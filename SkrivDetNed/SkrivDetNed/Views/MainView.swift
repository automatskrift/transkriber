//
//  MainView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .monitor
    @StateObject private var folderMonitorVM = FolderMonitorViewModel.shared
    @StateObject private var transcriptionVM = TranscriptionViewModel.shared
    @StateObject private var whisperService = WhisperService.shared

    enum Tab {
        case monitor
        case transcriptions
        case manual
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FolderMonitorView()
                .environmentObject(transcriptionVM)
                .environmentObject(whisperService)
                .environmentObject(folderMonitorVM)
                .tabItem {
                    Label("Overvågning", systemImage: "folder.badge.gearshape")
                }
                .tag(Tab.monitor)

            TranscriptionsView()
                .environmentObject(transcriptionVM)
                .tabItem {
                    Label("Transskriptioner", systemImage: "doc.text.magnifyingglass")
                }
                .tag(Tab.transcriptions)

            ManualTranscriptionView()
                .environmentObject(transcriptionVM)
                .tabItem {
                    Label("Manuel", systemImage: "doc.text")
                }
                .tag(Tab.manual)

            SettingsView()
                .tabItem {
                    Label("Indstillinger", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert("Eksisterende filer fundet", isPresented: $folderMonitorVM.showExistingFilesPrompt) {
            Button("Proces alle (\(folderMonitorVM.existingFilesCount))") {
                folderMonitorVM.processExistingFiles()
            }
            Button("Spring over", role: .cancel) {
                folderMonitorVM.skipExistingFiles()
            }
        } message: {
            Text("Der blev fundet \(folderMonitorVM.existingFilesCount) eksisterende lydfil(er) i iCloud. Vil du transskribere dem nu?")
        }
    }
}

#Preview {
    MainView()
}
