//
//  FolderMonitorService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import Combine

@MainActor
class FolderMonitorService: ObservableObject {
    static let shared = FolderMonitorService()

    @Published var isMonitoring = false
    @Published var monitoredFolder: URL?
    @Published var pendingFiles: [URL] = []
    @Published var processedFiles: Set<String> = []

    private var eventStream: FSEventStreamRef?
    private var monitorTask: Task<Void, Never>?
    private let fileProcessQueue = DispatchQueue(label: "dk.omdethele.SkrivDetNed.fileProcess", qos: .userInitiated)
    private let debounceInterval: TimeInterval = 3.0

    private var pendingFileTimers: [URL: Task<Void, Never>] = [:]

    private init() {
        // Load processed files from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "processedFiles"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            processedFiles = decoded
        }
    }

    func startMonitoring(folder: URL) {
        guard !isMonitoring else { return }

        self.monitoredFolder = folder
        self.isMonitoring = true

        // Start FSEvents monitoring
        setupFSEvents(for: folder)

        // Initial scan of folder
        Task {
            await scanFolderForNewFiles(folder)
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoredFolder = nil

        // Stop FSEvents
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }

        // Cancel pending timers
        for (_, timer) in pendingFileTimers {
            timer.cancel()
        }
        pendingFileTimers.removeAll()

        monitorTask?.cancel()
        monitorTask = nil
    }

    func clearPendingQueue() {
        // Cancel all pending timers
        for (_, timer) in pendingFileTimers {
            timer.cancel()
        }
        pendingFileTimers.removeAll()

        // Clear pending files
        pendingFiles.removeAll()
        print("🗑️ Cleared pending queue")
    }

    func removePendingFile(_ url: URL) {
        // Cancel timer for this file
        pendingFileTimers[url]?.cancel()
        pendingFileTimers[url] = nil

        // Remove from pending files
        pendingFiles.removeAll { $0 == url }
        print("🗑️ Removed pending file: \(url.lastPathComponent)")
    }

    private func setupFSEvents(for folder: URL) {
        let pathsToWatch = [folder.path] as CFArray
        let callback: FSEventStreamCallback = { streamRef, contextInfo, numEvents, eventPaths, eventFlags, eventIds in
            guard let contextInfo = contextInfo else { return }

            let service = Unmanaged<FolderMonitorService>.fromOpaque(contextInfo).takeUnretainedValue()

            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]

            Task { @MainActor in
                for path in paths {
                    let url = URL(fileURLWithPath: path)
                    await service.handleFileSystemEvent(at: url)
                }
            }
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            self.eventStream = stream
        }
    }

    private func handleFileSystemEvent(at url: URL) async {
        guard isMonitoring,
              let monitoredFolder = monitoredFolder,
              url.path.hasPrefix(monitoredFolder.path) else {
            return
        }

        // Check if it's an audio file
        guard FileSystemHelper.shared.isAudioFile(url) else {
            return
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        // Check if already processed
        guard !processedFiles.contains(url.path) else {
            return
        }

        // Check if transcription already exists
        guard !FileSystemHelper.shared.transcriptionFileExists(for: url) else {
            return
        }

        // Check if it's an iCloud placeholder
        if iCloudHelper.shared.isICloudPlaceholder(url) {
            // Try to start download
            try? iCloudHelper.shared.startDownloading(url)
            return
        }

        // Debounce: wait for file to be stable
        // Cancel existing timer for this file
        pendingFileTimers[url]?.cancel()

        // Create new timer
        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // Check if file is stable
            if await FileSystemHelper.shared.isStableFile(at: url) {
                // Handle iCloud download if needed
                if iCloudHelper.shared.isICloudURL(url) {
                    do {
                        try iCloudHelper.shared.startDownloading(url)
                        let downloaded = try await iCloudHelper.shared.waitForDownload(url, timeout: 120)
                        if !downloaded {
                            print("Failed to download iCloud file: \(url.path)")
                            return
                        }
                    } catch {
                        print("Error downloading iCloud file: \(error)")
                        return
                    }
                }

                // Add to pending queue
                await addToPendingQueue(url)
            }

            // Remove timer
            await MainActor.run {
                pendingFileTimers[url] = nil
            }
        }

        pendingFileTimers[url] = timer
    }

    private func scanFolderForNewFiles(_ folder: URL) async {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            // Check if it's an audio file
            guard FileSystemHelper.shared.isAudioFile(fileURL) else {
                continue
            }

            // Check if already processed
            guard !processedFiles.contains(fileURL.path) else {
                continue
            }

            // Check if transcription already exists
            guard !FileSystemHelper.shared.transcriptionFileExists(for: fileURL) else {
                continue
            }

            // Add to pending queue
            await handleFileSystemEvent(at: fileURL)
        }
    }

    private func addToPendingQueue(_ url: URL) async {
        guard !pendingFiles.contains(url) else { return }

        pendingFiles.append(url)

        // Notify transcription manager
        NotificationCenter.default.post(
            name: NSNotification.Name("NewAudioFileDetected"),
            object: nil,
            userInfo: ["url": url]
        )
    }

    func markAsProcessed(_ url: URL) {
        processedFiles.insert(url.path)
        pendingFiles.removeAll { $0 == url }

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(processedFiles) {
            UserDefaults.standard.set(encoded, forKey: "processedFiles")
        }
    }

    func removeFromPending(_ url: URL) {
        pendingFiles.removeAll { $0 == url }
    }

    func clearProcessedHistory() {
        processedFiles.removeAll()
        UserDefaults.standard.removeObject(forKey: "processedFiles")
    }
}
