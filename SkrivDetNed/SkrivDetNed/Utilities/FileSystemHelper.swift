//
//  FileSystemHelper.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

@MainActor
class FileSystemHelper {
    nonisolated static let shared = FileSystemHelper()

    nonisolated private init() {}

    // Supported audio file extensions
    nonisolated static let supportedAudioExtensions = ["m4a", "mp3", "wav", "aiff", "caf", "aac", "flac"]

    nonisolated func isAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.supportedAudioExtensions.contains(ext)
    }

    func isStableFile(at url: URL, waitTime: TimeInterval = 2.0) async -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard let initialSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return false
        }

        // Wait for specified time
        try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))

        guard let finalSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return false
        }

        return initialSize == finalSize
    }

    nonisolated func transcriptionFileExists(for audioURL: URL) -> Bool {
        let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
        return FileManager.default.fileExists(atPath: txtURL.path)
    }

    nonisolated func createApplicationSupportDirectory() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appDirectory = appSupportURL.appendingPathComponent("SkrivDetNed")

        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }

        return appDirectory
    }

    nonisolated func createModelsDirectory() throws -> URL {
        let appDirectory = try createApplicationSupportDirectory()
        let modelsDirectory = appDirectory.appendingPathComponent("Models")

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        }

        return modelsDirectory
    }

    nonisolated func modelExists(_ modelType: WhisperModelType) -> Bool {
        guard let modelsDir = try? createModelsDirectory() else { return false }
        let modelPath = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    nonisolated func deleteModel(_ modelType: WhisperModelType) throws {
        let modelsDir = try createModelsDirectory()
        let modelPath = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
    }

    func getModelSize(_ modelType: WhisperModelType) -> Int64? {
        guard let modelsDir = try? createModelsDirectory() else { return nil }
        let modelPath = modelsDir.appendingPathComponent("ggml-\(modelType.rawValue).bin")

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }

        return fileSize
    }

    func getTotalModelsSize() -> Int64 {
        var totalSize: Int64 = 0

        for modelType in WhisperModelType.allCases {
            if let size = getModelSize(modelType) {
                totalSize += size
            }
        }

        return totalSize
    }
}
