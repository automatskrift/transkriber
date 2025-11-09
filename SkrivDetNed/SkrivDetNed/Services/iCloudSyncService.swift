//
//  iCloudSyncService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import Combine

@MainActor
class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()

    @Published var isAvailable = false
    @Published var isSyncing = false
    @Published var syncError: String?

    private var metadataQuery: NSMetadataQuery?
    private let containerIdentifier = "iCloud.dk.omdethele.SkrivDetNed"
    private var heartbeatTimer: Timer?

    private init() {
        Task {
            await checkiCloudAvailability()
        }
    }

    /// Check if iCloud is available
    func checkiCloudAvailability() async {
        let token = await Task.detached {
            FileManager.default.ubiquityIdentityToken
        }.value

        isAvailable = token != nil
        if isAvailable {
            print("✅ iCloud is available")
        } else {
            print("⚠️ iCloud is not available. User needs to sign in to iCloud.")
        }
    }

    /// Get the iCloud container URL
    func getiCloudContainerURL() -> URL? {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        ) else {
            print("❌ Failed to get iCloud container URL")
            return nil
        }

        let documentsURL = containerURL.appendingPathComponent("Documents")
        print("📁 iCloud container URL: \(documentsURL.path)")
        return documentsURL
    }

    /// Get the recordings folder in iCloud
    func getRecordingsFolderURL() -> URL? {
        guard let documentsURL = getiCloudContainerURL() else {
            return nil
        }

        let recordingsURL = documentsURL.appendingPathComponent("Recordings")

        // Check for duplicate folders (Recordings 2, etc.) and warn
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let duplicateFolders = contents.filter { url in
                let name = url.lastPathComponent
                return name.hasPrefix("Recordings") && name != "Recordings"
            }

            if !duplicateFolders.isEmpty {
                print("⚠️ WARNING: Found duplicate Recordings folders:")
                for folder in duplicateFolders {
                    print("   - \(folder.lastPathComponent)")
                }
                print("   This can happen due to iCloud sync conflicts.")
                print("   Please manually merge and delete duplicates in iCloud Drive.")
            }
        } catch {
            print("⚠️ Could not check for duplicate folders: \(error)")
        }

        // Check if directory exists - need to check both local existence and iCloud status
        var isDirectory: ObjCBool = false
        let localExists = FileManager.default.fileExists(atPath: recordingsURL.path, isDirectory: &isDirectory)

        if localExists && isDirectory.boolValue {
            print("📁 Recordings folder exists locally")
            return recordingsURL
        }

        // Check if it exists in iCloud but not downloaded yet
        if localExists {
            print("⚠️ Path exists but is not a directory!")
            // Don't try to create - something is wrong
            return recordingsURL
        }

        // Try to start downloading if it exists in iCloud
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: recordingsURL)
            print("📥 Started downloading Recordings folder from iCloud")
            // Check again after attempting download
            if FileManager.default.fileExists(atPath: recordingsURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                print("📁 Recordings folder downloaded successfully")
                return recordingsURL
            }
        } catch let error as NSError {
            // If error is "file doesn't exist", we need to create it
            if error.domain == NSCocoaErrorDomain && (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError) {
                print("📁 Recordings folder doesn't exist in iCloud, creating...")
            } else {
                print("⚠️ Download attempt error: \(error) - will try to create")
            }
        }

        // Directory doesn't exist locally or in iCloud - create it
        // Use NSFileCoordinator to avoid conflicts during creation
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var createError: Error?

        coordinator.coordinate(
            writingItemAt: recordingsURL,
            options: .forMerging,
            error: &coordinatorError
        ) { url in
            do {
                // Double-check if it exists now (another process might have created it)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                    print("📁 Recordings folder already exists (created during coordination)")
                    return
                }

                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("📁 Created Recordings folder in iCloud with coordination")
            } catch {
                createError = error
            }
        }

        if let error = coordinatorError ?? createError {
            let nsError = error as NSError
            // Ignore "already exists" error (can happen with race conditions)
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteFileExistsError {
                print("📁 Recordings folder already exists")
            } else {
                print("❌ Failed to create Recordings folder: \(error)")
                return nil
            }
        }

        return recordingsURL
    }

    /// Start monitoring iCloud for new audio files
    func startMonitoring(onNewFile: @escaping (URL) -> Void) {
        guard isAvailable else {
            print("⚠️ Cannot start monitoring: iCloud not available")
            return
        }

        stopMonitoring() // Stop any existing query

        metadataQuery = NSMetadataQuery()
        guard let query = metadataQuery else { return }

        // Get container URL to search in
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            print("❌ Cannot get container URL for monitoring")
            return
        }

        let documentsURL = containerURL.appendingPathComponent("Documents")
        print("🔍 Monitoring iCloud at: \(documentsURL.path)")

        // Search in specific iCloud container Documents folder
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        // Look for audio files in our Recordings folder
        let audioExtensions = ["m4a", "mp3", "wav", "aiff", "caf", "aac", "flac"]
        let extensionPredicates = audioExtensions.map { ext in
            NSPredicate(format: "%K LIKE[c] '*.\\(ext)'", NSMetadataItemFSNameKey)
        }

        // Also filter by path to only include our Recordings folder
        let pathPredicate = NSPredicate(format: "%K CONTAINS[c] 'Recordings'", NSMetadataItemPathKey)

        let extensionCompound = NSCompoundPredicate(orPredicateWithSubpredicates: extensionPredicates)
        query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [extensionCompound, pathPredicate])

        // Set up notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        // Store callback
        self.newFileCallback = onNewFile

        // Start the query
        if query.start() {
            print("✅ NSMetadataQuery started successfully")
            print("   Predicate: \(query.predicate?.description ?? "none")")
            print("   Search scopes: \(query.searchScopes)")
        } else {
            print("❌ Failed to start NSMetadataQuery")
        }

        // Enable live updates (important for real-time monitoring)
        query.enableUpdates()
        print("🔍 Started monitoring iCloud for new audio files (live updates enabled)")

        // Start periodic check as backup (every 30 seconds)
        // This helps catch files that NSMetadataQuery might miss
        periodicCheckTimer?.invalidate()
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { @Sendable [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicCheck()
            }
        }
        print("⏰ Started periodic check timer (every 30s)")
    }

    /// Periodic check for new files (backup for NSMetadataQuery)
    private func performPeriodicCheck() async {
        guard let recordingsURL = getRecordingsFolderURL() else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let audioExtensions = ["m4a", "mp3", "wav", "aiff", "caf", "aac", "flac"]
            let audioFiles = files.filter { url in
                audioExtensions.contains(url.pathExtension.lowercased())
            }

            // Check for new files (not in existing files list and not transcribed)
            for audioFile in audioFiles {
                // Skip if ignored
                if AppSettings.shared.ignoredFiles.contains(audioFile.path) {
                    continue
                }

                // Skip if already has transcription
                let transcriptionURL = audioFile.deletingPathExtension().appendingPathExtension("txt")
                if FileManager.default.fileExists(atPath: transcriptionURL.path) {
                    continue
                }

                // Check if we've already processed this file
                if !existingFiles.contains(audioFile) && !hasBeenNotified(audioFile) {
                    print("🔔 Periodic check found new file: \(audioFile.lastPathComponent)")
                    newFileCallback?(audioFile)
                    markAsNotified(audioFile)
                }
            }
        } catch {
            print("⚠️ Periodic check failed: \(error)")
        }
    }

    // Track files we've already notified about
    private var notifiedFiles: Set<String> = []

    private func hasBeenNotified(_ url: URL) -> Bool {
        return notifiedFiles.contains(url.path)
    }

    private func markAsNotified(_ url: URL) {
        notifiedFiles.insert(url.path)
    }

    private var newFileCallback: ((URL) -> Void)?
    private var periodicCheckTimer: Timer?

    private var shouldProcessExistingFiles = false
    private var existingFiles: [URL] = []
    private var hasGatheredOnce = false

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        print("📊 iCloud query finished gathering. Found \(query.resultCount) files")

        // Debug: List ALL files found
        if query.resultCount > 0 {
            print("📋 Files found by query:")
            for i in 0..<query.resultCount {
                if let item = query.result(at: i) as? NSMetadataItem,
                   let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                   let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                    print("   - \(fileName) at \(path)")
                }
            }
        } else {
            // Fallback: NSMetadataQuery didn't find files, try direct file system scan
            print("⚠️ NSMetadataQuery found 0 files, trying direct file system scan...")
            scanDirectoryForFiles()
        }

        print("📊 hasGatheredOnce: \(hasGatheredOnce), resultCount: \(query.resultCount)")

        if !hasGatheredOnce {
            // First time - collect existing files
            print("🔄 First time gathering - scanning for existing files")
            hasGatheredOnce = true
            existingFiles.removeAll()

            for i in 0..<query.resultCount {
                if let item = query.result(at: i) as? NSMetadataItem,
                   let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                   let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String {

                    print("🔍 Checking file: \(fileName)")

                    // Skip .json and .txt files
                    guard !fileName.hasSuffix(".json") && !fileName.hasSuffix(".txt") else {
                        print("   ⏭️ Skipping metadata/transcription file")
                        continue
                    }

                    // Skip if file is ignored
                    if AppSettings.shared.ignoredFiles.contains(url.path) {
                        print("   ⏭️ Skipping ignored file")
                        continue
                    }

                    let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
                    print("   📥 Download status: \(downloadStatus ?? "unknown")")

                    if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent ||
                       downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded {

                        // Check if transcription already exists
                        let transcriptionURL = url.deletingPathExtension().appendingPathExtension("txt")
                        if FileManager.default.fileExists(atPath: transcriptionURL.path) {
                            print("   ⏭️ Already transcribed (found .txt file)")
                            continue
                        }

                        // Check metadata status
                        if let recordingsFolder = getRecordingsFolderURL(),
                           let metadata = try? RecordingMetadata.load(for: fileName, from: recordingsFolder) {
                            print("   📋 Loaded metadata - status: \(metadata.status.rawValue)")
                            // Skip if already completed
                            if metadata.status == .completed {
                                print("   ⏭️ Already completed (metadata status: completed)")
                                continue
                            }
                            // Skip if failed
                            if metadata.status == .failed {
                                print("   ⏭️ Previously failed (metadata status: failed)")
                                continue
                            }
                            // Skip if transcribing (will be handled by resetStuckTranscriptions)
                            if metadata.status == .transcribing {
                                print("   ⏭️ Currently transcribing (will be handled by stuck transcriptions check)")
                                continue
                            }
                            print("   📝 Metadata status: \(metadata.status.rawValue) - will be added to existing files")
                        } else {
                            print("   ⚠️ No metadata found for \(fileName) - will be added to existing files")
                        }

                        existingFiles.append(url)
                        print("   ✅ Added to existing files")
                    } else {
                        print("   ⏭️ Not downloaded yet")
                    }
                }
            }

            print("📂 Found \(existingFiles.count) existing audio file(s) needing transcription")

            // Notify that existing files are ready (only if there are any)
            if !existingFiles.isEmpty {
                print("🔔 Posting ExistingFilesFound notification with count: \(existingFiles.count)")
                print("   Files: \(existingFiles.map { $0.lastPathComponent })")
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ExistingFilesFound"),
                        object: nil,
                        userInfo: ["count": existingFiles.count]
                    )
                }
            } else {
                print("✅ No files need transcription (all are either transcribed or ignored)")
            }
        } else {
            // Subsequent gathers - process normally
            for i in 0..<query.resultCount {
                if let item = query.result(at: i) as? NSMetadataItem {
                    processMetadataItem(item, isNewFile: false)
                }
            }
        }

        query.enableUpdates()
    }

    /// Scan directory directly for files (fallback when NSMetadataQuery fails)
    private func scanDirectoryForFiles() {
        guard let recordingsURL = getRecordingsFolderURL() else {
            print("❌ Cannot get recordings folder URL for direct scan")
            return
        }

        print("📂 Scanning directory: \(recordingsURL.path)")

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsURL,
                includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
                options: [.skipsHiddenFiles]
            )

            print("📋 Found \(files.count) total files in directory")

            let audioExtensions = ["m4a", "mp3", "wav", "aiff", "caf", "aac", "flac"]
            let audioFiles = files.filter { url in
                audioExtensions.contains(url.pathExtension.lowercased())
            }

            print("🎵 Found \(audioFiles.count) audio files")

            if !hasGatheredOnce && !audioFiles.isEmpty {
                hasGatheredOnce = true

                // Filter out files that already have transcriptions or are ignored
                existingFiles = audioFiles.filter { audioURL in
                    // Skip ignored files
                    if AppSettings.shared.ignoredFiles.contains(audioURL.path) {
                        print("   ⏭️ Skipping \(audioURL.lastPathComponent) - ignored")
                        return false
                    }

                    // Skip already transcribed files
                    let transcriptionURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
                    let hasTranscription = FileManager.default.fileExists(atPath: transcriptionURL.path)
                    if hasTranscription {
                        print("   ⏭️ Skipping \(audioURL.lastPathComponent) - already transcribed")
                        return false
                    }

                    // Check metadata status
                    if let metadata = try? RecordingMetadata.load(for: audioURL.lastPathComponent, from: recordingsURL) {
                        print("   📋 \(audioURL.lastPathComponent) metadata status: \(metadata.status.rawValue)")
                        // Skip if already completed
                        if metadata.status == .completed {
                            print("   ⏭️ Skipping \(audioURL.lastPathComponent) - completed")
                            return false
                        }
                        // Skip if failed
                        if metadata.status == .failed {
                            print("   ⏭️ Skipping \(audioURL.lastPathComponent) - failed")
                            return false
                        }
                        // Skip if transcribing (will be handled by resetStuckTranscriptions)
                        if metadata.status == .transcribing {
                            print("   ⏭️ Skipping \(audioURL.lastPathComponent) - transcribing (handled elsewhere)")
                            return false
                        }
                    } else {
                        print("   ⚠️ No metadata found for \(audioURL.lastPathComponent)")
                    }

                    return true
                }

                print("📂 Found \(existingFiles.count) existing audio file(s) needing transcription via direct scan")

                // Notify that existing files are ready (only if there are any)
                if !existingFiles.isEmpty {
                    print("🔔 Posting ExistingFilesFound notification (direct scan) with count: \(existingFiles.count)")
                    print("   Files: \(existingFiles.map { $0.lastPathComponent })")
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExistingFilesFound"),
                            object: nil,
                            userInfo: ["count": existingFiles.count]
                        )
                    }
                } else {
                    print("✅ No files need transcription (all are either transcribed or ignored)")
                }
            }
        } catch {
            print("❌ Failed to scan directory: \(error)")
        }
    }

    /// Process existing files that were found on startup
    func processExistingFiles() {
        print("📥 Processing \(existingFiles.count) existing files")
        for url in existingFiles {
            newFileCallback?(url)
        }
        existingFiles.removeAll()
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()

        let addedCount = (notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem])?.count ?? 0
        let changedCount = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.count ?? 0
        let removedCount = (notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem])?.count ?? 0

        print("🔄 iCloud query updated: +\(addedCount) ~\(changedCount) -\(removedCount)")

        // Process new files
        if let addedItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            print("   Processing \(addedItems.count) new item(s)")
            for item in addedItems {
                processMetadataItem(item, isNewFile: true)
            }
        }

        query.enableUpdates()
    }

    private func processMetadataItem(_ item: NSMetadataItem, isNewFile: Bool) {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
            return
        }

        guard let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else {
            return
        }

        // Check download status
        let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

        print("📄 File: \(fileName)")
        print("   Status: \(downloadStatus ?? "unknown")")
        print("   URL: \(url.path)")

        // Only process files that are downloaded or downloading
        if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent ||
           downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded {

            // Skip .json metadata files
            guard !fileName.hasSuffix(".json") && !fileName.hasSuffix(".txt") else {
                return
            }

            if isNewFile {
                print("✨ New audio file detected: \(fileName)")
                markAsNotified(url)
                newFileCallback?(url)
            }
        } else if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
            // Start download
            print("⬇️ Starting download for: \(fileName)")
            Task {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
        }
    }

    /// Stop monitoring iCloud
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)

        // Stop periodic check timer
        periodicCheckTimer?.invalidate()
        periodicCheckTimer = nil

        print("⏹️ Stopped monitoring iCloud")
    }

    /// Save transcription result to iCloud
    func saveTranscriptionToiCloud(audioFileName: String, transcription: String) async throws {
        guard let recordingsFolder = getRecordingsFolderURL() else {
            throw iCloudError.containerNotAvailable
        }

        // Load metadata to check for promptPrefix
        var metadata = try RecordingMetadata.load(for: audioFileName, from: recordingsFolder)
            ?? RecordingMetadata(audioFileName: audioFileName, createdOnDevice: "macOS")

        // Debug metadata
        print("🔍 DEBUG Metadata loaded (macOS):")
        print("   audioFileName: \(audioFileName)")
        print("   metadata.promptPrefix: \(String(describing: metadata.promptPrefix))")
        print("   metadata.title: \(String(describing: metadata.title))")

        // Prepare final transcription text with prompt prefix if available
        var finalTranscription = transcription
        if let promptPrefix = metadata.promptPrefix, !promptPrefix.isEmpty {
            finalTranscription = promptPrefix + transcription
            print("✨ Prepending prompt prefix to transcription")
            print("   Prompt: \(promptPrefix.prefix(100))...")
            print("   Original transcription length: \(transcription.count)")
            print("   Final transcription length: \(finalTranscription.count)")
        } else {
            print("📝 No prompt prefix to prepend")
            if metadata.promptPrefix == nil {
                print("   Reason: promptPrefix is nil")
            } else if metadata.promptPrefix?.isEmpty == true {
                print("   Reason: promptPrefix is empty")
            }
        }

        // Create .txt file name
        let baseName = (audioFileName as NSString).deletingPathExtension
        let transcriptionFileName = "\(baseName).txt"
        let transcriptionURL = recordingsFolder.appendingPathComponent(transcriptionFileName)

        // Write transcription with prompt prefix
        try finalTranscription.write(to: transcriptionURL, atomically: true, encoding: .utf8)
        print("💾 Saved transcription to iCloud: \(transcriptionFileName)")

        // Update metadata
        metadata.status = .completed
        metadata.transcriptionFileName = transcriptionFileName
        metadata.updatedAt = Date()
        metadata.transcribedOnDevice = "macOS"

        try metadata.save(to: recordingsFolder)
        print("📝 Updated metadata for: \(audioFileName)")
    }

    /// Update metadata status
    func updateMetadataStatus(audioFileName: String, status: RecordingStatus) async throws {
        guard let recordingsFolder = getRecordingsFolderURL() else {
            throw iCloudError.containerNotAvailable
        }

        var metadata = try RecordingMetadata.load(for: audioFileName, from: recordingsFolder)
            ?? RecordingMetadata(audioFileName: audioFileName, createdOnDevice: "Unknown")

        metadata.status = status
        metadata.updatedAt = Date()

        try metadata.save(to: recordingsFolder)
    }

    /// Check for pending files that need transcription
    func checkForPendingFiles() async -> [URL] {
        guard let recordingsFolder = getRecordingsFolderURL() else {
            return []
        }

        var pendingFiles: [URL] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsFolder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let jsonFiles = files.filter {
                $0.pathExtension == "json" &&
                $0.lastPathComponent != ".mac_heartbeat.json" &&
                !$0.lastPathComponent.contains(" 2.json") &&
                !$0.lastPathComponent.contains(" 3.json") &&
                !$0.lastPathComponent.contains(" 4.json")
            }

            for jsonFile in jsonFiles {
                guard let data = try? Data(contentsOf: jsonFile) else { continue }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                guard let metadata = try? decoder.decode(RecordingMetadata.self, from: data) else {
                    continue
                }

                // Check if status is pending
                if metadata.status == .pending {
                    let audioURL = recordingsFolder.appendingPathComponent(metadata.audioFileName)

                    // Verify audio file exists
                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        // Verify transcription doesn't exist
                        let transcriptionURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
                        if !FileManager.default.fileExists(atPath: transcriptionURL.path) {
                            print("🔄 Found pending file for retry: \(metadata.audioFileName)")
                            pendingFiles.append(audioURL)
                        }
                    }
                }
            }

            if !pendingFiles.isEmpty {
                print("📋 Found \(pendingFiles.count) pending file(s) to retry")
            }

        } catch {
            print("❌ Failed to check for pending files: \(error)")
        }

        return pendingFiles
    }
}

enum iCloudError: LocalizedError {
    case containerNotAvailable
    case notSignedIn
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return NSLocalizedString("iCloud container er ikke tilgængelig", comment: "")
        case .notSignedIn:
            return NSLocalizedString("Ikke logget ind på iCloud", comment: "")
        case .downloadFailed:
            return NSLocalizedString("Download fra iCloud fejlede", comment: "")
        }
    }
}

// MARK: - Heartbeat
extension iCloudSyncService {
    /// Start heartbeat - writes timestamp to iCloud every minute
    func startHeartbeat() {
        // Write initial heartbeat
        writeHeartbeat()

        // Schedule periodic heartbeat every 60 seconds
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                self?.writeHeartbeat()
            }
        }
        print("💓 Heartbeat timer started (every 60 seconds)")
    }

    /// Stop heartbeat timer
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        print("💔 Heartbeat timer stopped")
    }

    /// Write current timestamp to heartbeat file
    private func writeHeartbeat() {
        guard let recordingsFolder = getRecordingsFolderURL() else {
            print("⚠️ Cannot write heartbeat: recordings folder not available")
            return
        }

        let heartbeatURL = recordingsFolder.appendingPathComponent(".mac_heartbeat.json")
        let heartbeatData: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "device": "macOS"
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: heartbeatData, options: .prettyPrinted)
            try jsonData.write(to: heartbeatURL)
            print("💓 Heartbeat written: \(Date())")
        } catch {
            print("❌ Failed to write heartbeat: \(error)")
        }
    }

    /// Read the last heartbeat from iCloud
    func getLastHeartbeat() -> Date? {
        guard let recordingsFolder = getRecordingsFolderURL() else {
            return nil
        }

        let heartbeatURL = recordingsFolder.appendingPathComponent(".mac_heartbeat.json")

        guard FileManager.default.fileExists(atPath: heartbeatURL.path),
              let jsonData = try? Data(contentsOf: heartbeatURL),
              let heartbeatData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let timestampString = heartbeatData["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
            return nil
        }

        return timestamp
    }
}
