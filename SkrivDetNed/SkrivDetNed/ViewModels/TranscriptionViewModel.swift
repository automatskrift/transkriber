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
            await cleanupDuplicateMetadataFiles()
            await loadExistingTranscriptions()
        }
    }

    /// Clean up duplicate metadata files created by iCloud sync conflicts
    private func cleanupDuplicateMetadataFiles() async {
        guard let directory = iCloudSyncService.shared.getRecordingsFolderURL() else {
            return
        }
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Find all duplicate JSON files (ending with " 2.json", " 3.json", etc.)
            let duplicateFiles = files.filter {
                $0.pathExtension == "json" &&
                ($0.lastPathComponent.contains(" 2.json") ||
                 $0.lastPathComponent.contains(" 3.json") ||
                 $0.lastPathComponent.contains(" 4.json"))
            }

            for duplicateFile in duplicateFiles {
                print("🗑️ Cleaning up duplicate metadata file: \(duplicateFile.lastPathComponent)")

                // Try to find the original file
                let originalFileName = duplicateFile.lastPathComponent
                    .replacingOccurrences(of: " 2.json", with: ".json")
                    .replacingOccurrences(of: " 3.json", with: ".json")
                    .replacingOccurrences(of: " 4.json", with: ".json")

                let originalFile = directory.appendingPathComponent(originalFileName)

                if FileManager.default.fileExists(atPath: originalFile.path) {
                    // Original exists, so we can safely delete the duplicate
                    try? FileManager.default.removeItem(at: duplicateFile)
                    print("   ✅ Deleted duplicate (original exists)")
                } else {
                    // Original doesn't exist, rename duplicate to be the original
                    try? FileManager.default.moveItem(at: duplicateFile, to: originalFile)
                    print("   ✅ Renamed duplicate to original filename")
                }
            }

            if !duplicateFiles.isEmpty {
                print("✅ Cleaned up \(duplicateFiles.count) duplicate metadata file(s)")
            }
        } catch {
            print("❌ Failed to clean up duplicate metadata files: \(error)")
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
        print("📝 addToQueue called for: \(url.lastPathComponent)")
        print("   Full path: \(url.path)")
        print("   Current taskQueue size: \(taskQueue.count)")
        print("   Current activeTasks size: \(activeTasks.count)")
        print("   isProcessing: \(isProcessing)")

        // Check if already in queue
        guard !taskQueue.contains(url) else {
            print("⏭️ File already in queue: \(url.lastPathComponent)")
            return
        }
        guard !activeTasks.contains(where: { $0.audioFileURL == url }) else {
            print("⏭️ File already being transcribed: \(url.lastPathComponent)")
            return
        }

        print("   ✓ Not in queue or active tasks")

        // Check if file has already been processed (completed or failed) in iCloud
        if AppSettings.shared.iCloudSyncEnabled,
           let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
            print("   📁 Checking iCloud metadata...")
            do {
                if let metadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder) {
                    print("   📋 Found metadata with status: \(metadata.status.rawValue)")
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
                    print("   ✓ Status is \(metadata.status.rawValue) - will proceed")
                } else {
                    print("   ℹ️ No metadata found - will proceed")
                }
            } catch {
                // No metadata found, proceed with transcription
                print("   ℹ️ No existing metadata (error: \(error.localizedDescription)) - will proceed")
            }
        } else {
            print("   ℹ️ iCloud sync disabled or no recordings folder - will proceed")
        }

        taskQueue.append(url)
        print("➕ Added to transcription queue: \(url.lastPathComponent)")
        print("   Queue length: \(taskQueue.count)")
        print("   isProcessing: \(isProcessing)")

        // Start processing if not already
        if !isProcessing {
            print("   🚀 Starting queue processing...")
            await processQueue()
        } else {
            print("   ⏸️ Already processing - will be picked up when current task completes")
        }
    }

    func transcribeFile(_ url: URL) async throws {
        let logMessage = "🎬 transcribeFile STARTED for: \(url.lastPathComponent) at \(Date())"
        print(logMessage)
        try? logMessage.appending("\n").write(toFile: "/tmp/skrivdetned_debug.log", atomically: false, encoding: .utf8)

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

        print("✅ File exists, creating task...")
        let task = TranscriptionTask(audioFileURL: url)
        activeTasks.append(task)
        currentTask = task
        print("✅ Task created and added to activeTasks (count: \(activeTasks.count))")

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

                    // Clear previous error if retrying a failed transcription
                    if metadata.status == .failed {
                        print("🔄 Retrying previously failed file - clearing error message")
                        metadata.errorMessage = nil
                        metadata.lastAttemptedAt = nil
                    }

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

            // Transcribe (WhisperKit will download model automatically if needed)
            let result = try await WhisperService.shared.transcribe(
                audioURL: url,
                modelType: modelType
            ) { progress in
                Task { @MainActor in
                    if let index = self.activeTasks.firstIndex(where: { $0.id == task.id }) {
                        self.activeTasks[index].status = .processing(progress: progress)
                    }
                }
            }

            // Insert marks if available
            var finalTranscription = result.text
            if url.path.contains("Mobile Documents"),
               let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL(),
               let metadata = try? RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder),
               let marks = metadata.marks, !marks.isEmpty {
                finalTranscription = insertMarks(in: result.text, marks: marks, segments: result.segments)
                print("📍 Inserted \(marks.count) marks into transcription")
            }

            // Save transcription to file
            try finalTranscription.write(to: task.outputFileURL, atomically: true, encoding: .utf8)

            // If file is from iCloud, save transcription back to iCloud
            if url.path.contains("Mobile Documents") {
                do {
                    try await iCloudSyncService.shared.saveTranscriptionToiCloud(
                        audioFileName: url.lastPathComponent,
                        transcription: finalTranscription
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
            print("❌ Transcription error caught for \(url.lastPathComponent): \(error)")

            // Update task status
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                activeTasks[index].status = .failed(error: error.localizedDescription)
                activeTasks[index].completedAt = Date()

                // Move to completed
                let failedTask = activeTasks.remove(at: index)
                completedTasks.insert(failedTask, at: 0)
                print("   ✅ Task moved to completed with failed status")
            }

            // If file is from iCloud, save error status to metadata
            if url.path.contains("Mobile Documents") {
                print("   📁 File is from iCloud, updating metadata...")
                print("   📍 File path: \(url.path)")

                do {
                    if let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
                        print("   📂 Recordings folder: \(recordingsFolder.path)")

                        var metadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder)
                            ?? RecordingMetadata(audioFileName: url.lastPathComponent, createdOnDevice: "Unknown")

                        print("   📝 Current metadata status: \(metadata.status.rawValue)")

                        metadata.status = .failed
                        metadata.errorMessage = error.localizedDescription
                        metadata.lastAttemptedAt = Date()
                        metadata.updatedAt = Date()

                        print("   💾 Attempting to save metadata with status: failed")
                        try metadata.save(to: recordingsFolder)
                        print("   ✅ Successfully saved error status to iCloud metadata: \(error.localizedDescription)")

                        // Verify it was saved correctly
                        if let verifyMetadata = try? RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder) {
                            print("   ✓ Verification - metadata status is now: \(verifyMetadata.status.rawValue)")
                        } else {
                            print("   ⚠️ Verification failed - could not reload metadata")
                        }
                    } else {
                        print("   ❌ Could not get recordings folder URL")
                    }
                } catch let saveError {
                    print("   ❌ Failed to save error status to iCloud: \(saveError)")
                    print("   📋 Save error type: \(type(of: saveError))")
                    print("   📋 Save error details: \(saveError.localizedDescription)")
                    if let nsError = saveError as NSError? {
                        print("   📋 NSError domain: \(nsError.domain)")
                        print("   📋 NSError code: \(nsError.code)")
                        print("   📋 NSError userInfo: \(nsError.userInfo)")
                    }
                }
            } else {
                print("   ℹ️ File is NOT from iCloud (path: \(url.path))")
            }

            throw error
        }

        currentTask = nil
    }

    private func processQueue() async {
        // Check if stuck - processing flag set but no active tasks
        if isProcessing && activeTasks.isEmpty && !taskQueue.isEmpty {
            print("⚠️ Processing flag stuck - resetting (queue has \(taskQueue.count) files)")
            isProcessing = false
        }

        guard !isProcessing else {
            print("⏸️ Already processing queue (activeTasks: \(activeTasks.count))")
            return
        }
        isProcessing = true

        let logMsg = "🚀 Starting queue processing (\(taskQueue.count) files in queue) at \(Date())"
        print(logMsg)
        try? logMsg.appending("\n").write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)

        while !taskQueue.isEmpty {
            let url = taskQueue.removeFirst()

            let procMsg = "🔄 Processing: \(url.lastPathComponent) (\(taskQueue.count) remaining)"
            print(procMsg)
            if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                log.append(procMsg + "\n")
                try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
            }

            // Check if file still exists
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            if !fileExists {
                let msg = "⏭️ SKIP: File doesn't exist: \(url.lastPathComponent)"
                print(msg)
                if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                    log.append(msg + "\n")
                    try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
                }
                FolderMonitorService.shared.removeFromPending(url)
                continue
            }

            // Skip if file is ignored
            if AppSettings.shared.ignoredFiles.contains(url.path) {
                let msg = "⏭️ SKIP: File is ignored: \(url.lastPathComponent)"
                print(msg)
                if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                    log.append(msg + "\n")
                    try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
                }
                continue
            }

            // Skip if already processed
            let isProcessed = FolderMonitorService.shared.processedFiles.contains(url.path)
            if isProcessed {
                let msg = "⏭️ SKIP: Already processed: \(url.lastPathComponent)"
                print(msg)
                if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                    log.append(msg + "\n")
                    try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
                }
                continue
            }

            // Skip if transcription already exists
            let transcriptionExists = FileSystemHelper.shared.transcriptionFileExists(for: url)
            if transcriptionExists {
                let msg = "⏭️ SKIP: Transcription exists: \(url.lastPathComponent)"
                print(msg)
                if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                    log.append(msg + "\n")
                    try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
                }
                FolderMonitorService.shared.markAsProcessed(url)
                continue
            }

            let startMsg = "▶️ Starting transcription: \(url.lastPathComponent)"
            print(startMsg)
            if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                log.append(startMsg + "\n")
                try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
            }

            do {
                try await transcribeFile(url)
                print("✅ Completed transcription: \(url.lastPathComponent)")
            } catch {
                print("❌ Transcription failed for \(url.lastPathComponent): \(error)")
                // Mark as processed even if failed, so it doesn't keep appearing
                // The metadata status is already set to .failed in the error handler
                FolderMonitorService.shared.markAsProcessed(url)
                print("   ✅ Marked failed file as processed in FolderMonitorService")
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

    /// Check if a file is already in the transcription queue
    func isInQueue(_ url: URL) -> Bool {
        return taskQueue.contains { $0.path == url.path }
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

    /// Insert marks into transcription text based on segment timestamps
    private func insertMarks(in text: String, marks: [Double], segments: [TranscriptionSegment]) -> String {
        guard !marks.isEmpty, !segments.isEmpty else { return text }

        // Sort marks by timestamp
        let sortedMarks = marks.sorted()

        // Create a list of (position, markNumber) to insert
        var insertions: [(segmentIndex: Int, markNumber: Int)] = []

        for (markIndex, markTime) in sortedMarks.enumerated() {
            // Find the segment that contains or is closest to this mark time
            var closestSegmentIndex = 0
            var closestDistance = Double.infinity

            for (index, segment) in segments.enumerated() {
                // Check if mark is within this segment
                if markTime >= segment.start && markTime <= segment.end {
                    closestSegmentIndex = index
                    break
                }

                // Check distance to segment start
                let distance = abs(segment.start - markTime)
                if distance < closestDistance {
                    closestDistance = distance
                    closestSegmentIndex = index
                }
            }

            insertions.append((segmentIndex: closestSegmentIndex, markNumber: markIndex + 1))
        }

        // Sort insertions by segment index (descending) so we can insert from end to start
        insertions.sort { $0.segmentIndex > $1.segmentIndex }

        // Build result by inserting marks before segments
        var result = text
        var processedSegments = segments

        for insertion in insertions.reversed() {
            let segment = processedSegments[insertion.segmentIndex]
            let markText = "[Mark \(insertion.markNumber)]"

            // Find the segment text in the full transcription
            if let range = result.range(of: segment.text) {
                // Insert mark before the segment
                result.insert(contentsOf: markText + " ", at: range.lowerBound)
            }
        }

        return result
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
