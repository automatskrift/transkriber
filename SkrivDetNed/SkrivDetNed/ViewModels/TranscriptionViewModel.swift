//
//  TranscriptionViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import UserNotifications
import Combine

@MainActor
class TranscriptionViewModel: ObservableObject {
    static let shared = TranscriptionViewModel()

    @Published var activeTasks: [TranscriptionTask] = [] {
        didSet {
            MenuBarManager.shared.updateIcon(isTranscribing: !activeTasks.isEmpty)
        }
    }
    @Published var completedTasks: [TranscriptionTask] = []
    @Published var currentTask: TranscriptionTask?

    private var isProcessing = false
    private var taskQueue: [URL] = []

    private init() {
        // Listen for new files from folder monitor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewAudioFile),
            name: NSNotification.Name("NewAudioFileDetected"),
            object: nil
        )

        // Load existing completed transcriptions on startup
        Task {
            await loadExistingTranscriptions()
        }
    }

    /// Load existing transcription files from monitored folder and iCloud
    private func loadExistingTranscriptions() async {
        var foundTasks: [TranscriptionTask] = []

        // Check local monitored folder
        if let folderURL = AppSettings.shared.monitoredFolderURL {
            await scanFolderForTranscriptions(folderURL, into: &foundTasks)
        }

        // Check iCloud folder
        if AppSettings.shared.iCloudSyncEnabled,
           let iCloudFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
            await scanFolderForTranscriptions(iCloudFolder, into: &foundTasks)
        }

        // Sort by modification date (newest first) and take the 50 most recent
        foundTasks.sort { task1, task2 in
            guard let date1 = task1.completedAt, let date2 = task2.completedAt else {
                return false
            }
            return date1 > date2
        }

        completedTasks = Array(foundTasks.prefix(50))

        if !completedTasks.isEmpty {
            print("📋 Loaded \(completedTasks.count) existing transcription(s)")
        }
    }

    /// Scan a folder for completed transcriptions
    private func scanFolderForTranscriptions(_ folderURL: URL, into tasks: inout [TranscriptionTask]) async {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            // Find all .txt transcription files
            let transcriptionFiles = files.filter { $0.pathExtension == "txt" }

            for txtFile in transcriptionFiles {
                // Find corresponding audio file
                let baseName = txtFile.deletingPathExtension().lastPathComponent
                let audioExtensions = ["m4a", "mp3", "wav", "aiff", "caf", "aac", "flac"]

                var audioFileURL: URL?
                for ext in audioExtensions {
                    let possibleAudioFile = folderURL.appendingPathComponent("\(baseName).\(ext)")
                    if FileManager.default.fileExists(atPath: possibleAudioFile.path) {
                        audioFileURL = possibleAudioFile
                        break
                    }
                }

                // If we found the audio file, create a completed task
                if let audioURL = audioFileURL {
                    // Skip if file is ignored
                    if AppSettings.shared.ignoredFiles.contains(audioURL.path) {
                        continue
                    }

                    // Get creation date of audio file and modification date of transcription
                    let audioAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
                    let txtAttributes = try? FileManager.default.attributesOfItem(atPath: txtFile.path)

                    let audioCreationDate = audioAttributes?[.creationDate] as? Date ?? Date()
                    let txtModificationDate = txtAttributes?[.modificationDate] as? Date ?? Date()

                    var task = TranscriptionTask(audioFileURL: audioURL, outputFileURL: txtFile, createdAt: audioCreationDate)
                    task.status = .completed
                    task.completedAt = txtModificationDate

                    // Avoid duplicates
                    if !tasks.contains(where: { $0.outputFileURL.path == txtFile.path }) {
                        tasks.append(task)
                    }
                }
            }
        } catch {
            print("⚠️ Failed to scan folder \(folderURL.path): \(error)")
        }
    }

    @objc private func handleNewAudioFile(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        Task {
            await addToQueue(url)
        }
    }

    func addToQueue(_ url: URL) async {
        // Check if already in queue
        guard !taskQueue.contains(url) else { return }
        guard !activeTasks.contains(where: { $0.audioFileURL == url }) else { return }

        taskQueue.append(url)

        // Start processing if not already
        if !isProcessing {
            await processQueue()
        }
    }

    func transcribeFile(_ url: URL) async throws {
        // Check if file still exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ File no longer exists: \(url.lastPathComponent)")
            // Remove from pending if it was there
            FolderMonitorService.shared.removeFromPending(url)
            throw TranscriptionError.fileNotFound
        }

        let task = TranscriptionTask(audioFileURL: url)
        activeTasks.append(task)
        currentTask = task

        // Update task status
        if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
            activeTasks[index].status = .processing(progress: 0.0)
        }

        do {
            // Get selected model
            let modelType = AppSettings.shared.selectedModelType

            // Ensure model is downloaded
            guard FileSystemHelper.shared.modelExists(modelType) else {
                throw TranscriptionError.modelNotDownloaded
            }

            // Transcribe
            let transcription = try await WhisperService.shared.transcribe(
                audioURL: url,
                modelType: modelType
            ) { progress in
                Task { @MainActor in
                    if let index = self.activeTasks.firstIndex(where: { $0.id == task.id }) {
                        self.activeTasks[index].status = .processing(progress: progress)
                    }
                }
            }

            // Save transcription to file
            try transcription.write(to: task.outputFileURL, atomically: true, encoding: .utf8)

            // If file is from iCloud, save transcription back to iCloud
            if url.path.contains("Mobile Documents") {
                do {
                    try await iCloudSyncService.shared.saveTranscriptionToiCloud(
                        audioFileName: url.lastPathComponent,
                        transcription: transcription
                    )
                    print("✅ Successfully saved transcription and metadata to iCloud")
                } catch {
                    print("❌ Failed to save to iCloud: \(error)")
                }
            }

            // Update task status
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                activeTasks[index].status = .completed
                activeTasks[index].completedAt = Date()

                // Move to completed
                let completedTask = activeTasks.remove(at: index)
                completedTasks.insert(completedTask, at: 0)

                // Keep only last 50 completed tasks
                if completedTasks.count > 50 {
                    completedTasks = Array(completedTasks.prefix(50))
                }
            }

            // Mark as processed in folder monitor
            FolderMonitorService.shared.markAsProcessed(url)

            // Send notification
            if AppSettings.shared.showNotifications {
                sendCompletionNotification(for: task)
            }

            // Delete audio file if setting is enabled
            if AppSettings.shared.deleteAudioAfterTranscription {
                try? FileManager.default.removeItem(at: url)
            }

        } catch {
            // Update task status
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                activeTasks[index].status = .failed(error: error.localizedDescription)
                activeTasks[index].completedAt = Date()

                // Move to completed
                let failedTask = activeTasks.remove(at: index)
                completedTasks.insert(failedTask, at: 0)
            }

            // If file is from iCloud, save error status to metadata
            if url.path.contains("Mobile Documents") {
                do {
                    if let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
                        var metadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder)
                            ?? RecordingMetadata(audioFileName: url.lastPathComponent, createdOnDevice: "Unknown")

                        metadata.status = .failed
                        metadata.errorMessage = error.localizedDescription
                        metadata.lastAttemptedAt = Date()
                        metadata.updatedAt = Date()

                        try metadata.save(to: recordingsFolder)
                        print("❌ Saved error status to iCloud metadata: \(error.localizedDescription)")
                    }
                } catch {
                    print("⚠️ Failed to save error status to iCloud: \(error)")
                }
            }

            throw error
        }

        currentTask = nil
    }

    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        while !taskQueue.isEmpty {
            let url = taskQueue.removeFirst()

            // Check if file still exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⏭️ Skipping deleted file: \(url.lastPathComponent)")
                FolderMonitorService.shared.removeFromPending(url)
                continue
            }

            // Skip if file is ignored
            if AppSettings.shared.ignoredFiles.contains(url.path) {
                print("⏭️ Skipping ignored file: \(url.lastPathComponent)")
                continue
            }

            // Skip if already processed
            guard !FolderMonitorService.shared.processedFiles.contains(url.path) else {
                continue
            }

            // Skip if transcription already exists
            guard !FileSystemHelper.shared.transcriptionFileExists(for: url) else {
                FolderMonitorService.shared.markAsProcessed(url)
                continue
            }

            do {
                try await transcribeFile(url)
            } catch {
                print("Transcription failed for \(url.lastPathComponent): \(error)")
            }

            // Small delay between files
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        isProcessing = false
    }

    private func sendCompletionNotification(for task: TranscriptionTask) {
        let content = UNMutableNotificationContent()
        content.title = "Transskription færdig"
        content.body = "'\(task.fileName)' er blevet transkriberet"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelTask(_ task: TranscriptionTask) {
        if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
            activeTasks.remove(at: index)
        }
        taskQueue.removeAll { url in
            url == task.audioFileURL
        }

        if currentTask?.id == task.id {
            WhisperService.shared.cancelTranscription()
            currentTask = nil
        }
    }

    func clearCompletedTasks() {
        completedTasks.removeAll()
    }

    /// Retry a failed transcription task
    func retryTask(_ task: TranscriptionTask) async {
        // Remove from completed tasks
        completedTasks.removeAll { $0.id == task.id }

        // Add to queue for retry
        await addToQueue(task.audioFileURL)

        print("🔄 Retrying transcription for: \(task.fileName)")
    }

    /// Ignore a failed task permanently
    func ignoreTask(_ task: TranscriptionTask) {
        // Add to ignored files list
        var ignoredFiles = AppSettings.shared.ignoredFiles
        ignoredFiles.insert(task.audioFileURL.path)
        AppSettings.shared.ignoredFiles = ignoredFiles

        // Remove from completed tasks list
        completedTasks.removeAll { $0.id == task.id }

        print("🚫 Ignoring file: \(task.fileName)")
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotDownloaded
    case fileNotFound
    case invalidFile
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Whisper model er ikke downloadet. Download en model i indstillinger."
        case .fileNotFound:
            return "Lydfilen blev ikke fundet"
        case .invalidFile:
            return "Ugyldig lydfil"
        case .transcriptionFailed:
            return "Transskription fejlede"
        }
    }
}
