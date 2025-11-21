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
    private let defaults = UserDefaults.standard

    // Basic settings - use @Published with manual UserDefaults sync to avoid AttributeGraph cycles
    @Published var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var isMonitoringEnabled: Bool {
        didSet { defaults.set(isMonitoringEnabled, forKey: "isMonitoringEnabled") }
    }
    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: "showNotifications") }
    }
    @Published var deleteAudioAfterTranscription: Bool {
        didSet { defaults.set(deleteAudioAfterTranscription, forKey: "deleteAudioAfterTranscription") }
    }
    @Published var selectedLanguage: String {
        didSet { defaults.set(selectedLanguage, forKey: "selectedLanguage") }
    }
    @Published var startAtLogin: Bool {
        didSet { defaults.set(startAtLogin, forKey: "startAtLogin") }
    }

    // iCloud sync settings
    @Published var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }

    // Ignored files (failed transcriptions that user wants to skip)
    private var ignoredFilesData: Data {
        get { defaults.data(forKey: "ignoredFiles") ?? Data() }
        set { defaults.set(newValue, forKey: "ignoredFiles") }
    }

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
            objectWillChange.send()
        }
    }

    // Advanced Whisper settings
    @Published var whisperTemperature: Double {
        didSet { defaults.set(whisperTemperature, forKey: "whisperTemperature") }
    }
    @Published var whisperTranslateToEnglish: Bool {
        didSet { defaults.set(whisperTranslateToEnglish, forKey: "whisperTranslateToEnglish") }
    }
    @Published var whisperInitialPrompt: String {
        didSet { defaults.set(whisperInitialPrompt, forKey: "whisperInitialPrompt") }
    }
    @Published var whisperIncludeTimestamps: Bool {
        didSet { defaults.set(whisperIncludeTimestamps, forKey: "whisperIncludeTimestamps") }
    }
    @Published var whisperWordLevelTimestamps: Bool {
        didSet { defaults.set(whisperWordLevelTimestamps, forKey: "whisperWordLevelTimestamps") }
    }
    @Published var whisperThreadCount: Int {
        didSet { defaults.set(whisperThreadCount, forKey: "whisperThreadCount") }
    }
    @Published var whisperAutoDetectLanguage: Bool {
        didSet { defaults.set(whisperAutoDetectLanguage, forKey: "whisperAutoDetectLanguage") }
    }
    @Published var autoUnloadModel: Bool {
        didSet { defaults.set(autoUnloadModel, forKey: "autoUnloadModel") }
    }

    // Whisper decoding thresholds (advanced)
    @Published var whisperCompressionRatioThreshold: Double {
        didSet { defaults.set(whisperCompressionRatioThreshold, forKey: "whisperCompressionRatioThreshold") }
    }
    @Published var whisperLogProbThreshold: Double {
        didSet { defaults.set(whisperLogProbThreshold, forKey: "whisperLogProbThreshold") }
    }
    @Published var whisperNoSpeechThreshold: Double {
        didSet { defaults.set(whisperNoSpeechThreshold, forKey: "whisperNoSpeechThreshold") }
    }

    static let shared = AppSettings()

    private init() {
        // Load saved values from UserDefaults
        self.selectedModel = defaults.string(forKey: "selectedModel") ?? WhisperModelType.base.rawValue
        self.isMonitoringEnabled = defaults.bool(forKey: "isMonitoringEnabled")
        self.showNotifications = defaults.object(forKey: "showNotifications") as? Bool ?? true
        self.deleteAudioAfterTranscription = defaults.bool(forKey: "deleteAudioAfterTranscription")
        self.selectedLanguage = defaults.string(forKey: "selectedLanguage") ?? "da"
        self.startAtLogin = defaults.bool(forKey: "startAtLogin")
        self.iCloudSyncEnabled = defaults.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        self.whisperTemperature = defaults.double(forKey: "whisperTemperature")
        self.whisperTranslateToEnglish = defaults.bool(forKey: "whisperTranslateToEnglish")
        self.whisperInitialPrompt = defaults.string(forKey: "whisperInitialPrompt") ?? ""
        self.whisperIncludeTimestamps = defaults.bool(forKey: "whisperIncludeTimestamps")
        self.whisperWordLevelTimestamps = defaults.bool(forKey: "whisperWordLevelTimestamps")
        self.whisperThreadCount = defaults.object(forKey: "whisperThreadCount") as? Int ?? 1
        self.whisperAutoDetectLanguage = defaults.bool(forKey: "whisperAutoDetectLanguage")
        self.autoUnloadModel = defaults.object(forKey: "autoUnloadModel") as? Bool ?? true

        // Whisper decoding thresholds (defaults are more permissive to avoid cutting off audio)
        self.whisperCompressionRatioThreshold = defaults.object(forKey: "whisperCompressionRatioThreshold") as? Double ?? 2.8
        self.whisperLogProbThreshold = defaults.object(forKey: "whisperLogProbThreshold") as? Double ?? -1.5
        self.whisperNoSpeechThreshold = defaults.object(forKey: "whisperNoSpeechThreshold") as? Double ?? 0.8
    }

    var selectedModelType: WhisperModelType {
        WhisperModelType(rawValue: selectedModel) ?? .base
    }
}
