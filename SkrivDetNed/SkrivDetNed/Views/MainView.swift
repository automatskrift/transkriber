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
            Group {
                if selectedTab == .monitor {
                    FolderMonitorView()
                        .environmentObject(transcriptionVM)
                        .environmentObject(whisperService)
                        .environmentObject(folderMonitorVM)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(NSLocalizedString("Overvågning", comment: ""), systemImage: "folder.badge.gearshape")
            }
            .tag(Tab.monitor)

            Group {
                if selectedTab == .transcriptions {
                    TranscriptionsView()
                        .environmentObject(transcriptionVM)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(NSLocalizedString("Transskriptioner", comment: ""), systemImage: "doc.text.magnifyingglass")
            }
            .tag(Tab.transcriptions)

            Group {
                if selectedTab == .manual {
                    ManualTranscriptionView()
                        .environmentObject(transcriptionVM)
                        .environmentObject(whisperService)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(NSLocalizedString("Manuel", comment: ""), systemImage: "doc.text")
            }
            .tag(Tab.manual)

            Group {
                if selectedTab == .settings {
                    SettingsView()
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(NSLocalizedString("Indstillinger", comment: ""), systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert(NSLocalizedString("Eksisterende filer fundet", comment: ""), isPresented: $folderMonitorVM.showExistingFilesPrompt) {
            Button(String(format: NSLocalizedString("Proces alle (%lld)", comment: ""), folderMonitorVM.existingFilesCount)) {
                folderMonitorVM.processExistingFiles()
            }
            Button(NSLocalizedString("Spring over", comment: ""), role: .cancel) {
                folderMonitorVM.skipExistingFiles()
            }
        } message: {
            Text(String(format: NSLocalizedString("Der blev fundet %lld eksisterende lydfil(er) i iCloud. Vil du transskribere dem nu?", comment: ""), folderMonitorVM.existingFilesCount))
        }
    }
}

#Preview {
    MainView()
}
