//
//  FolderMonitorViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FolderMonitorViewModel: ObservableObject {
    static let shared = FolderMonitorViewModel()

    @Published var isMonitoring = false {
        didSet {
            MenuBarManager.shared.isMonitoring = isMonitoring
        }
    }
    @Published var selectedFolderURL: URL?
    @Published var pendingFiles: [URL] = []
    @Published var recentlyCompleted: [TranscriptionTask] = []
    @Published var showExistingFilesPrompt = false
    @Published var existingFilesCount = 0
    @Published var errorMessage: String?
    @Published var showError = false

    // iCloud file categories
    @Published var iCloudQueuedFiles: [(url: URL, metadata: RecordingMetadata)] = []
    @Published var iCloudCompletedFiles: [(url: URL, metadata: RecordingMetadata)] = []
    @Published var iCloudFailedFiles: [(url: URL, metadata: RecordingMetadata)] = []

    private let monitorService = FolderMonitorService.shared
    private let transcriptionVM = TranscriptionViewModel.shared
    private let iCloudService = iCloudSyncService.shared
    private let settings = AppSettings.shared
    private var iCloudRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let initMsg = "🏁 FolderMonitorViewModel INIT at \(Date()) - iCloudSyncEnabled: \(settings.iCloudSyncEnabled)"
        print(initMsg)
        try? initMsg.appending("\n").write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)

        setupObservers()
        loadSavedFolder()
        setupiCloudMonitoring()

        // Start refresh timer for iCloud files (every 5 seconds)
        if settings.iCloudSyncEnabled {
            let timerMsg = "   ✅ Starting iCloud refresh timer (every 5s)"
            print(timerMsg)
            if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                log.append(timerMsg + "\n")
                try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
            }

            iCloudRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshiCloudFileLists()
                }
            }
            // Initial refresh - delayed to not block app startup
            Task {
                // Wait 1 second before first refresh to let UI show up
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await refreshiCloudFileLists()
            }
        } else {
            let noTimerMsg = "   ❌ iCloud sync disabled - no refresh timer"
            print(noTimerMsg)
            if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                log.append(noTimerMsg + "\n")
                try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
            }
        }
    }

    deinit {
        iCloudRefreshTimer?.invalidate()
    }

    private func setupiCloudMonitoring() {
        // Start iCloud monitoring if enabled
        print("🔧 setupiCloudMonitoring called, iCloudSyncEnabled: \(settings.iCloudSyncEnabled)")

        if settings.iCloudSyncEnabled {
            // Don't block app startup - do this in background
            Task.detached { [weak self] in
                guard let self = self else { return }

                // Check availability first
                print("🔍 Checking iCloud availability...")
                await iCloudSyncService.shared.checkiCloudAvailability()

                // Wait a moment for iCloud to be ready
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Start monitoring
                await MainActor.run {
                    print("🚀 Starting iCloud monitoring...")
                    iCloudSyncService.shared.startMonitoring { [weak self] url in
                        Task { @MainActor in
                            await self?.handleiCloudFile(url)
                        }
                    }
                }

                // Check for pending files that need retry
                let pendingFiles = await self.iCloudService.checkForPendingFiles()
                if !pendingFiles.isEmpty {
                    await MainActor.run {
                        print("🔄 Processing \(pendingFiles.count) pending file(s) for retry")
                    }
                    for url in pendingFiles {
                        await self.handleiCloudFile(url)
                    }
                }
            }
        } else {
            print("⏭️ iCloud monitoring disabled in settings")
        }
    }

    private func handleiCloudFile(_ url: URL) async {
        print("📱 New file from iCloud: \(url.lastPathComponent)")

        // Update metadata status
        try? await iCloudService.updateMetadataStatus(
            audioFileName: url.lastPathComponent,
            status: .transcribing
        )

        // Add to transcription queue
        await transcriptionVM.addToQueue(url)
    }

    private func setupObservers() {
        // Observe folder monitor service
        monitorService.$isMonitoring
            .assign(to: &$isMonitoring)

        monitorService.$monitoredFolder
            .assign(to: &$selectedFolderURL)

        monitorService.$pendingFiles
            .assign(to: &$pendingFiles)

        // Observe errors from folder monitor service
        monitorService.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.errorMessage = error
                    self?.showError = true
                }
            }
            .store(in: &cancellables)

        // Observe transcription completed tasks
        transcriptionVM.$completedTasks
            .map { Array($0.prefix(10)) }
            .assign(to: &$recentlyCompleted)

        // Observe existing files found
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExistingFilesFound"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let count = notification.userInfo?["count"] as? Int else { return }
            Task { @MainActor [weak self] in
                self?.existingFilesCount = count
                self?.showExistingFilesPrompt = true
            }
        }
    }

    func processExistingFiles() {
        iCloudService.processExistingFiles()
        showExistingFilesPrompt = false
    }

    func skipExistingFiles() {
        showExistingFilesPrompt = false
    }

    func clearPendingQueue() {
        monitorService.clearPendingQueue()
    }

    func clearCompletedTasks() {
        transcriptionVM.clearCompletedTasks()
    }

    func ignorePendingFile(_ fileURL: URL) {
        // Add to ignored files list
        var ignoredFiles = settings.ignoredFiles
        ignoredFiles.insert(fileURL.path)
        settings.ignoredFiles = ignoredFiles

        // Mark as processed so it won't be picked up again
        monitorService.markAsProcessed(fileURL)

        // Remove from pending queue
        monitorService.removePendingFile(fileURL)

        // Remove from transcription processing (queue and active tasks)
        transcriptionVM.removeFileFromProcessing(fileURL)

        print("🚫 Ignoring pending file: \(fileURL.lastPathComponent)")
    }

    private func loadSavedFolder() {
        print("📂 loadSavedFolder called")
        print("   hasBookmark: \(BookmarkManager.shared.hasBookmark)")
        print("   isMonitoringEnabled: \(settings.isMonitoringEnabled)")

        // Try to restore from bookmark first (more reliable with sandboxing)
        if BookmarkManager.shared.hasBookmark {
            if settings.isMonitoringEnabled {
                print("   🔄 Attempting to restore monitoring from bookmark...")
                // Restore monitoring using the saved bookmark
                let restored = monitorService.restoreMonitoringFromBookmark()
                if restored {
                    print("   ✅ Restored monitoring from bookmark")
                    // Update selectedFolderURL to match what's being monitored
                    if let folderURL = monitorService.monitoredFolder {
                        selectedFolderURL = folderURL
                        print("   📁 Set selectedFolderURL to: \(folderURL.path)")
                    }
                } else {
                    print("   ⚠️ Failed to restore monitoring from bookmark")
                }
            } else if let path = BookmarkManager.shared.getSavedBookmarkPath() {
                // Just set the selected folder (don't start monitoring)
                selectedFolderURL = URL(fileURLWithPath: path)
                print("   📁 Set selectedFolderURL (monitoring disabled): \(path)")
            }
        } else {
            print("   ℹ️ No saved folder found")
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("Vælg Folder", comment: "")
        panel.message = NSLocalizedString("Vælg en folder til overvågning af lydfiler", comment: "")

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    self.selectedFolderURL = url

                    // Start monitoring automatically
                    self.startMonitoring()
                }
            }
        }
    }

    func startMonitoring() {
        guard let folderURL = selectedFolderURL else {
            errorMessage = NSLocalizedString("Ingen folder valgt. Vælg venligst en folder først.", comment: "")
            showError = true
            print("No folder selected")
            return
        }

        // FolderMonitorService now handles security-scoped access and bookmark saving
        monitorService.startMonitoring(folder: folderURL)

        // Verify that monitoring actually started
        if !monitorService.isMonitoring {
            errorMessage = NSLocalizedString("Kunne ikke starte overvågning. Tjek at appen har adgang til folderen.", comment: "")
            showError = true
            settings.isMonitoringEnabled = false
        } else {
            settings.isMonitoringEnabled = true
        }
    }

    func stopMonitoring() {
        // FolderMonitorService now handles security-scoped access cleanup
        monitorService.stopMonitoring()
        settings.isMonitoringEnabled = false
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    var statusText: String {
        if isMonitoring {
            if pendingFiles.isEmpty {
                return NSLocalizedString("Overvåger...", comment: "")
            } else {
                return String(format: NSLocalizedString("Behandler %lld fil(er)...", comment: ""), pendingFiles.count)
            }
        } else {
            return NSLocalizedString("Ikke aktiv", comment: "")
        }
    }

    var statusColor: Color {
        isMonitoring ? .green : .gray
    }

    /// Refresh iCloud file lists by scanning metadata
    func refreshiCloudFileLists() async {
        let msg = "🔄 refreshiCloudFileLists called at \(Date())"
        print(msg)
        try? msg.appending("\n").write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)

        guard settings.iCloudSyncEnabled,
              let recordingsFolder = iCloudService.getRecordingsFolderURL() else {
            let failMsg = "   ❌ iCloud disabled or no folder"
            print(failMsg)
            if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                log.append(failMsg + "\n")
                try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
            }
            return
        }

        var queued: [(URL, RecordingMetadata)] = []
        var completed: [(URL, RecordingMetadata)] = []
        var failed: [(URL, RecordingMetadata)] = []

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
                let audioFileName = jsonFile.deletingPathExtension().lastPathComponent + ".m4a"
                guard let metadata = try? RecordingMetadata.load(
                    for: audioFileName,
                    from: recordingsFolder
                ) else {
                    print("⚠️ Could not load metadata for: \(audioFileName)")
                    continue
                }

                let audioURL = recordingsFolder.appendingPathComponent(metadata.audioFileName)

                // Debug failed files
                if metadata.status == .failed {
                    print("   🔍 Processing failed file: \(metadata.audioFileName), error: \(metadata.errorMessage ?? "none")")
                }

                // Only include if audio file exists
                guard FileManager.default.fileExists(atPath: audioURL.path) else {
                    continue
                }

                switch metadata.status {
                case .uploading:
                    // Still being uploaded from iPhone, skip for now
                    continue
                case .pending, .downloading:
                    // Check if currently being transcribed
                    let isActive = transcriptionVM.activeTasks.contains { $0.audioFileURL.lastPathComponent == metadata.audioFileName }

                    if !isActive {
                        // If file has an error message, it should be marked as failed, not pending
                        if metadata.errorMessage != nil {
                            print("⚠️ File \(metadata.audioFileName) has pending status but has error - should be failed")
                            // Don't add to queue, skip it
                            continue
                        }

                        queued.append((audioURL, metadata))
                    }
                case .queued:
                    // Already in queue on Mac
                    let isActive = transcriptionVM.activeTasks.contains { $0.audioFileURL.lastPathComponent == metadata.audioFileName }
                    if !isActive {
                        queued.append((audioURL, metadata))
                    }
                case .completed:
                    completed.append((audioURL, metadata))
                case .failed:
                    print("   📍 Found failed file: \(metadata.audioFileName)")
                    failed.append((audioURL, metadata))
                case .transcribing:
                    // Check if it's actually failed (has error message but status is stuck as transcribing)
                    let isActive = transcriptionVM.activeTasks.contains { $0.audioFileURL.lastPathComponent == metadata.audioFileName }

                    if !isActive {
                        // Not currently being transcribed
                        if metadata.errorMessage != nil {
                            // Has error - should be treated as failed
                            print("   📍 Found stuck transcribing file with error (treating as failed): \(metadata.audioFileName)")
                            failed.append((audioURL, metadata))
                        } else {
                            // Stuck in transcribing state without error - needs to be retried
                            print("   🔄 Found stuck transcribing file without error - adding to queue: \(metadata.audioFileName)")
                            queued.append((audioURL, metadata))
                        }
                    }
                    // If active, skip - shown in activeTasks
                }
            }

            // Sort by creation date (newest first)
            queued.sort { $0.1.createdAt > $1.1.createdAt }
            completed.sort { $0.1.updatedAt > $1.1.updatedAt }
            failed.sort { $0.1.updatedAt > $1.1.updatedAt }

            await MainActor.run {
                print("📊 Refresh summary: \(queued.count) queued, \(completed.count) completed, \(failed.count) failed")
                self.iCloudQueuedFiles = queued
                self.iCloudCompletedFiles = completed
                self.iCloudFailedFiles = failed
            }

            // Auto-start queued files (if not already in transcription queue/active)
            if !queued.isEmpty {
                print("🔍 Checking \(queued.count) queued file(s) for auto-start")
                for (url, _) in queued {
                    let isInQueue = transcriptionVM.isInQueue(url)
                    let isActive = transcriptionVM.activeTasks.contains { $0.audioFileURL.lastPathComponent == url.lastPathComponent }

                    print("   File: \(url.lastPathComponent) - inQueue: \(isInQueue), isActive: \(isActive)")

                    if !isInQueue && !isActive {
                        let msg = "   🚀 Auto-starting queued file: \(url.lastPathComponent) at \(Date())"
                        print(msg)
                        try? msg.appending("\n").write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)

                        // Remove from processed files list so it can be retried
                        FolderMonitorService.shared.removeFromProcessed(url)
                        let removeMsg = "   🗑️ Removed from processed files list: \(url.lastPathComponent)"
                        print(removeMsg)
                        if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                            log.append(removeMsg + "\n")
                            try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
                        }

                        await transcriptionVM.addToQueue(url)
                        let afterMsg = "   ✅ addToQueue completed for: \(url.lastPathComponent)"
                        print(afterMsg)
                        if var log = try? String(contentsOfFile: "/tmp/skrivdetned_debug.log", encoding: .utf8) {
                            log.append(afterMsg + "\n")
                            try? log.write(toFile: "/tmp/skrivdetned_debug.log", atomically: true, encoding: .utf8)
                        }
                    } else {
                        print("   ⏭️ Skipping (already in queue or active)")
                    }
                }
            }
        } catch {
            print("❌ Failed to refresh iCloud file lists: \(error)")
        }
    }
}
