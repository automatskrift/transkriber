//
//  AudioFileService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import AVFoundation

class AudioFileService {
    static let shared = AudioFileService()

    private init() {}

    func getAudioDuration(_ url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return nil
        }
        return duration.seconds
    }

    func getAudioFormat(_ url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }

        guard let descriptions = try? await track.load(.formatDescriptions),
              let formatDescription = descriptions.first else {
            return nil
        }

        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        return fourCharCodeToString(mediaSubType)
    }

    func validateAudioFile(_ url: URL) async -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }

        // Check if it's a valid audio file by trying to create an AVAsset
        let asset = AVURLAsset(url: url)
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []

        return !audioTracks.isEmpty
    }

    private func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((code >> 24) & 0xFF),
            CChar((code >> 16) & 0xFF),
            CChar((code >> 8) & 0xFF),
            CChar(code & 0xFF),
            0
        ]
        return String(cString: bytes)
    }
}
