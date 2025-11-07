//
//  AppSettings.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @AppStorage("selectedModel") var selectedModel: String = WhisperModelType.base.rawValue
    @AppStorage("monitoredFolderPath") var monitoredFolderPath: String = ""
    @AppStorage("monitoredFolderBookmark") var monitoredFolderBookmark: Data?
    @AppStorage("isMonitoringEnabled") var isMonitoringEnabled: Bool = false
    @AppStorage("showNotifications") var showNotifications: Bool = true
    @AppStorage("deleteAudioAfterTranscription") var deleteAudioAfterTranscription: Bool = false
    @AppStorage("selectedLanguage") var selectedLanguage: String = "da"
    @AppStorage("startAtLogin") var startAtLogin: Bool = false

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
