//
//  SettingsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = ModelManagerViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingAdvancedSettings = false
    @State private var showingIgnoredFiles = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Models Section
                GroupBox(label: Label("WhisperKit Modeller", systemImage: "cpu")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Modeller downloades automatisk første gang de bruges")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        ForEach(WhisperModelType.allCases) { modelType in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(modelType.displayName)
                                        .font(.headline)
                                    Text(modelType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if settings.selectedModel == modelType.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }

                                Button(settings.selectedModel == modelType.rawValue ? "Valgt" : "Vælg") {
                                    settings.selectedModel = modelType.rawValue
                                }
                                .buttonStyle(.bordered)
                                .disabled(settings.selectedModel == modelType.rawValue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // iCloud Sync
                GroupBox(label: Label("iCloud Sync", systemImage: "icloud")) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Synkronisér med iOS app via iCloud", isOn: $settings.iCloudSyncEnabled)
                                    .font(.headline)

                                Text("Overvåger automatisk iCloud mappe for optagelser fra iOS appen")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if iCloudSyncService.shared.isAvailable {
                                Label("iCloud tilgængelig", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Label("iCloud ikke tilgængelig", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Divider()

                        Toggle("Overvåg også lokal mappe", isOn: $settings.monitorLocalFolderEnabled)
                            .help("Overvåg både iCloud og en lokal mappe samtidig")
                            .disabled(!settings.iCloudSyncEnabled)

                        if let iCloudURL = iCloudSyncService.shared.getRecordingsFolderURL() {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(.secondary)
                                Text("iCloud mappe:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(iCloudURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // General Settings
                GroupBox(label: Label("Indstillinger", systemImage: "gear")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Start at login
                        Toggle("Start ved login", isOn: $settings.startAtLogin)

                        Divider()

                        // Show notifications
                        Toggle("Vis notifikationer", isOn: $settings.showNotifications)

                        Divider()

                        // Delete audio after transcription
                        Toggle("Slet lydfil efter transskription", isOn: $settings.deleteAudioAfterTranscription)
                            .help("Sletter automatisk lydfilerne efter de er blevet transkriberet")

                        Divider()

                        // Language selection
                        HStack {
                            Text("Sprog:")
                            Spacer()
                            Picker("", selection: $settings.selectedLanguage) {
                                Text("Dansk").tag("da")
                                Text("English").tag("en")
                                Text("Svensk").tag("sv")
                                Text("Norsk").tag("no")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }

                        Divider()

                        // Ignored files button
                        Button(action: { showingIgnoredFiles = true }) {
                            HStack {
                                Label("Ignorerede lydfiler", systemImage: "xmark.circle")
                                Spacer()
                                if !settings.ignoredFiles.isEmpty {
                                    Text("\(settings.ignoredFiles.count)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)

                        Divider()

                        // Advanced settings button
                        Button(action: { showingAdvancedSettings = true }) {
                            HStack {
                                Label("Avancerede indstillinger...", systemImage: "gearshape.2")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView()
        }
        .sheet(isPresented: $showingIgnoredFiles) {
            IgnoredFilesView()
        }
        .onAppear {
            viewModel.refreshModels()
        }
    }
}

struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Selection radio button
            Button(action: {
                if model.isDownloaded {
                    onSelect()
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!model.isDownloaded)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.type.displayName)
                        .font(.headline)

                    Text("(\(model.type.fileSizeFormatted))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isSelected {
                        Text("• Aktiv")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                }

                Text(model.type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Progress bar
                if isDownloading, let progress = downloadProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action button
            if model.isDownloaded {
                Button(action: onDelete) {
                    Label("Slet", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if isDownloading {
                Button(action: onCancel) {
                    Label("Annuller", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView()
}
