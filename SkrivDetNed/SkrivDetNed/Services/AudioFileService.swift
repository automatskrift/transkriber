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

    func getAudioDuration(_ url: URL) -> TimeInterval? {
        let asset = AVAsset(url: url)
        return asset.duration.seconds
    }

    func getAudioFormat(_ url: URL) -> String? {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return nil
        }

        let descriptions = track.formatDescriptions as! [CMFormatDescription]
        guard let formatDescription = descriptions.first else {
            return nil
        }

        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        return fourCharCodeToString(mediaSubType)
    }

    func validateAudioFile(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }

        // Check if it's a valid audio file by trying to create an AVAsset
        let asset = AVAsset(url: url)
        let audioTracks = asset.tracks(withMediaType: .audio)

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
