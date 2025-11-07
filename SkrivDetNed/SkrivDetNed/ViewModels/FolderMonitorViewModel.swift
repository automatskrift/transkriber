//
//  FolderMonitorViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI

@MainActor
class FolderMonitorViewModel: ObservableObject {
    @Published var isMonitoring = false
    @Published var selectedFolderURL: URL?
    @Published var pendingFiles: [URL] = []
    @Published var recentlyCompleted: [TranscriptionTask] = []

    private let monitorService = FolderMonitorService.shared
    private let transcriptionVM = TranscriptionViewModel.shared
    private let settings = AppSettings.shared

    init() {
        setupObservers()
        loadSavedFolder()
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
