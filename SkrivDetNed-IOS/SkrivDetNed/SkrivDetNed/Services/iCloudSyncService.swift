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
    @Published var uploadProgress: Double = 0

    private var metadataQuery: NSMetadataQuery?
    private let containerIdentifier = "iCloud.dk.omdethele.SkrivDetNed"
    private var transcriptionCallbacks: [String: (String) -> Void] = [:]
    private var activeUploads: [String: Recording] = [:]

    private init() {
        checkiCloudAvailability()
        setupBackgroundSupport()
        setupMetadataMonitoring()
    }

    /// Setup background upload support
    private func setupBackgroundSupport() {
        // Enable ubiquitous item coordination for background uploads
        // iCloud Drive automatically handles background uploads
        print("🔧 Background upload support enabled via iCloud Drive")
    }

    /// Setup metadata monitoring for real-time updates
    private func setupMetadataMonitoring() {
        guard isAvailable else {
            print("⚠️ Cannot setup metadata monitoring - iCloud not available")
            return
        }

        metadataQuery = NSMetadataQuery()
        guard let query = metadataQuery else { return }

        // Search for .json metadata files in iCloud
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)

        // Observe for updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: NSNotification.Name.NSMetadataQueryDidUpdate,
            object: query
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering),
            name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.start()
        print("✅ Metadata monitoring started - listening for changes")
    }

    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        print("📊 Metadata query finished initial gathering")
        Task { @MainActor in
            await processMetadataUpdates()
        }
    }

    @objc private func metadataQueryDidUpdate(_ notification: Notification) {
        print("🔄 Metadata query detected changes")
        Task { @MainActor in
            await processMetadataUpdates()
        }
    }

    private func processMetadataUpdates() async {
        guard let query = metadataQuery else { return }
        guard let recordingsFolder = getRecordingsFolderURL() else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        print("📝 Processing \(query.resultCount) metadata files")

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                  let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                continue
            }

            // Only process .json files in Recordings folder
            guard fileName.hasSuffix(".json"),
                  url.path.contains("Recordings") else {
                continue
            }

            // Load and check metadata
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                guard let metadata = try? decoder.decode(RecordingMetadata.self, from: data) else {
                    continue
                }

                // Update local recording with new status/transcription
                await updateLocalRecordingStatus(audioFileName: metadata.audioFileName, metadata: metadata)

                // If completed and has transcription, download it
                if metadata.status == .completed,
                   let transcriptionFileName = metadata.transcriptionFileName {
                    let transcriptionURL = recordingsFolder.appendingPathComponent(transcriptionFileName)

                    if FileManager.default.fileExists(atPath: transcriptionURL.path),
                       let transcription = try? String(contentsOf: transcriptionURL, encoding: .utf8) {
                        await updateLocalRecording(audioFileName: metadata.audioFileName, transcription: transcription)
                        print("📥 Downloaded transcription for \(metadata.audioFileName)")
                    }
                }

            } catch {
                print("⚠️ Failed to process metadata file \(fileName): \(error)")
            }
        }
    }

    /// Check if iCloud is available
    func checkiCloudAvailability() {
        Task.detached {
            let token = FileManager.default.ubiquityIdentityToken
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: self.containerIdentifier)

            await MainActor.run {
                self.isAvailable = token != nil && containerURL != nil
                if self.isAvailable {
                    print("✅ iCloud is available")
                    print("📱 iCloud identity token: \(token != nil ? "present" : "missing")")
                    print("📁 iCloud container: \(containerURL?.path ?? "not accessible")")
                } else {
                    print("⚠️ iCloud is not available")
                    if token == nil {
                        print("   - User needs to sign in to iCloud")
                    }
                    if containerURL == nil {
                        print("   - Container not accessible - check entitlements and provisioning")
                    }
                }
            }
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

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: recordingsURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("📁 Created Recordings folder in iCloud")
            } catch {
                print("❌ Failed to create Recordings folder: \(error)")
                return nil
            }
        }

        return recordingsURL
    }

    /// Upload recording to iCloud
    func uploadRecording(_ recording: Recording) async throws {
        print("📤 Upload requested for: \(recording.fileName)")
        print("   - isAvailable: \(isAvailable)")

        guard isAvailable else {
            print("❌ Upload failed: iCloud not available")
            throw iCloudError.notSignedIn
        }

        print("   - Getting recordings folder...")
        guard let recordingsFolder = getRecordingsFolderURL() else {
            print("❌ Upload failed: Could not get recordings folder URL")
            throw iCloudError.containerNotAvailable
        }

        print("   - Recordings folder: \(recordingsFolder.path)")
        print("   - Local file exists: \(FileManager.default.fileExists(atPath: recording.localURL.path))")

        // Track active upload
        activeUploads[recording.fileName] = recording

        isSyncing = true
        uploadProgress = 0

        do {
            // Copy audio file to iCloud
            let destinationURL = recordingsFolder.appendingPathComponent(recording.fileName)

            // Check if file already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("⚠️ File already exists in iCloud, removing old version")
                try FileManager.default.removeItem(at: destinationURL)
            }

            print("📤 Uploading \(recording.fileName) to iCloud...")

            // Use NSFileCoordinator for reliable iCloud uploads
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(
                writingItemAt: destinationURL,
                options: .forReplacing,
                error: &coordinatorError
            ) { url in
                do {
                    try FileManager.default.copyItem(at: recording.localURL, to: url)
                } catch {
                    print("❌ Coordinator copy failed: \(error)")
                }
            }

            if let error = coordinatorError {
                throw error
            }

            uploadProgress = 0.5

            // Mark file for upload
            try (destinationURL as NSURL).setResourceValue(
                true,
                forKey: .isUbiquitousItemKey
            )

            // Create metadata
            var metadata = RecordingMetadata(
                audioFileName: recording.fileName,
                createdOnDevice: "iOS"
            )
            metadata.status = .pending
            metadata.title = recording.title
            metadata.tags = recording.tags
            metadata.notes = recording.notes
            metadata.duration = recording.duration

            try metadata.save(to: recordingsFolder)
            uploadProgress = 1.0

            print("✅ Successfully uploaded \(recording.fileName) to iCloud")

            // Notify user if enabled
            if AppSettings.shared.showNotifications {
                await NotificationService.shared.notifyUploadComplete(for: recording.title)
            }

            // Start monitoring for transcription
            startMonitoringTranscription(for: recording.fileName)

            // Remove from active uploads
            activeUploads.removeValue(forKey: recording.fileName)

            isSyncing = false

        } catch {
            isSyncing = false
            uploadProgress = 0
            activeUploads.removeValue(forKey: recording.fileName)

            print("❌ Failed to upload recording: \(error)")

            // Notify user of failure
            if AppSettings.shared.showNotifications {
                await NotificationService.shared.notifyUploadFailed(
                    for: recording.title,
                    error: error.localizedDescription
                )
            }

            throw error
        }
    }

    /// Get upload progress for a recording
    func getUploadProgress(for fileName: String) -> Double? {
        guard activeUploads[fileName] != nil else { return nil }
        return uploadProgress
    }

    /// Check if a recording is currently uploading
    func isUploading(_ fileName: String) -> Bool {
        return activeUploads[fileName] != nil
    }

    /// Start monitoring iCloud for transcription updates
    func startMonitoringTranscription(for audioFileName: String, onComplete: ((String) -> Void)? = nil) {
        if let callback = onComplete {
            transcriptionCallbacks[audioFileName] = callback
        }

        if metadataQuery == nil {
            setupTranscriptionMonitoring()
        }
    }

    private func setupTranscriptionMonitoring() {
        // Re-check availability before starting
        if !isAvailable {
            checkiCloudAvailability()

            // Wait a bit for check to complete, then try again
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                await MainActor.run {
                    guard self.isAvailable else {
                        print("⚠️ Cannot start monitoring: iCloud not available after check")
                        return
                    }
                    self.startMonitoringQuery()
                }
            }
            return
        }

        startMonitoringQuery()
    }

    private func startMonitoringQuery() {
        stopMonitoring() // Stop any existing query

        metadataQuery = NSMetadataQuery()
        guard let query = metadataQuery else {
            print("❌ Failed to create NSMetadataQuery")
            return
        }

        // Search in iCloud Documents
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        // Look for .txt and .json files (transcriptions and metadata)
        let predicates = [
            NSPredicate(format: "%K LIKE[c] '*.txt'", NSMetadataItemFSNameKey),
            NSPredicate(format: "%K LIKE[c] '*.json'", NSMetadataItemFSNameKey)
        ]
        query.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

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

        query.start()
        print("🔍 Started monitoring iCloud for transcriptions")
    }

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        print("📊 iCloud query finished gathering. Found \(query.resultCount) files")

        for i in 0..<query.resultCount {
            if let item = query.result(at: i) as? NSMetadataItem {
                processMetadataItem(item)
            }
        }

        query.enableUpdates()
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        print("🔄 iCloud query updated")

        // Process updated items
        if let updatedItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] {
            for item in updatedItems {
                processMetadataItem(item)
            }
        }

        // Process new items
        if let addedItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedItems {
                processMetadataItem(item)
            }
        }

        query.enableUpdates()
    }

    private func processMetadataItem(_ item: NSMetadataItem) {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
            return
        }

        guard let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else {
            return
        }

        // Check download status
        let downloadStatus = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

        // Download if needed
        if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
            print("⬇️ Starting download for: \(fileName)")
            Task {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
            return
        }

        // Process downloaded transcription files
        if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent ||
           downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded {

            if fileName.hasSuffix(".txt") {
                handleTranscriptionFile(url: url, fileName: fileName)
            } else if fileName.hasSuffix(".json") {
                handleMetadataUpdate(url: url, fileName: fileName)
            }
        }
    }

    private func handleTranscriptionFile(url: URL, fileName: String) {
        Task {
            do {
                let transcription = try String(contentsOf: url, encoding: .utf8)
                let audioFileName = fileName.replacingOccurrences(of: ".txt", with: ".m4a")

                print("📥 Downloaded transcription for: \(audioFileName)")
                print("   Length: \(transcription.count) characters")

                // Update local recording with transcription
                await updateLocalRecording(audioFileName: audioFileName, transcription: transcription)

                // Call callback if registered
                if let callback = transcriptionCallbacks[audioFileName] {
                    callback(transcription)
                    transcriptionCallbacks.removeValue(forKey: audioFileName)
                }

            } catch {
                print("❌ Failed to read transcription: \(error)")
            }
        }
    }

    private func handleMetadataUpdate(url: URL, fileName: String) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let metadata = try decoder.decode(RecordingMetadata.self, from: data)

                print("📝 Metadata update for: \(metadata.audioFileName)")
                print("   Status: \(metadata.status.rawValue)")

                // Update local recording status
                await updateLocalRecordingStatus(audioFileName: metadata.audioFileName, metadata: metadata)

            } catch {
                print("❌ Failed to parse metadata: \(error)")
            }
        }
    }

    private func updateLocalRecording(audioFileName: String, transcription: String) async {
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for file in jsonFiles {
                guard let data = try? Data(contentsOf: file),
                      var recording = try? decoder.decode(Recording.self, from: data) else {
                    continue
                }

                if recording.fileName == audioFileName {
                    recording.transcriptionText = transcription
                    recording.hasTranscription = true
                    recording.cloudStatus = .completed

                    // Save updated recording
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let updatedData = try encoder.encode(recording)
                    try updatedData.write(to: file)

                    print("✅ Updated local recording with transcription")

                    // Post notification for UI update
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TranscriptionReceived"),
                            object: nil,
                            userInfo: ["audioFileName": audioFileName]
                        )
                    }

                    break
                }
            }
        } catch {
            print("❌ Failed to update local recording: \(error)")
        }
    }

    private func updateLocalRecordingStatus(audioFileName: String, metadata: RecordingMetadata) async {
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for file in jsonFiles {
                guard let data = try? Data(contentsOf: file),
                      var recording = try? decoder.decode(Recording.self, from: data) else {
                    continue
                }

                if recording.fileName == audioFileName {
                    // Update status based on metadata
                    switch metadata.status {
                    case .pending:
                        recording.cloudStatus = .pending
                        recording.errorMessage = nil
                    case .downloading:
                        recording.cloudStatus = .synced
                        recording.errorMessage = nil
                    case .transcribing:
                        recording.cloudStatus = .transcribing
                        recording.errorMessage = nil
                    case .completed:
                        recording.cloudStatus = .completed
                        recording.errorMessage = nil
                    case .failed:
                        recording.cloudStatus = .failed
                        recording.errorMessage = metadata.errorMessage
                    }

                    // Save updated recording
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let updatedData = try encoder.encode(recording)
                    try updatedData.write(to: file)

                    print("✅ Updated local recording status to: \(recording.cloudStatus.displayName)")
                    if let errorMsg = recording.errorMessage {
                        print("   Error: \(errorMsg)")
                    }

                    // Notify UI to refresh
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RecordingStatusChanged"),
                        object: nil,
                        userInfo: ["fileName": audioFileName]
                    )

                    break
                }
            }
        } catch {
            print("❌ Failed to update local recording status: \(error)")
        }
    }

    /// Stop monitoring iCloud
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)
        print("⏹️ Stopped monitoring iCloud")
    }

    /// Check for stuck transcriptions (files in "transcribing" state for too long)
    func checkForStuckTranscriptions() async {
        guard let recordingsFolder = getRecordingsFolderURL() else { return }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsFolder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let jsonFiles = files.filter { $0.pathExtension == "json" }

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

                    // If transcribing for more than 10 minutes, consider it stuck
                    if timeSinceUpdate > 600 {
                        print("⚠️ Found stuck transcription: \(metadata.audioFileName)")
                        print("   Time since update: \(Int(timeSinceUpdate / 60)) minutes")

                        // Check if transcription file actually exists
                        if let transcriptionFileName = metadata.transcriptionFileName {
                            let transcriptionURL = recordingsFolder.appendingPathComponent(transcriptionFileName)

                            if FileManager.default.fileExists(atPath: transcriptionURL.path) {
                                // Transcription exists! Update status to completed
                                metadata.status = .completed
                                try? metadata.save(to: recordingsFolder)
                                print("   ✅ Found transcription file - updated to completed")

                                // Update local recording
                                if let transcription = try? String(contentsOf: transcriptionURL, encoding: .utf8) {
                                    await updateLocalRecording(audioFileName: metadata.audioFileName, transcription: transcription)
                                }
                            } else {
                                // No transcription found - reset to pending
                                metadata.status = .pending
                                metadata.updatedAt = Date()
                                try? metadata.save(to: recordingsFolder)
                                print("   🔄 Reset to pending (transcription not found)")

                                // Update local recording
                                await updateLocalRecordingStatus(audioFileName: metadata.audioFileName, metadata: metadata)
                            }
                        } else {
                            // No transcription filename set - reset to pending
                            metadata.status = .pending
                            metadata.updatedAt = Date()
                            try? metadata.save(to: recordingsFolder)
                            print("   🔄 Reset to pending (no transcription filename)")

                            // Update local recording
                            await updateLocalRecordingStatus(audioFileName: metadata.audioFileName, metadata: metadata)
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to check for stuck transcriptions: \(error)")
        }
    }

    /// Check for existing transcriptions on startup
    func checkForExistingTranscriptions() async {
        guard let recordingsFolder = getRecordingsFolderURL() else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: recordingsFolder,
                includingPropertiesForKeys: [.nameKey, .isUbiquitousItemKey]
            )

            let transcriptionFiles = files.filter { $0.pathExtension == "txt" }

            for file in transcriptionFiles {
                let fileName = file.lastPathComponent
                handleTranscriptionFile(url: file, fileName: fileName)
            }

            print("✅ Checked for existing transcriptions: found \(transcriptionFiles.count)")

        } catch {
            print("❌ Failed to check for existing transcriptions: \(error)")
        }
    }
}

enum iCloudError: LocalizedError {
    case containerNotAvailable
    case notSignedIn
    case downloadFailed
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return "iCloud container er ikke tilgængelig"
        case .notSignedIn:
            return "Ikke logget ind på iCloud"
        case .downloadFailed:
            return "Download fra iCloud fejlede"
        case .uploadFailed:
            return "Upload til iCloud fejlede"
        }
    }
}
