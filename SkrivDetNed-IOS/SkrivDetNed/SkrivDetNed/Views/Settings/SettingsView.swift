//
//  SettingsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            Form {
                // Recording Settings
                Section {
                    Picker("Lydkvalitet", selection: $settings.audioQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }

                    Toggle("Pause ved opkald", isOn: $settings.pauseOnCall)

                    Toggle("Fortsæt i baggrund", isOn: $settings.backgroundRecording)
                } header: {
                    Label("Optagelse", systemImage: "mic")
                } footer: {
                    Text("Højere kvalitet giver bedre transskriptioner men større filer")
                }

                // iCloud Settings
                Section {
                    Toggle("Auto-upload til iCloud", isOn: $settings.iCloudAutoUpload)

                    Toggle("Auto-download transskriptioner", isOn: $settings.iCloudAutoDownloadTranscriptions)

                    if settings.iCloudAutoUpload {
                        HStack {
                            Text("iCloud Status")
                            Spacer()
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text("Tilgængelig")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("iCloud Sync", systemImage: "icloud")
                } footer: {
                    Text("Optagelser uploades automatisk til iCloud for transskribering på din Mac")
                }

                // Transcription Settings
                Section {
                    Picker("Sprog", selection: $settings.selectedLanguage) {
                        Text("Dansk").tag("da")
                        Text("Engelsk").tag("en")
                        Text("Svensk").tag("sv")
                        Text("Norsk").tag("no")
                        Text("Tysk").tag("de")
                        Text("Fransk").tag("fr")
                        Text("Spansk").tag("es")
                    }

                    Toggle("Vis notifikationer", isOn: $settings.showNotifications)

                    Toggle("Slet lyd efter transskribering", isOn: $settings.deleteAudioAfterTranscription)
                } header: {
                    Label("Transskribering", systemImage: "doc.text")
                } footer: {
                    Text("Transskribering sker på din Mac via SkrivDetNed macOS appen")
                }

                // Privacy Settings
                Section {
                    Toggle("Tilføj lokation til optagelser", isOn: $settings.addLocationToRecordings)
                } header: {
                    Label("Privatliv", systemImage: "hand.raised")
                } footer: {
                    Text("Lokation kan hjælpe med at organisere optagelser")
                }

                // Storage Info
                Section {
                    HStack {
                        Text("Optagelser")
                        Spacer()
                        Text(storageUsed)
                            .foregroundColor(.secondary)
                    }

                    Button("Ryd cache") {
                        clearCache()
                    }
                    .foregroundColor(.red)
                } header: {
                    Label("Lagerplads", systemImage: "internaldrive")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Button("Om SkrivDetNed") {
                        showingAbout = true
                    }

                    Link("Support", destination: URL(string: "https://github.com")!)

                    Link("Privatlivspolitik", destination: URL(string: "https://github.com")!)
                } header: {
                    Label("Om", systemImage: "info.circle")
                }
            }
            .navigationTitle("Indstillinger")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }

    private var storageUsed: String {
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        guard FileManager.default.fileExists(atPath: recordingsDir.path),
              let files = try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 B"
        }

        let totalSize = files.compactMap { url -> Int64? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = values.fileSize else {
                return nil
            }
            return Int64(fileSize)
        }.reduce(0, +)

        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    private func clearCache() {
        // TODO: Implement cache clearing
        print("🗑️ Clearing cache...")
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.blue)

                    Text("SkrivDetNed")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Om appen")
                            .font(.headline)

                        Text("SkrivDetNed gør det nemt at optage lyd på din iPhone og automatisk få det transskriberet til tekst via din Mac.")
                            .font(.body)

                        Text("Funktioner")
                            .font(.headline)
                            .padding(.top)

                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "mic.circle", title: "Høj kvalitet optagelse", description: "Optag lyd i høj kvalitet")
                            FeatureRow(icon: "icloud", title: "iCloud Sync", description: "Automatisk synkronisering")
                            FeatureRow(icon: "doc.text", title: "Transskribering", description: "Præcis tale-til-tekst")
                            FeatureRow(icon: "magnifyingglass", title: "Søgning", description: "Find hurtigt dine optagelser")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Om")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Luk") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
