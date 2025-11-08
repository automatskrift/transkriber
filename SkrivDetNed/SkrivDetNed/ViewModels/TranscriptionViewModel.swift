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
    private var stuckCheckTimer: Timer?

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
            await resetStuckTranscriptions()
            await loadExistingTranscriptions()
            await processPendingFiles()
        }

        // Start periodic check for stuck transcriptions and pending files (every 5 minutes)
        stuckCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.resetStuckTranscriptions()
                await self?.processPendingFiles()
            }
        }
        print("⏰ Started periodic check for stuck/pending transcriptions (every 5 minutes)")
    }

    deinit {
        stuckCheckTimer?.invalidate()
    }

    /// Reset transcriptions that are stuck in "transcribing" status
    private func resetStuckTranscriptions() async {
        print("🔍 Checking for stuck transcriptions...")

        guard let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() else {
            print("⚠️ Cannot access iCloud recordings folder")
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsFolder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let jsonFiles = files.filter { $0.pathExtension == "json" }
            var resetCount = 0

            for jsonFile in jsonFiles {
                guard let data = try? Data(contentsOf: jsonFile) else { continue }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                guard var metadata = try? decoder.decode(RecordingMetadata.self, from: data) else {
                    continue
                }

                // Check if stuck in transcribing state
                if metadata.status == .transcribing {
                    let timeSinceUpdate = Date().timeIntervalSince(metadata.updatedAt)

                    // If transcribing for more than 2 minutes, consider it stuck
                    if timeSinceUpdate > 120 {
                        print("⚠️ Found stuck transcription: \(metadata.audioFileName)")
                        print("   Time since update: \(Int(timeSinceUpdate)) seconds")

                        // Reset to pending so it will be picked up again
                        metadata.status = .pending
                        metadata.updatedAt = Date()
                        metadata.transcribedOnDevice = nil

                        let encoder = JSONEncoder()
                        encoder.dateEncodingStrategy = .iso8601
                        encoder.outputFormatting = .prettyPrinted

                        if let updatedData = try? encoder.encode(metadata) {
                            try? updatedData.write(to: jsonFile)
                            print("   ✅ Reset to pending status")
                            resetCount += 1
                        }
                    }
                }
            }

            if resetCount > 0 {
                print("✅ Reset \(resetCount) stuck transcription(s)")
            } else {
                print("✅ No stuck transcriptions found")
            }

        } catch {
            print("❌ Failed to check for stuck transcriptions: \(error)")
        }
    }

    /// Process pending files from iCloud that are waiting for transcription
    private func processPendingFiles() async {
        print("🔍 Checking for pending transcriptions in iCloud...")

        guard AppSettings.shared.iCloudSyncEnabled else {
            print("⏭️ iCloud sync not enabled, skipping pending files check")
            return
        }

        guard let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() else {
            print("⚠️ Cannot access iCloud recordings folder")
            return
        }

        print("📁 iCloud recordings folder: \(recordingsFolder.path)")

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsFolder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            print("📂 Found \(files.count) total files in iCloud folder")

            let jsonFiles = files.filter { $0.pathExtension == "json" }
            print("📄 Found \(jsonFiles.count) JSON metadata files")

            var pendingCount = 0
            var statusCounts: [String: Int] = [:]

            for jsonFile in jsonFiles {
                guard let data = try? Data(contentsOf: jsonFile) else {
                    print("⚠️ Could not read: \(jsonFile.lastPathComponent)")
                    continue
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                guard let metadata = try? decoder.decode(RecordingMetadata.self, from: data) else {
                    print("⚠️ Could not decode metadata: \(jsonFile.lastPathComponent)")
                    continue
                }

                // Count status
                let statusKey = metadata.status.rawValue
                statusCounts[statusKey, default: 0] += 1

                // Check if in pending state
                if metadata.status == .pending {
                    // Find the audio file
                    let audioURL = recordingsFolder.appendingPathComponent(metadata.audioFileName)

                    print("🔎 Checking pending file: \(metadata.audioFileName)")
                    print("   Audio file exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
                    print("   Audio file path: \(audioURL.path)")

                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        print("📥 Found pending file: \(metadata.audioFileName)")
                        await addToQueue(audioURL)
                        pendingCount += 1
                    } else {
                        print("⚠️ Pending file not found on disk: \(metadata.audioFileName)")
                    }
                }
            }

            print("📊 Status summary:")
            for (status, count) in statusCounts.sorted(by: { $0.key < $1.key }) {
                print("   \(status): \(count)")
            }

            if pendingCount > 0 {
                print("✅ Found \(pendingCount) pending file(s) to transcribe")
            } else {
                print("✅ No pending files found")
            }

        } catch {
            print("❌ Failed to check for pending files: \(error)")
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
        guard !taskQueue.contains(url) else {
            print("⏭️ File already in queue: \(url.lastPathComponent)")
            return
        }
        guard !activeTasks.contains(where: { $0.audioFileURL == url }) else {
            print("⏭️ File already being transcribed: \(url.lastPathComponent)")
            return
        }

        // Check if file has already been processed (completed or failed) in iCloud
        if AppSettings.shared.iCloudSyncEnabled,
           let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
            do {
                if let metadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder) {
                    // Skip if already completed successfully
                    if metadata.status == .completed {
                        print("⏭️ File already transcribed (status: completed): \(url.lastPathComponent)")
                        FolderMonitorService.shared.markAsProcessed(url)
                        return
                    }
                    // Skip if failed (unless user explicitly retries)
                    if metadata.status == .failed {
                        print("⏭️ File previously failed transcription: \(url.lastPathComponent)")
                        print("   Use 'Retry' button to transcribe again")
                        FolderMonitorService.shared.markAsProcessed(url)
                        return
                    }
                    // Allow pending and transcribing status (transcribing will be reset by resetStuckTranscriptions)
                }
            } catch {
                // No metadata found, proceed with transcription
                print("ℹ️ No existing metadata for: \(url.lastPathComponent)")
            }
        }

        taskQueue.append(url)
        print("➕ Added to transcription queue: \(url.lastPathComponent)")

        // Start processing if not already
        if !isProcessing {
            await processQueue()
        }
    }

    func transcribeFile(_ url: URL) async throws {
        // Check if file is ignored
        if AppSettings.shared.ignoredFiles.contains(url.path) {
            print("⏭️ Skipping ignored file in transcribeFile: \(url.lastPathComponent)")
            FolderMonitorService.shared.removeFromPending(url)
            throw TranscriptionError.fileNotFound
        }

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

        // If file is from iCloud, update metadata to "transcribing"
        if url.path.contains("Mobile Documents") {
            do {
                if let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
                    var metadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder)
                        ?? RecordingMetadata(audioFileName: url.lastPathComponent, createdOnDevice: "Unknown")

                    metadata.status = .transcribing
                    metadata.transcribedOnDevice = "macOS"
                    metadata.updatedAt = Date()

                    try metadata.save(to: recordingsFolder)
                    print("🔄 Updated metadata to 'transcribing' status")
                }
            } catch {
                print("⚠️ Failed to update metadata to transcribing: \(error)")
            }
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
        guard !isProcessing else {
            print("⏸️ Already processing queue")
            return
        }
        isProcessing = true

        print("🚀 Starting queue processing (\(taskQueue.count) files in queue)")

        while !taskQueue.isEmpty {
            let url = taskQueue.removeFirst()

            print("🔄 Processing: \(url.lastPathComponent) (\(taskQueue.count) remaining)")

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
                print("⏭️ Skipping already processed file: \(url.lastPathComponent)")
                continue
            }

            // Skip if transcription already exists
            guard !FileSystemHelper.shared.transcriptionFileExists(for: url) else {
                print("⏭️ Transcription already exists: \(url.lastPathComponent)")
                FolderMonitorService.shared.markAsProcessed(url)
                continue
            }

            print("▶️ Starting transcription: \(url.lastPathComponent)")

            do {
                try await transcribeFile(url)
                print("✅ Completed transcription: \(url.lastPathComponent)")
            } catch {
                print("❌ Transcription failed for \(url.lastPathComponent): \(error)")
            }

            // Small delay between files
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        print("🏁 Queue processing finished")
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

    /// Remove file from queue and active tasks (used when ignoring a file)
    func removeFileFromProcessing(_ url: URL) {
        // Remove from task queue
        taskQueue.removeAll { $0.path == url.path }

        // Remove from active tasks
        activeTasks.removeAll { $0.audioFileURL.path == url.path }

        // Update current task if needed
        if currentTask?.audioFileURL.path == url.path {
            currentTask = nil
        }

        print("🗑️ Removed \(url.lastPathComponent) from transcription processing")
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
