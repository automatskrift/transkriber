//
//  ModelDownloadService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import Combine

@MainActor
class ModelDownloadService: NSObject, ObservableObject {
    static let shared = ModelDownloadService()

    @Published var downloadProgress: [WhisperModelType: Double] = [:]
    @Published var isDownloading: [WhisperModelType: Bool] = [:]

    private var downloadTasks: [WhisperModelType: URLSessionDownloadTask] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600 // 1 hour for large files
        config.httpMaximumConnectionsPerHost = 1
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    func downloadModel(_ modelType: WhisperModelType) async throws {
        print("🚀 ModelDownloadService: Starting download for \(modelType.rawValue)")

        guard !isDownloading[modelType, default: false] else {
            print("⚠️ ModelDownloadService: Already downloading \(modelType.rawValue)")
            throw DownloadError.alreadyDownloading
        }

        // Check if already downloaded
        if FileSystemHelper.shared.modelExists(modelType) {
            print("⚠️ ModelDownloadService: \(modelType.rawValue) already exists")
            throw DownloadError.alreadyDownloaded
        }

        await MainActor.run {
            isDownloading[modelType] = true
            downloadProgress[modelType] = 0.0
        }

        let modelsDir = try FileSystemHelper.shared.createModelsDirectory()
        _ = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")

        print("📁 Models directory: \(modelsDir.path)")
        print("🌐 Download URL: \(modelType.downloadURL)")

        do {
            let downloadTask = urlSession.downloadTask(with: modelType.downloadURL)
            downloadTasks[modelType] = downloadTask
            downloadModelTypes[downloadTask] = modelType  // Store mapping
            print("▶️ Starting download task for \(modelType.rawValue)")
            downloadTask.resume()

            // Wait for download to complete
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Store continuation for later use
                downloadContinuations[modelType] = continuation
            }

            print("✅ ModelDownloadService: Download completed successfully for \(modelType.rawValue)")

        } catch {
            print("❌ ModelDownloadService: Download failed for \(modelType.rawValue): \(error)")
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
    nonisolated(unsafe) private var downloadModelTypes: [URLSessionDownloadTask: WhisperModelType] = [:]
}

extension ModelDownloadService: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    // Handle HTTP redirects
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("🔄 Redirect from: \(response.url?.absoluteString ?? "unknown")")
        print("🔄 Redirect to: \(request.url?.absoluteString ?? "unknown")")
        print("🔄 Status code: \(response.statusCode)")

        // Allow the redirect
        completionHandler(request)
    }

    // Note: Removed urlSession(_:task:didReceive:completionHandler:) as it's optional
    // and was causing protocol matching warnings. Response logging happens in other delegates.

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelType = downloadModelTypes[downloadTask] else {
            print("❌ ModelDownloadService: No model type found for download task")
            return
        }

        print("✅ ModelDownloadService: Download finished for \(modelType.rawValue)")
        print("📁 Temporary location: \(location.path)")

        // Move file immediately before the temp file is deleted
        // This must happen synchronously in the delegate callback
        let moveResult: Result<URL, Error>
        do {
            let modelsDir = try FileSystemHelper.shared.createModelsDirectory()
            let destinationURL = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")

            print("📁 Destination: \(destinationURL.path)")
            print("📦 Temp file exists: \(FileManager.default.fileExists(atPath: location.path))")

            // Remove existing file if any
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("🗑️ Removed existing file at destination")
            }

            // Move downloaded file to destination
            try FileManager.default.moveItem(at: location, to: destinationURL)
            print("✅ Successfully moved file to: \(destinationURL.path)")

            // Verify file exists after move
            let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)
            print("📦 File exists after move: \(fileExists)")

            if fileExists {
                let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                print("📊 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")

                // Validate file size - should be at least 1 MB for any valid model
                if fileSize < 1_000_000 {
                    // Log file content for debugging
                    if let content = try? String(contentsOf: destinationURL, encoding: .utf8) {
                        print("📄 File content: \(content)")
                    }
                    throw DownloadError.invalidFileSize(fileSize)
                }
            }

            moveResult = .success(destinationURL)
        } catch {
            print("❌ ModelDownloadService: Failed to move file: \(error)")
            moveResult = .failure(error)
        }

        Task { @MainActor in
            switch moveResult {
            case .success:
                // Show 100% progress briefly before cleaning up
                downloadProgress[modelType] = 1.0

                // Wait a moment so user can see the completion
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Clean up
                isDownloading[modelType] = false
                downloadProgress[modelType] = nil
                downloadTasks[modelType] = nil
                downloadModelTypes[downloadTask] = nil

                // Resume continuation
                if let continuation = downloadContinuations[modelType] {
                    continuation.resume()
                    downloadContinuations[modelType] = nil
                }

            case .failure(let error):
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
        guard let modelType = downloadModelTypes[downloadTask] else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            downloadProgress[modelType] = progress
        }

        // Log progress every 10% (using static variable to avoid spam)
        let progressPercent = Int(progress * 100)
        if progressPercent % 10 == 0 && progressPercent > 0 {
            let downloaded = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
            print("📥 Download progress for \(modelType.rawValue): \(progressPercent)% (\(downloaded) / \(total))")
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
    case invalidFileSize(Int64)

    var errorDescription: String? {
        switch self {
        case .alreadyDownloading:
            return NSLocalizedString("Model bliver allerede downloadet", comment: "")
        case .alreadyDownloaded:
            return NSLocalizedString("Model er allerede downloadet", comment: "")
        case .cancelled:
            return NSLocalizedString("Download annulleret", comment: "")
        case .networkError(let error):
            return String(format: NSLocalizedString("Netværksfejl: %@", comment: ""), error.localizedDescription)
        case .invalidFileSize(let size):
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            return String(format: NSLocalizedString("Ugyldig filstørrelse: %@. Filen ser ud til at være en fejlside i stedet for modellen. Prøv igen senere.", comment: ""), sizeStr)
        }
    }
}
