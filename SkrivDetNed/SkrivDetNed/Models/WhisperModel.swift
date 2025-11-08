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
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
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
            return "Hurtigste model, god til korte optagelser"
        case .base:
            return "God balance mellem hastighed og nøjagtighed"
        case .small:
            return "Bedre nøjagtighed, stadig rimelig hurtig"
        case .medium:
            return "Høj nøjagtighed for længere optagelser"
        case .large:
            return "Bedste nøjagtighed (v3), langsommere"
        }
    }

    var downloadURL: URL {
        // whisper.cpp model URLs from Hugging Face
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        return URL(string: "\(baseURL)/ggml-\(rawValue).bin?download=true")!
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
