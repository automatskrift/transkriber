//
//  RecordingsListViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import Combine

enum SortOrder: String, CaseIterable {
    case newestFirst = "newest"
    case oldestFirst = "oldest"
    case name = "name"
    case size = "size"

    var displayName: String {
        switch self {
        case .newestFirst: return "Nyeste først"
        case .oldestFirst: return "Ældste først"
        case .name: return "Navn"
        case .size: return "Størrelse"
        }
    }
}

@MainActor
class RecordingsListViewModel: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var sortOrder: SortOrder = .newestFirst {
        didSet {
            sortRecordings()
        }
    }

    private let iCloudService = iCloudSyncService.shared

    init() {
        loadRecordings()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        // Refresh when transcription is received
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTranscriptionUpdate),
            name: NSNotification.Name("TranscriptionReceived"),
            object: nil
        )

        // Refresh when upload status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUploadStatusUpdate),
            name: NSNotification.Name("RecordingUploadStatusChanged"),
            object: nil
        )
    }

    @objc private func handleTranscriptionUpdate(_ notification: Notification) {
        // Reload recordings to reflect updated transcription status
        loadRecordings()
    }

    @objc private func handleUploadStatusUpdate(_ notification: Notification) {
        // Reload recordings to reflect updated upload status
        loadRecordings()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func loadRecordings() {
        // Load recordings from local storage
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        guard FileManager.default.fileExists(atPath: recordingsDir.path) else {
            recordings = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            recordings = jsonFiles.compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let recording = try? decoder.decode(Recording.self, from: data) else {
                    return nil
                }
                return recording
            }

            sortRecordings()
            print("📂 Loaded \(recordings.count) recordings")

        } catch {
            print("❌ Failed to load recordings: \(error)")
            recordings = []
        }
    }

    func refresh() async {
        // Reload from disk and check iCloud status
        loadRecordings()

        // Check iCloud for new transcriptions
        await iCloudService.checkForExistingTranscriptions()

        // Reload again after iCloud check
        await Task.sleep(1_000_000_000) // Wait 1 second for iCloud updates
        loadRecordings()
    }

    func deleteRecording(_ recording: Recording) {
        // Delete from disk
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        let metadataURL = recordingsDir.appendingPathComponent("\(recording.id.uuidString).json")

        do {
            // Delete audio file
            try? FileManager.default.removeItem(at: recording.localURL)

            // Delete metadata
            try FileManager.default.removeItem(at: metadataURL)

            // Remove from array
            recordings.removeAll { $0.id == recording.id }

            print("🗑️ Deleted recording: \(recording.title)")

        } catch {
            print("❌ Failed to delete recording: \(error)")
        }
    }


    private func sortRecordings() {
        switch sortOrder {
        case .newestFirst:
            recordings.sort { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            recordings.sort { $0.createdAt < $1.createdAt }
        case .name:
            recordings.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .size:
            recordings.sort { $0.fileSize > $1.fileSize }
        }
    }
}
