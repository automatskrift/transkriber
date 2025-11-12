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
    // Basic settings
    @AppStorage("selectedModel") var selectedModel: String = WhisperModelType.base.rawValue
    @AppStorage("isMonitoringEnabled") var isMonitoringEnabled: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("deleteAudioAfterTranscription") var deleteAudioAfterTranscription: Bool = false
    @AppStorage("selectedLanguage") var selectedLanguage: String = "da"
    @AppStorage("startAtLogin") var startAtLogin: Bool = false

    // iCloud sync settings
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = true

    // Ignored files (failed transcriptions that user wants to skip)
    @AppStorage("ignoredFiles") private var ignoredFilesData: Data = Data()

    var ignoredFiles: Set<String> {
        get {
            guard let set = try? JSONDecoder().decode(Set<String>.self, from: ignoredFilesData) else {
                return []
            }
            return set
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            ignoredFilesData = data
        }
    }

    // Advanced Whisper settings
    @AppStorage("whisperTemperature") var whisperTemperature: Double = 0.0
    @AppStorage("whisperTranslateToEnglish") var whisperTranslateToEnglish: Bool = false
    @AppStorage("whisperInitialPrompt") var whisperInitialPrompt: String = ""
    @AppStorage("whisperIncludeTimestamps") var whisperIncludeTimestamps: Bool = false
    @AppStorage("whisperWordLevelTimestamps") var whisperWordLevelTimestamps: Bool = false
    @AppStorage("whisperThreadCount") var whisperThreadCount: Int = 1 // Number of concurrent workers (default 1 for stability)
    @AppStorage("whisperAutoDetectLanguage") var whisperAutoDetectLanguage: Bool = false

    static let shared = AppSettings()

    var selectedModelType: WhisperModelType {
        WhisperModelType(rawValue: selectedModel) ?? .base
    }
}
