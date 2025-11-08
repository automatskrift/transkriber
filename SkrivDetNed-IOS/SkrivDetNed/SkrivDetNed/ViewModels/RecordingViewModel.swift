//
//  RecordingViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevels: [Float] = []
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var isInitializingRecording = false // For optimistic UI

    // Metadata fields
    @Published var recordingTitle: String = ""
    @Published var recordingTags: String = ""
    @Published var recordingNotes: String = ""
    @Published var selectedPrompt: TranscriptionPrompt?

    private let audioService = AudioRecordingService.shared
    private let iCloudService = iCloudSyncService.shared
    private let locationService = LocationService.shared
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        setupiCloudMonitoring()
    }

    private func setupiCloudMonitoring() {
        // Check iCloud availability
        iCloudService.checkiCloudAvailability()

        // Check for existing transcriptions on startup
        if settings.iCloudAutoDownloadTranscriptions {
            Task {
                await iCloudService.checkForExistingTranscriptions()
            }
        }

        // Request location permission if enabled
        if settings.addLocationToRecordings {
            locationService.requestPermission()
        }
    }

    private func setupBindings() {
        // Bind audio service state to local state
        audioService.$isRecording
            .assign(to: &$isRecording)

        audioService.$isPaused
            .assign(to: &$isPaused)

        audioService.$duration
            .assign(to: &$duration)

        audioService.$audioLevels
            .assign(to: &$audioLevels)
    }

    // MARK: - Recording Controls

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        // Show initializing state immediately for better UX
        isInitializingRecording = true

        Task {
            do {
                try await audioService.startRecording(quality: settings.audioQuality)
                isInitializingRecording = false
                print("✅ Recording started")
            } catch {
                // Revert UI state if recording fails
                isInitializingRecording = false
                handleError(error)
            }
        }
    }

    func stopRecording() {
        print("🛑 Stop recording called")
        Task {
            do {
                print("⏹️ Stopping audio service...")
                var recording = try await audioService.stopRecording()
                print("📝 Recording stopped, got file: \(recording.fileName)")

                // Apply metadata
                recording.title = recordingTitle.isEmpty ? recording.title : recordingTitle
                recording.tags = parseTags(from: recordingTags)
                recording.notes = recordingNotes.isEmpty ? nil : recordingNotes

                // Debug selectedPrompt
                print("🔍 DEBUG selectedPrompt:")
                print("   selectedPrompt: \(String(describing: selectedPrompt))")
                print("   selectedPrompt?.name: \(selectedPrompt?.name ?? "nil")")
                print("   selectedPrompt?.text: \(selectedPrompt?.text ?? "nil")")
                print("   selectedPrompt?.text.isEmpty: \(String(describing: selectedPrompt?.text.isEmpty))")

                recording.promptPrefix = selectedPrompt?.text.isEmpty == false ? selectedPrompt?.text : nil

                print("📝 Applied metadata - title: \(recording.title)")
                if let prompt = recording.promptPrefix {
                    print("✨ Prompt prefix set: \(prompt.prefix(50))...")
                    print("   Full promptPrefix: \(prompt)")
                } else {
                    print("📝 No prompt prefix selected")
                }

                // Add location if enabled
                if settings.addLocationToRecordings {
                    if let locationData = await locationService.getCurrentLocation() {
                        recording.latitude = locationData.location?.coordinate.latitude
                        recording.longitude = locationData.location?.coordinate.longitude
                        recording.locationName = locationData.name
                        print("📍 Added location: \(locationData.name ?? "Unknown")")
                    }
                }

                // Save recording
                print("💾 Saving recording...")
                try await saveRecording(recording)
                print("✅ Recording saved successfully")

                // Reset metadata fields
                resetMetadata()

                // Show success
                showSuccess = true

            } catch {
                print("❌ Error in stopRecording: \(error.localizedDescription)")
                handleError(error)
            }
        }
    }

    func togglePause() {
        if isPaused {
            audioService.resumeRecording()
        } else {
            audioService.pauseRecording()
        }
    }

    func cancelRecording() {
        audioService.cancelRecording()
        resetMetadata()
        print("🗑️ Recording cancelled")
    }

    // MARK: - Helpers

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var estimatedFileSize: String {
        // Estimate based on bitrate and duration
        let bitRate = Double(settings.audioQuality.bitRate)
        let estimatedBytes = Int64((bitRate / 8) * duration)
        return ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
    }

    private func parseTags(from input: String) -> [String] {
        let tags = input
            .components(separatedBy: CharacterSet(charactersIn: " ,#"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return tags
    }

    private func resetMetadata() {
        recordingTitle = ""
        recordingTags = ""
        recordingNotes = ""
        selectedPrompt = nil
    }

    private func saveRecording(_ recording: Recording) async throws {
        print("💾 saveRecording called for: \(recording.fileName)")

        // Save to local database/storage
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        print("📁 Recordings directory: \(recordingsDir.path)")
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let metadataURL = recordingsDir.appendingPathComponent("\(recording.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(recording)
        try data.write(to: metadataURL)

        print("💾 Recording metadata saved: \(metadataURL.lastPathComponent)")
        if let promptPrefix = recording.promptPrefix {
            print("   ✨ Saved with promptPrefix: \(promptPrefix.prefix(50))...")
        }

        // Debug: Print JSON contents to verify
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 JSON contents preview:")
            let lines = jsonString.split(separator: "\n").prefix(15)
            for line in lines {
                print("   \(line)")
            }
        }

        // Upload to iCloud if enabled
        print("🔍 Checking iCloud upload - enabled: \(settings.iCloudAutoUpload)")
        if settings.iCloudAutoUpload {
            print("☁️ Starting iCloud upload...")

            // Update status to uploading
            var uploadingRecording = recording
            uploadingRecording.cloudStatus = .uploading
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(uploadingRecording) {
                try? data.write(to: metadataURL)
            }

            // Notify UI to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RecordingUploadStatusChanged"), object: nil)

            do {
                try await iCloudService.uploadRecording(recording)
                print("☁️ Recording uploaded to iCloud successfully")

                // Update status to synced
                var syncedRecording = recording
                syncedRecording.cloudStatus = .synced
                if let data = try? encoder.encode(syncedRecording) {
                    try? data.write(to: metadataURL)
                }

                // Notify UI to refresh
                NotificationCenter.default.post(name: NSNotification.Name("RecordingUploadStatusChanged"), object: nil)
            } catch {
                print("⚠️ Failed to upload to iCloud: \(error.localizedDescription)")
                print("   Error: \(error)")

                // Update status to failed
                var failedRecording = recording
                failedRecording.cloudStatus = .failed
                if let data = try? encoder.encode(failedRecording) {
                    try? data.write(to: metadataURL)
                }

                // Notify UI to refresh
                NotificationCenter.default.post(name: NSNotification.Name("RecordingUploadStatusChanged"), object: nil)
                // Don't throw - recording is still saved locally
            }
        } else {
            print("⏭️ iCloud auto-upload is disabled, skipping upload")
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("❌ Error: \(error.localizedDescription)")
    }
}
