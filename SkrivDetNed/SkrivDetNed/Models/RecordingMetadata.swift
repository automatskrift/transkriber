//
//  RecordingMetadata.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

/// Metadata for a recording that syncs between iOS and macOS apps
struct RecordingMetadata: Codable {
    let id: UUID
    let audioFileName: String
    let createdAt: Date
    var status: RecordingStatus
    var transcriptionFileName: String?
    var updatedAt: Date

    // Optional metadata
    var title: String?
    var tags: [String]
    var notes: String?
    var language: String?
    var duration: TimeInterval?
    var promptPrefix: String?

    // Device info
    var createdOnDevice: String? // "iOS" or "macOS"
    var transcribedOnDevice: String?

    // Error info
    var errorMessage: String?
    var lastAttemptedAt: Date?

    // Marks (timestamps in seconds when user pressed "Mark" during recording)
    var marks: [Double]?

    init(audioFileName: String, createdOnDevice: String = "Unknown") {
        self.id = UUID()
        self.audioFileName = audioFileName
        self.createdAt = Date()
        self.status = .pending
        self.updatedAt = Date()
        self.tags = []
        self.createdOnDevice = createdOnDevice
    }

    /// Save metadata to JSON file
    func save(to directory: URL) throws {
        let metadataFileName = audioFileName.replacingOccurrences(of: ".m4a", with: ".json")
            .replacingOccurrences(of: ".mp3", with: ".json")
            .replacingOccurrences(of: ".wav", with: ".json")

        let metadataURL = directory.appendingPathComponent(metadataFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(self)

        // Use NSFileCoordinator for iCloud files to prevent sync conflicts
        if directory.path.contains("Mobile Documents") {
            var coordinatorError: NSError?
            var writeError: Error?

            let coordinator = NSFileCoordinator(filePresenter: nil)

            // Use .forMerging option to prevent conflicts when both apps write simultaneously
            coordinator.coordinate(writingItemAt: metadataURL, options: [.forReplacing, .forMerging], error: &coordinatorError) { url in
                do {
                    // Check if file exists and read current version first
                    if FileManager.default.fileExists(atPath: url.path) {
                        // Read existing metadata to merge with current changes
                        var readError: NSError?

                        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { readURL in
                            _ = try? Data(contentsOf: readURL)
                        }

                        // iOS only writes once (after upload), macOS writes status updates
                        // No need for timestamp comparison - NSFileCoordinator handles conflicts
                        // If a conflict occurs, iCloud creates " 2.json" which we cleanup automatically
                        try data.write(to: url, options: [])
                    } else {
                        // File doesn't exist yet, safe to write
                        try data.write(to: url, options: [])
                    }
                } catch {
                    writeError = error
                }
            }

            if let error = coordinatorError {
                throw error
            }
            if let error = writeError {
                throw error
            }
        } else {
            // For local files, write directly with atomic option
            try data.write(to: metadataURL, options: .atomic)
        }
    }

    /// Load metadata from JSON file
    static func load(for audioFileName: String, from directory: URL) throws -> RecordingMetadata? {
        let metadataFileName = audioFileName.replacingOccurrences(of: ".m4a", with: ".json")
            .replacingOccurrences(of: ".mp3", with: ".json")
            .replacingOccurrences(of: ".wav", with: ".json")

        let metadataURL = directory.appendingPathComponent(metadataFileName)

        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        // Use NSFileCoordinator for iCloud files to ensure consistent reads
        let data: Data
        if directory.path.contains("Mobile Documents") {
            // Try NSFileCoordinator first, but with a timeout
            var coordinatorError: NSError?
            var readData: Data?
            var readError: Error?

            let coordinator = NSFileCoordinator(filePresenter: nil)
            let semaphore = DispatchSemaphore(value: 0)

            // Start coordinated read in background
            DispatchQueue.global(qos: .userInitiated).async {
                coordinator.coordinate(readingItemAt: metadataURL,
                                      options: [],  // No special options, let it work normally
                                      error: &coordinatorError) { url in
                    do {
                        readData = try Data(contentsOf: url)
                    } catch {
                        readError = error
                    }
                }
                semaphore.signal()
            }

            // Wait for max 1 second
            let timeout = DispatchTime.now() + .seconds(1)
            let result = semaphore.wait(timeout: timeout)

            if result == .timedOut {
                print("⚠️ NSFileCoordinator timed out, using direct read")
                // Timeout - fall back to direct read
                data = try Data(contentsOf: metadataURL)
            } else if let error = coordinatorError {
                print("⚠️ NSFileCoordinator error: \(error), falling back to direct read")
                // Permission error - fall back to direct read
                data = try Data(contentsOf: metadataURL)
            } else if let error = readError {
                print("⚠️ Read error: \(error)")
                throw error
            } else if let loadedData = readData {
                data = loadedData
            } else {
                // Fall back to direct read if no data
                data = try Data(contentsOf: metadataURL)
            }
        } else {
            data = try Data(contentsOf: metadataURL)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata = try decoder.decode(RecordingMetadata.self, from: data)

        // Debug: log if loading failed file
        if metadata.status == .failed {
            print("   📖 Loaded failed metadata: \(audioFileName), error: \(metadata.errorMessage ?? "none")")
        }

        return metadata
    }
}

enum RecordingStatus: String, Codable {
    case uploading = "uploading"       // Being uploaded to iCloud (from iPhone)
    case pending = "pending"           // In iCloud, waiting to be queued
    case queued = "queued"             // Added to transcription queue on Mac
    case downloading = "downloading"   // Downloading from iCloud
    case transcribing = "transcribing" // Currently being transcribed
    case completed = "completed"       // Transcription completed
    case failed = "failed"             // Transcription failed

    var displayName: String {
        switch self {
        case .uploading: return NSLocalizedString("Uploading", comment: "Status: Uploading")
        case .pending: return NSLocalizedString("Pending", comment: "Status: Pending")
        case .queued: return NSLocalizedString("In Queue", comment: "Status: In Queue")
        case .downloading: return NSLocalizedString("Downloading...", comment: "Status: Downloading")
        case .transcribing: return NSLocalizedString("Transcribing...", comment: "Status: Transcribing")
        case .completed: return NSLocalizedString("Completed", comment: "Status: Completed")
        case .failed: return NSLocalizedString("Failed", comment: "Status: Failed")
        }
    }

    var icon: String {
        switch self {
        case .uploading: return "icloud.and.arrow.up"
        case .pending: return "clock"
        case .queued: return "text.badge.plus"
        case .downloading: return "icloud.and.arrow.down"
        case .transcribing: return "waveform"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}
