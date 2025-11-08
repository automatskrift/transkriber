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

    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = .sharedInstance()
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var currentRecordingURL: URL?
    private var wasInterrupted = false
    private var currentActivity: Activity<RecordingActivityAttributes>?

    private override init() {
        super.init()
        setupAudioSession()
        setupInterruptionObserver()
    }

    private func setupAudioSession() {
        do {
            // Configure for background recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("✅ Audio session configured for background recording")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
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
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Start recording
    func startRecording(quality: AudioQuality = .high) async throws {
        // Request permission if needed
        guard await requestPermission() else {
            throw RecordingError.permissionDenied
        }

        // Generate unique filename
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
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
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            // Start recording
            guard audioRecorder?.record() == true else {
                throw RecordingError.failedToStart
            }

            currentRecordingURL = audioURL
            isRecording = true
            isPaused = false
            duration = 0
            audioLevels = []

            startMonitoring()
            startLiveActivity(fileName: fileName)

            print("✅ Recording started: \(fileName)")

        } catch {
            print("❌ Failed to start recording: \(error)")
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
        Task { await updateLiveActivity() }

        print("⏸️ Recording paused")
    }

    /// Resume recording
    func resumeRecording() {
        guard isRecording, isPaused else { return }

        audioRecorder?.record()
        isPaused = false
        startMonitoring()
        Task { await updateLiveActivity() }

        print("▶️ Recording resumed")
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
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }
                self.duration = recorder.currentTime

                // Update Live Activity every second
                if Int(recorder.currentTime) % 1 == 0 {
                    await self.updateLiveActivity()
                }
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
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled")
            return
        }

        let attributes = RecordingActivityAttributes(startTime: Date())
        let contentState = RecordingActivityAttributes.ContentState(
            duration: 0,
            isPaused: false,
            fileName: fileName
        )

        do {
            currentActivity = try Activity<RecordingActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("✅ Live Activity started")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    private func updateLiveActivity() async {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }

        let contentState = RecordingActivityAttributes.ContentState(
            duration: duration,
            isPaused: isPaused,
            fileName: currentRecordingURL?.lastPathComponent ?? "Recording"
        )

        await activity.update(.init(state: contentState, staleDate: nil))
    }

    private func endLiveActivity() async {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }

        let finalState = RecordingActivityAttributes.ContentState(
            duration: duration,
            isPaused: false,
            fileName: currentRecordingURL?.lastPathComponent ?? "Recording"
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
            return "Mikrofon adgang nægtet. Gå til Indstillinger for at give tilladelse."
        case .failedToStart:
            return "Kunne ikke starte optagelse. Prøv igen."
        case .noActiveRecording:
            return "Ingen aktiv optagelse."
        }
    }
}
