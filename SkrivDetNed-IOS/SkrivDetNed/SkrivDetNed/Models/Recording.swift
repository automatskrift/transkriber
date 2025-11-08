//
//  Recording.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let fileName: String
    private let _localURLPath: String? // Not used - kept for backwards compatibility
    private var _transcriptionFileName: String?
    var title: String
    var tags: [String]
    var notes: String?
    let duration: TimeInterval
    let fileSize: Int64
    let createdAt: Date
    var cloudStatus: CloudStatus
    var hasTranscription: Bool
    var transcriptionText: String?
    var errorMessage: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?

    // Computed property that reconstructs the full URL
    var localURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }

    // Computed property for transcription URL
    var transcriptionURL: URL? {
        guard let transcriptionFileName = _transcriptionFileName else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(transcriptionFileName)
    }

    // Helper to set transcription filename
    mutating func setTranscriptionFileName(_ fileName: String?) {
        _transcriptionFileName = fileName
    }

    init(
        fileName: String,
        localURL: URL,
        duration: TimeInterval,
        fileSize: Int64
    ) {
        self.id = UUID()
        self.fileName = fileName
        self._localURLPath = nil // Not used anymore, we compute it
        self._transcriptionFileName = nil
        self.title = fileName.replacingOccurrences(of: ".m4a", with: "")
        self.tags = []
        self.notes = nil
        self.duration = duration
        self.fileSize = fileSize
        self.createdAt = Date()
        self.cloudStatus = .local
        self.hasTranscription = false
        self.transcriptionText = nil
        self.errorMessage = nil
        self.locationName = nil
        self.latitude = nil
        self.longitude = nil
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "da_DK")
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    enum CloudStatus: String, Codable {
        case local          // Not uploaded yet
        case uploading      // Currently uploading
        case synced         // In iCloud
        case pending        // Waiting for transcription
        case transcribing   // Being transcribed
        case completed      // Transcription available
        case failed         // Error occurred

        var displayName: String {
            switch self {
            case .local: return "Lokal"
            case .uploading: return "Uploader..."
            case .synced: return "Synkroniseret"
            case .pending: return "Afventer"
            case .transcribing: return "Transkriberes..."
            case .completed: return "Færdig"
            case .failed: return "Fejlet"
            }
        }

        var icon: String {
            switch self {
            case .local: return "iphone"
            case .uploading: return "icloud.and.arrow.up"
            case .synced: return "icloud"
            case .pending: return "clock"
            case .transcribing: return "waveform"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .local: return "gray"
            case .uploading: return "blue"
            case .synced: return "blue"
            case .pending: return "orange"
            case .transcribing: return "purple"
            case .completed: return "green"
            case .failed: return "red"
            }
        }
    }
}
