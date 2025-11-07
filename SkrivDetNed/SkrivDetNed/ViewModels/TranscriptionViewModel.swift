//
//  TranscriptionViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import UserNotifications

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

            throw error
        }

        currentTask = nil
    }

    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        while !taskQueue.isEmpty {
            let url = taskQueue.removeFirst()

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
