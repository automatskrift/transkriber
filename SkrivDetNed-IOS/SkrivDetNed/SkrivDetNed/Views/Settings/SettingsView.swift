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
    @State private var showingClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var lastMacHeartbeat: Date?

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

                        Divider()

                        // Mac heartbeat status
                        HStack {
                            Text("Mac Status")
                            Spacer()
                            if let heartbeat = lastMacHeartbeat {
                                VStack(alignment: .trailing, spacing: 4) {
                                    if Date().timeIntervalSince(heartbeat) < 120 {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 8, height: 8)
                                            Text("Online")
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.orange)
                                                .frame(width: 8, height: 8)
                                            Text("Offline")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    Text(timeAgoString(from: heartbeat))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Ukendt")
                                    .foregroundColor(.secondary)
                            }
                            Button(action: refreshHeartbeat) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Label("iCloud Sync", systemImage: "icloud")
                } footer: {
                    Text("Optagelser uploades automatisk til iCloud for transskribering på din Mac")
                }
                .onAppear {
                    refreshHeartbeat()
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

                // LLM Prompts Settings
                Section {
                    NavigationLink(destination: PromptsEditorView()) {
                        HStack {
                            Text("Rediger prompts")
                            Spacer()
                            Text("\(settings.transcriptionPrompts.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Label("LLM Prompts", systemImage: "brain")
                } footer: {
                    Text("Forudindstillede prompts til at bearbejde transskriptioner med LLM'er")
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
                        showingClearCacheAlert = true
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
            .alert("Ryd cache", isPresented: $showingClearCacheAlert) {
                Button("Annuller", role: .cancel) {}
                Button("Ryd cache", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("Dette vil slette alle lokale optagelser og transskriptioner. Filer i iCloud påvirkes ikke.\n\nDenne handling kan ikke fortrydes.")
            }
            .alert("Cache ryddet", isPresented: $cacheCleared) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Alle lokale filer er blevet slettet.")
            }
        }
    }

    private var storageUsed: String {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDir.appendingPathComponent("Recordings")
        var totalSize: Int64 = 0

        // 1. Size of Recordings directory (metadata)
        if fileManager.fileExists(atPath: recordingsDir.path),
           let files = try? fileManager.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            totalSize += files.compactMap { url -> Int64? in
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                      let fileSize = values.fileSize else {
                    return nil
                }
                return Int64(fileSize)
            }.reduce(0, +)
        }

        // 2. Size of audio files in Documents root
        if let files = try? fileManager.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            let audioFiles = files.filter { url in
                url.lastPathComponent.hasPrefix("recording_") &&
                (url.pathExtension == "m4a" || url.pathExtension == "mp3" || url.pathExtension == "wav")
            }

            totalSize += audioFiles.compactMap { url -> Int64? in
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                      let fileSize = values.fileSize else {
                    return nil
                }
                return Int64(fileSize)
            }.reduce(0, +)
        }

        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    private func clearCache() {
        print("🗑️ Clearing cache...")

        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDir.appendingPathComponent("Recordings")
        var totalDeletedCount = 0

        // 1. Clear Recordings directory (metadata JSON files)
        if fileManager.fileExists(atPath: recordingsDir.path) {
            do {
                let files = try fileManager.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)

                for fileURL in files {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        totalDeletedCount += 1
                        print("🗑️ Deleted metadata: \(fileURL.lastPathComponent)")
                    } catch {
                        print("⚠️ Failed to delete \(fileURL.lastPathComponent): \(error)")
                    }
                }
            } catch {
                print("❌ Failed to clear Recordings directory: \(error)")
            }
        }

        // 2. Delete audio files from Documents root (recording_*.m4a)
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { url in
                url.lastPathComponent.hasPrefix("recording_") &&
                (url.pathExtension == "m4a" || url.pathExtension == "mp3" || url.pathExtension == "wav")
            }

            for audioFile in audioFiles {
                do {
                    try fileManager.removeItem(at: audioFile)
                    totalDeletedCount += 1
                    print("🗑️ Deleted audio: \(audioFile.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to delete audio file \(audioFile.lastPathComponent): \(error)")
                }
            }
        } catch {
            print("❌ Failed to scan Documents directory: \(error)")
        }

        print("✅ Cache cleared: \(totalDeletedCount) files deleted")
        cacheCleared = true
    }

    private func refreshHeartbeat() {
        lastMacHeartbeat = iCloudSyncService.shared.getLastHeartbeat()
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Sidst set: nu"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Sidst set: \(minutes) min siden"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Sidst set: \(hours) time\(hours == 1 ? "" : "r") siden"
        } else {
            let days = Int(interval / 86400)
            return "Sidst set: \(days) dag\(days == 1 ? "" : "e") siden"
        }
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
