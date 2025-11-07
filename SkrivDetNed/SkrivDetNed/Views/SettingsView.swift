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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Models Section
                GroupBox(label: Label("Whisper Modeller", systemImage: "cpu")) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.models) { model in
                            ModelRow(
                                model: model,
                                isSelected: settings.selectedModel == model.type.rawValue,
                                isDownloading: viewModel.isDownloading(model.type),
                                downloadProgress: viewModel.downloadProgress(for: model.type),
                                onSelect: {
                                    settings.selectedModel = model.type.rawValue
                                },
                                onDownload: {
                                    viewModel.downloadModel(model.type)
                                },
                                onCancel: {
                                    viewModel.cancelDownload(model.type)
                                },
                                onDelete: {
                                    viewModel.deleteModel(model.type)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Storage Info
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.secondary)
                    Text("Lager brugt:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.formattedTotalStorage)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .padding(.horizontal)

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
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
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
