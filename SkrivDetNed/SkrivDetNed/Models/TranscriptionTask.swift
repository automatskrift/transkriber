//
//  TranscriptionTask.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

enum TranscriptionStatus: Equatable {
    case pending
    case processing(progress: Double)
    case completed
    case failed(error: String)

    var isActive: Bool {
        switch self {
        case .processing: return true
        default: return false
        }
    }
}

struct TranscriptionTask: Identifiable {
    let id = UUID()
    let audioFileURL: URL
    let outputFileURL: URL
    var status: TranscriptionStatus
    var createdAt: Date
    var completedAt: Date?

    init(audioFileURL: URL, outputFileURL: URL? = nil, createdAt: Date? = nil) {
        self.audioFileURL = audioFileURL
        self.outputFileURL = outputFileURL ?? audioFileURL.deletingPathExtension().appendingPathExtension("txt")
        self.status = .pending
        self.createdAt = createdAt ?? Date()
    }

    var fileName: String {
        audioFileURL.lastPathComponent
    }

    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(createdAt)
    }

    var statusDescription: String {
        switch status {
        case .pending:
            return "Venter..."
        case .processing(let progress):
            return "Transkriberer... \(Int(progress * 100))%"
        case .completed:
            return "Færdig"
        case .failed(let error):
            return "Fejl: \(error)"
        }
    }
}
