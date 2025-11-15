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
        VStack(spacing: 0) {
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

            // Status bar at the bottom
            StatusBar()
                .environmentObject(whisperService)
                .environmentObject(transcriptionVM)
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
                    // Semi-transparent background that allows interaction underneath
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)  // Allow clicks to pass through

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

                        // OK button to acknowledge the information
                        Button(action: {
                            whisperService.isLoadingModel = false
                            whisperService.loadingModelName = nil
                        }) {
                            Text(NSLocalizedString("OK", comment: "OK button"))
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
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

// MARK: - Status Bar
struct StatusBar: View {
    @EnvironmentObject private var whisperService: WhisperService
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Status icon and text
            if whisperService.isDownloadingModel {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                    .imageScale(.small)

                if let modelName = whisperService.downloadingModelName {
                    Text(String(format: NSLocalizedString("Downloading model: %@", comment: "Status bar downloading model"), modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(NSLocalizedString("Downloading model...", comment: "Status bar downloading"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Progress indicator
                ProgressView(value: whisperService.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)

                Text(String(format: "%d%%", Int(whisperService.downloadProgress * 100)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

            } else if whisperService.isLoadingModel {
                Image(systemName: "cpu")
                    .foregroundColor(.orange)
                    .imageScale(.small)

                if let modelName = whisperService.loadingModelName {
                    Text(String(format: NSLocalizedString("Loading model into memory: %@", comment: "Status bar loading model"), modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(NSLocalizedString("Loading model into memory...", comment: "Status bar loading"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)

            } else if let currentTask = transcriptionVM.currentTask {
                Image(systemName: "waveform")
                    .foregroundColor(.purple)
                    .imageScale(.small)

                if case .processing(let progress) = currentTask.status {
                    Text(String(format: NSLocalizedString("Transcribing: %@", comment: "Status bar transcribing"), currentTask.fileName))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)

                    Text(String(format: "%d%%", Int(progress * 100)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                } else {
                    Text(String(format: NSLocalizedString("Preparing: %@", comment: "Status bar preparing"), currentTask.fileName))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }

            } else if !transcriptionVM.pendingQueue.isEmpty {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .imageScale(.small)

                Text(String(format: NSLocalizedString("%lld file(s) in queue", comment: "Status bar queue count"), transcriptionVM.pendingQueue.count))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Show model status when in queue
                if whisperService.isModelLoaded, let modelName = whisperService.loadedModelName {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: NSLocalizedString("Model loaded: %@", comment: "Status bar model loaded"), modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(NSLocalizedString("Model not loaded", comment: "Status bar model not loaded"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }

            } else {
                // Idle state
                if whisperService.isModelLoaded, let modelName = whisperService.loadedModelName {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .imageScale(.small)

                    Text(NSLocalizedString("Idle - Ready to transcribe", comment: "Status bar idle"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: NSLocalizedString("Model: %@", comment: "Status bar model name"), modelName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                        .imageScale(.small)

                    Text(NSLocalizedString("Idle - Model not loaded", comment: "Status bar idle no model"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Optional: Add app version or other info
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}

#Preview {
    MainView()
}
