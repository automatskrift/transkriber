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

    private let monitorService = FolderMonitorService.shared
    private let transcriptionVM = TranscriptionViewModel.shared
    private let iCloudService = iCloudSyncService.shared
    private let settings = AppSettings.shared

    private init() {
        setupObservers()
        loadSavedFolder()
        setupiCloudMonitoring()
    }

    private func setupiCloudMonitoring() {
        // Start iCloud monitoring if enabled
        print("🔧 setupiCloudMonitoring called, iCloudSyncEnabled: \(settings.iCloudSyncEnabled)")

        if settings.iCloudSyncEnabled {
            Task {
                // Check availability first
                print("🔍 Checking iCloud availability...")
                await iCloudService.checkiCloudAvailability()

                // Wait a moment for iCloud to be ready
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Start monitoring
                await MainActor.run {
                    print("🚀 Starting iCloud monitoring...")
                    iCloudService.startMonitoring { [weak self] url in
                        Task { @MainActor in
                            await self?.handleiCloudFile(url)
                        }
                    }
                }

                // Check for pending files that need retry
                let pendingFiles = await iCloudService.checkForPendingFiles()
                if !pendingFiles.isEmpty {
                    await MainActor.run {
                        print("🔄 Processing \(pendingFiles.count) pending file(s) for retry")
                    }
                    for url in pendingFiles {
                        await handleiCloudFile(url)
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
            self?.existingFilesCount = count
            self?.showExistingFilesPrompt = true
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

        // Remove from pending queue
        monitorService.removePendingFile(fileURL)

        // Remove from transcription processing (queue and active tasks)
        transcriptionVM.removeFileFromProcessing(fileURL)

        print("🚫 Ignoring pending file: \(fileURL.lastPathComponent)")
    }

    private func loadSavedFolder() {
        if let folderURL = settings.monitoredFolderURL {
            selectedFolderURL = folderURL

            if settings.isMonitoringEnabled {
                startMonitoring()
            }
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Vælg Folder"
        panel.message = "Vælg en folder til overvågning af lydfiler"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    self.selectedFolderURL = url
                    self.settings.monitoredFolderURL = url

                    // Start monitoring automatically
                    self.startMonitoring()
                }
            }
        }
    }

    func startMonitoring() {
        guard let folderURL = selectedFolderURL else {
            print("No folder selected")
            return
        }

        // Request security scoped access
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource")
            return
        }

        monitorService.startMonitoring(folder: folderURL)
        settings.isMonitoringEnabled = true
    }

    func stopMonitoring() {
        monitorService.stopMonitoring()
        settings.isMonitoringEnabled = false

        // Stop accessing security scoped resource
        if let folderURL = selectedFolderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
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
                return "Overvåger..."
            } else {
                return "Behandler \(pendingFiles.count) fil(er)..."
            }
        } else {
            return "Ikke aktiv"
        }
    }

    var statusColor: Color {
        isMonitoring ? .green : .gray
    }
}
