//
//  AppSettings.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Recording settings
    @AppStorage("audioQuality") var audioQuality: AudioQuality = .high
    @AppStorage("pauseOnCall") var pauseOnCall: Bool = true
    @AppStorage("backgroundRecording") var backgroundRecording: Bool = true

    // iCloud sync settings
    @AppStorage("iCloudAutoUpload") var iCloudAutoUpload: Bool = true
    @AppStorage("iCloudAutoDownloadTranscriptions") var iCloudAutoDownloadTranscriptions: Bool = true

    // Transcription settings
    @AppStorage("selectedLanguage") var selectedLanguage: String = "da"
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("deleteAudioAfterTranscription") var deleteAudioAfterTranscription: Bool = false

    // App settings
    @AppStorage("addLocationToRecordings") var addLocationToRecordings: Bool = false

    private init() {}
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Lav (32 kbps)"
        case .medium: return "Medium (64 kbps)"
        case .high: return "Høj (128 kbps)"
        }
    }

    var sampleRate: Double {
        switch self {
        case .low: return 22050.0
        case .medium: return 44100.0
        case .high: return 44100.0
        }
    }

    var bitRate: Int {
        switch self {
        case .low: return 32000
        case .medium: return 64000
        case .high: return 128000
        }
    }
}
