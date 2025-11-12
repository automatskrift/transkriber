//
//  AudioRecordingService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import AVFoundation
import Combine
import ActivityKit

@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevels: [Float] = []
    @Published var currentLevel: Float = 0
    @Published var marks: [Double] = []

    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = .sharedInstance()
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var currentRecordingURL: URL?
    private var wasInterrupted = false
    private var currentActivity: Activity<RecordingActivityAttributes>?

    private override init() {
        super.init()
        setupInterruptionObserver()
    }

    private func setupAudioSession() throws {
        do {
            // Configure for background recording
            // Use .record mode specifically for recording in background
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✅ Audio session configured for background recording")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            throw error
        }
    }

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        print("✅ Audio interruption observer setup")
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        Task { @MainActor in
            switch type {
            case .began:
                // Interruption began (phone call, etc.)
                if self.isRecording && !self.isPaused && AppSettings.shared.pauseOnCall {
                    print("📞 Interruption began - pausing recording")
                    self.pauseRecording()
                    self.wasInterrupted = true
                }

            case .ended:
                // Interruption ended
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
                }

                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && self.wasInterrupted && AppSettings.shared.pauseOnCall {
                    print("📞 Interruption ended - resuming recording")
                    // Wait a bit before resuming
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    self.resumeRecording()
                    self.wasInterrupted = false
                }

            @unknown default:
                break
            }
        }
    }

    /// Request microphone permission
    func requestPermission() async -> Bool {
        print("🎤 Requesting microphone permission...")

        let granted: Bool
        if #available(iOS 17.0, *) {
            // Use the new AVAudioApplication API for iOS 17.0+
            granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            // Fall back to the deprecated method for older iOS versions
            granted = await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
        return granted
    }

    /// Start recording
    func startRecording(quality: AudioQuality = .high) async throws {
        // Request permission if needed
        guard await requestPermission() else {
            throw RecordingError.permissionDenied
        }

        // Setup audio session after permission is granted
        try setupAudioSession()

        // Generate unique filename
        let fileName = "rec_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)

        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: quality.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: quality.bitRate
        ]

        do {
            // Create and configure recorder
            print("📝 Creating audio recorder with URL: \(audioURL)")
            print("📝 Settings: \(settings)")
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            // Prepare to record
            print("📝 Preparing to record...")
            guard audioRecorder?.prepareToRecord() == true else {
                print("❌ Failed to prepare recorder")
                throw RecordingError.failedToStart
            }
            print("✅ Recorder prepared successfully")

            // Start recording
            print("📝 Starting recording...")
            guard audioRecorder?.record() == true else {
                print("❌ Failed to start recording - record() returned false")
                if let error = audioRecorder?.url {
                    print("   Recorder URL: \(error)")
                }
                throw RecordingError.failedToStart
            }

            currentRecordingURL = audioURL
            isRecording = true
            isPaused = false
            duration = 0
            audioLevels = []
            marks = []

            startMonitoring()

            // Start Live Activity
            Task { @MainActor in
                self.startLiveActivity(fileName: fileName)
            }

            print("✅ Recording started: \(fileName)")

        } catch let error as RecordingError {
            print("❌ Recording error: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Failed to start recording: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            throw RecordingError.failedToStart
        }
    }

    /// Stop recording and return the recording info
    func stopRecording() async throws -> Recording {
        guard let recorder = audioRecorder, let url = currentRecordingURL else {
            throw RecordingError.noActiveRecording
        }

        recorder.stop()
        stopMonitoring()
        await endLiveActivity()

        isRecording = false
        isPaused = false

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Create recording object
        let recording = Recording(
            fileName: url.lastPathComponent,
            localURL: url,
            duration: duration,
            fileSize: fileSize
        )

        // Reset state
        audioRecorder = nil
        currentRecordingURL = nil
        duration = 0
        audioLevels = []
        currentLevel = 0

        print("✅ Recording stopped: \(recording.fileName)")

        return recording
    }

    /// Pause recording
    func pauseRecording() {
        guard isRecording, !isPaused else { return }

        audioRecorder?.pause()
        isPaused = true
        stopMonitoring()
        Task { await updateLiveActivity(pausedAt: Date()) }

        print("⏸️ Recording paused")
    }

    /// Resume recording
    func resumeRecording() {
        guard isRecording, isPaused else { return }

        audioRecorder?.record()
        isPaused = false
        startMonitoring()
        Task { await updateLiveActivity(pausedAt: nil) }

        print("▶️ Recording resumed")
    }

    /// Add a mark at the current recording time
    func addMark() {
        guard isRecording, let recorder = audioRecorder else { return }

        let currentTime = recorder.currentTime
        marks.append(currentTime)
        print("📍 Mark added at \(currentTime) seconds (total marks: \(marks.count))")
    }

    /// Cancel recording
    func cancelRecording() {
        guard let recorder = audioRecorder, let url = currentRecordingURL else { return }

        recorder.stop()
        stopMonitoring()
        Task { await endLiveActivity() }

        // Delete file
        try? FileManager.default.removeItem(at: url)

        // Reset state
        isRecording = false
        isPaused = false
        audioRecorder = nil
        currentRecordingURL = nil
        duration = 0
        audioLevels = []
        currentLevel = 0

        print("🗑️ Recording cancelled")
    }

    private func startMonitoring() {
        // Monitor audio levels
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }

                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)

                // Normalize level from dB (-160 to 0) to 0-1
                let normalizedLevel = max(0, min(1, (level + 160) / 160))

                self.currentLevel = normalizedLevel
                self.audioLevels.append(level)

                // Keep only last 100 samples
                if self.audioLevels.count > 100 {
                    self.audioLevels.removeFirst()
                }
            }
        }

        // Monitor duration
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                guard let recorder = self.audioRecorder else {
                    self.stopMonitoring()
                    return
                }

                // Update duration
                self.duration = recorder.currentTime
            }
        }
    }

    private func stopMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Live Activity

    private func startLiveActivity(fileName: String) {
        guard #available(iOS 16.2, *) else {
            print("⚠️ Live Activities require iOS 16.2+ for full features")
            return
        }

        let authInfo = ActivityAuthorizationInfo()
        print("📊 Live Activities status:")
        print("   - Enabled: \(authInfo.areActivitiesEnabled)")
        print("   - Frequent pushes enabled: \(authInfo.frequentPushesEnabled)")
        print("   - Are pushes enabled: \(authInfo.areActivitiesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled by user")
            print("   User needs to enable in Settings > SkrivDetNed > Live Activities")
            print("   OR Settings > Face ID & Passcode > Allow Access When Locked > Live Activities")
            return
        }

        let attributes = RecordingActivityAttributes(startTime: Date())
        let initialState = RecordingActivityAttributes.ContentState(
            isPaused: false,
            fileName: fileName,
            pausedAt: nil,
            totalPausedDuration: 0
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)

            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )

            print("✅ Live Activity requested successfully!")
            print("   Activity ID: \(currentActivity?.id ?? "unknown")")
            print("   Activity state: \(String(describing: currentActivity?.activityState))")
            print("   Content state: fileName=\(initialState.fileName), paused=\(initialState.isPaused)")

            // Debug: Check all active activities
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s
                let activities = Activity<RecordingActivityAttributes>.activities
                print("   📱 Total active activities: \(activities.count)")
                for activity in activities {
                    print("      - ID: \(activity.id)")
                    print("        State: \(activity.activityState)")
                    print("        Content: \(activity.content.state)")
                }

                if activities.isEmpty {
                    print("   ⚠️ WARNING: No active activities found - Live Activity may have failed silently")
                    print("   This usually means:")
                    print("      1. Live Activities are disabled in Settings")
                    print("      2. Widget Extension is not configured")
                    print("      3. ActivityConfiguration is missing")
                }
            }
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
            print("   Error details: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")

            if let activityError = error as? ActivityAuthorizationError {
                print("   Authorization error: \(activityError)")
            }
        }
    }

    private func updateLiveActivity(pausedAt: Date? = nil) async {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }
        guard activity.activityState == .active else { return }

        let contentState = RecordingActivityAttributes.ContentState(
            isPaused: isPaused,
            fileName: currentRecordingURL?.lastPathComponent ?? "Recording",
            pausedAt: pausedAt,
            totalPausedDuration: 0 // TODO: Track total paused time if needed
        )

        await activity.update(.init(state: contentState, staleDate: nil))
        print("🔄 Live Activity updated: paused: \(isPaused)")
    }

    private func endLiveActivity() async {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }

        let finalState = RecordingActivityAttributes.ContentState(
            isPaused: false,
            fileName: currentRecordingURL?.lastPathComponent ?? "Recording",
            pausedAt: nil,
            totalPausedDuration: 0
        )

        await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        currentActivity = nil
        print("✅ Live Activity ended")
    }

    nonisolated deinit {
        // Timers will be invalidated when the object is deallocated
        // Can't call MainActor-isolated methods from deinit
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("❌ Recording finished with error")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ Recording encode error: \(error)")
            }
        }
    }
}

enum RecordingError: LocalizedError {
    case permissionDenied
    case failedToStart
    case noActiveRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return NSLocalizedString("Mikrofon adgang nægtet. Gå til Indstillinger for at give tilladelse.", comment: "")
        case .failedToStart:
            return NSLocalizedString("Kunne ikke starte optagelse. Prøv igen.", comment: "")
        case .noActiveRecording:
            return NSLocalizedString("Ingen aktiv optagelse.", comment: "")
        }
    }
}
