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
                GroupBox(label: Label(NSLocalizedString("WhisperKit Modeller", comment: ""), systemImage: "cpu")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("Modeller downloades automatisk første gang de bruges", comment: ""))
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

                                Button(settings.selectedModel == modelType.rawValue ? NSLocalizedString("Valgt", comment: "") : NSLocalizedString("Vælg", comment: "")) {
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
                GroupBox(label: Label(NSLocalizedString("iCloud Sync", comment: ""), systemImage: "icloud")) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(NSLocalizedString("Synkronisér med iOS app via iCloud", comment: ""), isOn: $settings.iCloudSyncEnabled)
                                    .font(.headline)

                                Text(NSLocalizedString("Overvåger automatisk iCloud mappe for optagelser fra iOS appen", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if iCloudSyncService.shared.isAvailable {
                                Label(NSLocalizedString("iCloud tilgængelig", comment: ""), systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Label(NSLocalizedString("iCloud ikke tilgængelig", comment: ""), systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Divider()

                        Toggle(NSLocalizedString("Overvåg også lokal mappe", comment: ""), isOn: $settings.monitorLocalFolderEnabled)
                            .help(NSLocalizedString("Overvåg både iCloud og en lokal mappe samtidig", comment: ""))
                            .disabled(!settings.iCloudSyncEnabled)

                        if let iCloudURL = iCloudSyncService.shared.getRecordingsFolderURL() {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(.secondary)
                                Text(NSLocalizedString("iCloud mappe:", comment: ""))
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
                GroupBox(label: Label(NSLocalizedString("Indstillinger", comment: ""), systemImage: "gear")) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Start at login
                        Toggle(NSLocalizedString("Start ved login", comment: ""), isOn: $settings.startAtLogin)

                        Divider()

                        // Show notifications
                        Toggle(NSLocalizedString("Vis notifikationer", comment: ""), isOn: $settings.showNotifications)

                        Divider()

                        // Delete audio after transcription
                        Toggle(NSLocalizedString("Slet lydfil efter transskription", comment: ""), isOn: $settings.deleteAudioAfterTranscription)
                            .help(NSLocalizedString("Sletter automatisk lydfilerne efter de er blevet transkriberet", comment: ""))

                        Divider()

                        // Language selection
                        HStack {
                            Text(NSLocalizedString("Sprog:", comment: ""))
                            Spacer()
                            Picker("", selection: $settings.selectedLanguage) {
                                Text(NSLocalizedString("Dansk", comment: "")).tag("da")
                                Text(NSLocalizedString("English", comment: "")).tag("en")
                                Text(NSLocalizedString("Svensk", comment: "")).tag("sv")
                                Text(NSLocalizedString("Norsk", comment: "")).tag("no")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }

                        Divider()

                        // Ignored files button
                        Button(action: { showingIgnoredFiles = true }) {
                            HStack {
                                Label(NSLocalizedString("Ignorerede lydfiler", comment: ""), systemImage: "xmark.circle")
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
                                Label(NSLocalizedString("Avancerede indstillinger...", comment: ""), systemImage: "gearshape.2")
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
                        Text(NSLocalizedString("• Aktiv", comment: ""))
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
                    Label(NSLocalizedString("Slet", comment: ""), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if isDownloading {
                Button(action: onCancel) {
                    Label(NSLocalizedString("Annuller", comment: ""), systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: onDownload) {
                    Label(NSLocalizedString("Download", comment: ""), systemImage: "arrow.down.circle")
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
