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

    // Device info
    var createdOnDevice: String? // "iOS" or "macOS"
    var transcribedOnDevice: String?

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
        try data.write(to: metadataURL)
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

        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(RecordingMetadata.self, from: data)
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
