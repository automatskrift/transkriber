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
    @AppStorage("monitoredFolderPath") var monitoredFolderPath: String = ""
    @AppStorage("monitoredFolderBookmark") var monitoredFolderBookmark: Data?
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

    var monitoredFolderURL: URL? {
        get {
            guard let bookmarkData = monitoredFolderBookmark else { return nil }

            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return nil
            }

            return url
        }
        set {
            guard let url = newValue else {
                monitoredFolderBookmark = nil
                monitoredFolderPath = ""
                return
            }

            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                self.monitoredFolderBookmark = bookmarkData
                self.monitoredFolderPath = url.path
            } catch {
                print("Failed to create bookmark: \(error)")
            }
        }
    }
}
