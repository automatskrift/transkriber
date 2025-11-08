//
//  AudioRecordingService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import AVFoundation
import Combine

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

    private override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("✅ Audio session configured")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
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

        print("⏸️ Recording paused")
    }

    /// Resume recording
    func resumeRecording() {
        guard isRecording, isPaused else { return }

        audioRecorder?.record()
        isPaused = false
        startMonitoring()

        print("▶️ Recording resumed")
    }

    /// Cancel recording
    func cancelRecording() {
        guard let recorder = audioRecorder, let url = currentRecordingURL else { return }

        recorder.stop()
        stopMonitoring()

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
            }
        }
    }

    private func stopMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
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
