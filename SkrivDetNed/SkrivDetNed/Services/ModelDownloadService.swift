//
//  ModelDownloadService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

@MainActor
class ModelDownloadService: NSObject, ObservableObject {
    static let shared = ModelDownloadService()

    @Published var downloadProgress: [WhisperModelType: Double] = [:]
    @Published var isDownloading: [WhisperModelType: Bool] = [:]

    private var downloadTasks: [WhisperModelType: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    func downloadModel(_ modelType: WhisperModelType) async throws {
        guard !isDownloading[modelType, default: false] else {
            throw DownloadError.alreadyDownloading
        }

        // Check if already downloaded
        if FileSystemHelper.shared.modelExists(modelType) {
            throw DownloadError.alreadyDownloaded
        }

        await MainActor.run {
            isDownloading[modelType] = true
            downloadProgress[modelType] = 0.0
        }

        let modelsDir = try FileSystemHelper.shared.createModelsDirectory()
        let destinationURL = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")

        do {
            let downloadTask = urlSession.downloadTask(with: modelType.downloadURL)
            downloadTasks[modelType] = downloadTask
            downloadModelTypes[downloadTask] = modelType  // Store mapping
            downloadTask.resume()

            // Wait for download to complete
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Store continuation for later use
                downloadContinuations[modelType] = continuation
            }

        } catch {
            await MainActor.run {
                isDownloading[modelType] = false
                downloadProgress[modelType] = nil
            }
            throw error
        }
    }

    func cancelDownload(_ modelType: WhisperModelType) {
        downloadTasks[modelType]?.cancel()
        downloadTasks[modelType] = nil
        isDownloading[modelType] = false
        downloadProgress[modelType] = nil

        if let continuation = downloadContinuations[modelType] {
            continuation.resume(throwing: DownloadError.cancelled)
            downloadContinuations[modelType] = nil
        }
    }

    func deleteModel(_ modelType: WhisperModelType) throws {
        // Cancel download if in progress
        if isDownloading[modelType, default: false] {
            cancelDownload(modelType)
        }

        try FileSystemHelper.shared.deleteModel(modelType)
    }

    // Store continuations for completion
    private var downloadContinuations: [WhisperModelType: CheckedContinuation<Void, Error>] = [:]
    private var downloadModelTypes: [URLSessionDownloadTask: WhisperModelType] = [:]
}

extension ModelDownloadService: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            guard let modelType = downloadModelTypes[downloadTask] else { return }

            do {
                let modelsDir = try FileSystemHelper.shared.createModelsDirectory()
                let destinationURL = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")

                // Remove existing file if any
                try? FileManager.default.removeItem(at: destinationURL)

                // Move downloaded file to destination
                try FileManager.default.moveItem(at: location, to: destinationURL)

                // Clean up
                isDownloading[modelType] = false
                downloadProgress[modelType] = 1.0
                downloadTasks[modelType] = nil
                downloadModelTypes[downloadTask] = nil

                // Resume continuation
                if let continuation = downloadContinuations[modelType] {
                    continuation.resume()
                    downloadContinuations[modelType] = nil
                }

            } catch {
                isDownloading[modelType] = false
                downloadProgress[modelType] = nil
                downloadTasks[modelType] = nil
                downloadModelTypes[downloadTask] = nil

                if let continuation = downloadContinuations[modelType] {
                    continuation.resume(throwing: error)
                    downloadContinuations[modelType] = nil
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            guard let modelType = downloadModelTypes[downloadTask] else { return }

            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            downloadProgress[modelType] = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let modelType = downloadModelTypes[downloadTask] else { return }

        Task { @MainActor in
            if let error = error {
                isDownloading[modelType] = false
                downloadProgress[modelType] = nil
                downloadTasks[modelType] = nil
                downloadModelTypes[downloadTask] = nil

                if let continuation = downloadContinuations[modelType] {
                    continuation.resume(throwing: error)
                    downloadContinuations[modelType] = nil
                }
            }
        }
    }
}

enum DownloadError: LocalizedError {
    case alreadyDownloading
    case alreadyDownloaded
    case cancelled
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .alreadyDownloading:
            return "Model bliver allerede downloadet"
        case .alreadyDownloaded:
            return "Model er allerede downloadet"
        case .cancelled:
            return "Download annulleret"
        case .networkError(let error):
            return "Netværksfejl: \(error.localizedDescription)"
        }
    }
}
