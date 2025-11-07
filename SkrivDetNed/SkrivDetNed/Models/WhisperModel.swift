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
    case large = "large"

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var fileSize: Int64 {
        switch self {
        case .tiny: return 75_000_000      // ~75 MB
        case .base: return 142_000_000     // ~142 MB
        case .small: return 466_000_000    // ~466 MB
        case .medium: return 1_500_000_000 // ~1.5 GB
        case .large: return 2_900_000_000  // ~2.9 GB
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
            return "Bedste nøjagtighed, langsommere"
        }
    }

    var downloadURL: URL {
        // whisper.cpp model URLs
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        return URL(string: "\(baseURL)/ggml-\(rawValue).bin")!
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
