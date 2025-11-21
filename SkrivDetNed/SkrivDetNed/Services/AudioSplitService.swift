//
//  AudioSplitService.swift
//  SkrivDetNed
//
//  Created by Claude on 21/11/2025.
//

import Foundation
import AVFoundation

/// Service for splitting audio files into parts
class AudioSplitService {
    static let shared = AudioSplitService()

    private init() {}

    /// Split an audio file into two equal parts at the midpoint
    /// - Parameters:
    ///   - url: The audio file URL to split
    ///   - outputFolder: The folder to save the split files
    /// - Returns: URLs of the two split audio files (part1, part2)
    func splitInHalf(_ url: URL, outputFolder: URL) async throws -> (URL, URL) {
        print("✂️ Splitting audio file in half: \(url.lastPathComponent)")

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 2.0 else {
            throw AudioSplitError.fileTooShort
        }

        let midpoint = durationSeconds / 2.0
        print("   📊 Duration: \(String(format: "%.1f", durationSeconds))s, midpoint: \(String(format: "%.1f", midpoint))s")

        // Generate output filenames
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let part1Name = "\(baseName)_del1.\(ext)"
        let part2Name = "\(baseName)_del2.\(ext)"
        let part1URL = outputFolder.appendingPathComponent(part1Name)
        let part2URL = outputFolder.appendingPathComponent(part2Name)

        // Remove existing files if they exist
        try? FileManager.default.removeItem(at: part1URL)
        try? FileManager.default.removeItem(at: part2URL)

        // Export first half (0 to midpoint)
        try await exportSegment(
            from: asset,
            startTime: 0,
            endTime: midpoint,
            to: part1URL
        )
        print("   ✅ Created part 1: \(part1Name)")

        // Export second half (midpoint to end)
        try await exportSegment(
            from: asset,
            startTime: midpoint,
            endTime: durationSeconds,
            to: part2URL
        )
        print("   ✅ Created part 2: \(part2Name)")

        return (part1URL, part2URL)
    }

    private func exportSegment(
        from asset: AVURLAsset,
        startTime: Double,
        endTime: Double,
        to outputURL: URL
    ) async throws {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioSplitError.exportSessionCreationFailed
        }

        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 1000)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 1000)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return
        case .failed:
            throw exportSession.error ?? AudioSplitError.exportFailed
        case .cancelled:
            throw AudioSplitError.exportCancelled
        default:
            throw AudioSplitError.exportFailed
        }
    }
}

enum AudioSplitError: LocalizedError {
    case fileTooShort
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .fileTooShort:
            return "Audio file is too short to split (minimum 2 seconds)"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Failed to export audio segment"
        case .exportCancelled:
            return "Export was cancelled"
        }
    }
}
