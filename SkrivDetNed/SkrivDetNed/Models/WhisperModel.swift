//
//  WhisperModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

enum WhisperModelType: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large-v3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return NSLocalizedString("Tiny", comment: "")
        case .base: return NSLocalizedString("Base", comment: "")
        case .small: return NSLocalizedString("Small", comment: "")
        case .medium: return NSLocalizedString("Medium", comment: "")
        case .large: return NSLocalizedString("Large", comment: "")
        }
    }

    var fileSize: Int64 {
        switch self {
        case .tiny: return 78_000_000      // ~78 MB
        case .base: return 148_000_000     // ~148 MB
        case .small: return 488_000_000    // ~488 MB
        case .medium: return 1_530_000_000 // ~1.53 GB
        case .large: return 3_100_000_000  // ~3.1 GB (v3)
        }
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var description: String {
        switch self {
        case .tiny:
            return NSLocalizedString("Hurtigste model, god til korte optagelser", comment: "")
        case .base:
            return NSLocalizedString("God balance mellem hastighed og nøjagtighed", comment: "")
        case .small:
            return NSLocalizedString("Bedre nøjagtighed, stadig rimelig hurtig", comment: "")
        case .medium:
            return NSLocalizedString("Høj nøjagtighed for længere optagelser", comment: "")
        case .large:
            return NSLocalizedString("Bedste nøjagtighed (v3) - anbefales til andre sprog end engelsk", comment: "")
        }
    }

    var downloadURL: URL {
        // whisper.cpp model URLs from Hugging Face
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        return URL(string: "\(baseURL)/ggml-\(rawValue).bin?download=true")!
    }

    var modelPath: String {
        // Path to downloaded model for WhisperKit
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SkrivDetNed")
            .appendingPathComponent("Models")
            .appendingPathComponent("ggml-\(rawValue).bin")
            .path ?? ""
    }
}

struct WhisperModel: Identifiable {
    let id = UUID()
    let type: WhisperModelType
    var isDownloaded: Bool
    var downloadProgress: Double?

    var localURL: URL? {
        guard isDownloaded else { return nil }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SkrivDetNed")
            .appendingPathComponent("Models")
            .appendingPathComponent("ggml-\(type.rawValue).bin")
    }
}
