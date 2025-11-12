//
//  DownloadDetector.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import Combine
import os

/// Detects when WhisperKit is actually downloading models
@MainActor
class DownloadDetector: ObservableObject {
    static let shared = DownloadDetector()

    @Published var isActuallyDownloading = false
    @Published var detectedProgress: Double = 0.0

    private var timer: Timer?
    private var lastLogCheckTime = Date()
    private let logger = os.Logger(subsystem: "com.omdethele.SkrivDetNed", category: "DownloadDetector")

    private init() {}

    /// Start monitoring for downloads
    func startMonitoring() {
        // Monitor the huggingface directory for new files being created
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.checkForDownload()
            }
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isActuallyDownloading = false
    }

    /// Check if a download is happening by looking for temporary download files
    private func checkForDownload() {
        // Check for temporary download files in the huggingface cache
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let huggingfaceURL = libraryURL.appendingPathComponent("huggingface")

        // Look for .download or .part files which indicate ongoing downloads
        if let enumerator = FileManager.default.enumerator(at: huggingfaceURL,
                                                          includingPropertiesForKeys: [.nameKey, .creationDateKey],
                                                          options: [.skipsHiddenFiles], errorHandler: nil) {
            var foundDownloadFile = false

            for case let fileURL as URL in enumerator {
                let filename = fileURL.lastPathComponent

                // Check for download indicators
                if filename.contains(".download") ||
                   filename.contains(".part") ||
                   filename.contains(".tmp") ||
                   filename.hasSuffix(".downloading") {

                    // Check if file was created recently (within last 10 seconds)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       abs(creationDate.timeIntervalSinceNow) < 10 {

                        foundDownloadFile = true

                        // Try to estimate progress from file size
                        if let fileSize = attributes[.size] as? Int64 {
                            // Rough estimate based on expected model sizes
                            let estimatedTotalSize: Int64 = 1_500_000_000 // ~1.5GB for large model
                            let progress = min(Double(fileSize) / Double(estimatedTotalSize), 0.99)

                            if progress != detectedProgress {
                                logger.info("Download progress detected: \(progress)")
                                detectedProgress = progress
                            }
                        }
                        break
                    }
                }
            }

            if foundDownloadFile != isActuallyDownloading {
                isActuallyDownloading = foundDownloadFile
                if foundDownloadFile {
                    logger.info("WhisperKit download detected!")
                } else {
                    logger.info("WhisperKit download completed or stopped")
                    detectedProgress = 0.0
                }
            }
        }
    }

    /// Alternative method: Check system log for NSProgress entries
    func checkSystemLog() {
        // This would require entitlements to read system log
        // For now, we'll rely on file system monitoring
    }
}