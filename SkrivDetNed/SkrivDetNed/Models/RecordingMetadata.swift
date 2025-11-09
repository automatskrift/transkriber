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
                        var currentData: Data?
                        var readError: NSError?

                        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { readURL in
                            currentData = try? Data(contentsOf: readURL)
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
            var coordinatorError: NSError?
            var readData: Data?
            var readError: Error?

            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(readingItemAt: metadataURL, options: [], error: &coordinatorError) { url in
                do {
                    readData = try Data(contentsOf: url)
                } catch {
                    readError = error
                }
            }

            if let error = coordinatorError {
                throw error
            }
            if let error = readError {
                throw error
            }

            guard let loadedData = readData else {
                return nil
            }
            data = loadedData
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
    case pending = "pending"           // Waiting to be transcribed
    case downloading = "downloading"   // Downloading from iCloud
    case transcribing = "transcribing" // Currently being transcribed
    case completed = "completed"       // Transcription completed
    case failed = "failed"             // Transcription failed

    var displayName: String {
        switch self {
        case .pending: return "Afventer"
        case .downloading: return "Downloader..."
        case .transcribing: return "Transkriberer..."
        case .completed: return "Færdig"
        case .failed: return "Fejlet"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .downloading: return "icloud.and.arrow.down"
        case .transcribing: return "waveform"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}
