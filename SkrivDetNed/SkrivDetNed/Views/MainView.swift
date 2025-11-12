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
    @State private var showModelDownloadAlert = false

    enum Tab {
        case monitor
        case transcriptions
        case manual
        case monitorFolder
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
                Label(NSLocalizedString("Overvågning", comment: ""), systemImage: "clock.arrow.circlepath")
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
                if selectedTab == .monitorFolder {
                    MonitorFolderView()
                        .environmentObject(folderMonitorVM)
                } else {
                    Color.clear
                }
            }
            .tabItem {
                Label(NSLocalizedString("Monitor Folder", comment: "Monitor Folder tab"), systemImage: "folder.badge.gearshape")
            }
            .tag(Tab.monitorFolder)

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
        .overlay {
            // Show download alert globally when WhisperKit is downloading a model
            if whisperService.isDownloadingModel, let modelName = whisperService.downloadingModelName {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ModelDownloadAlert(
                        modelName: modelName,
                        isPresented: .constant(true)
                    )
                    .environmentObject(whisperService)
                }
            } else if whisperService.isLoadingModel {
                // Show loading indicator when model is being loaded into memory
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle())

                        Text(NSLocalizedString("Loading model...", comment: "Loading model message"))
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let modelName = whisperService.loadingModelName {
                            Text(modelName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(NSLocalizedString("This may take a moment for large models", comment: "Loading model info"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                }
            }
        }
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
