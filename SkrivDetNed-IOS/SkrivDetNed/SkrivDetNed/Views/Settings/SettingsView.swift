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

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Recording Settings
                Section {
                    Picker(NSLocalizedString("Lydkvalitet", comment: ""), selection: $settings.audioQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }

                    Toggle(NSLocalizedString("Pause ved opkald", comment: ""), isOn: $settings.pauseOnCall)

                    Toggle(NSLocalizedString("Fortsæt i baggrund", comment: ""), isOn: $settings.backgroundRecording)
                } header: {
                    Label(NSLocalizedString("Optagelse", comment: ""), systemImage: "mic")
                } footer: {
                    Text(NSLocalizedString("Højere kvalitet giver bedre transskriptioner men større filer", comment: ""))
                }

                // iCloud Settings
                Section {
                    Toggle(NSLocalizedString("Auto-upload til iCloud", comment: ""), isOn: $settings.iCloudAutoUpload)

                    Toggle(NSLocalizedString("Auto-download transskriptioner", comment: ""), isOn: $settings.iCloudAutoDownloadTranscriptions)

                    if settings.iCloudAutoUpload {
                        HStack {
                            Text(NSLocalizedString("iCloud Status", comment: ""))
                            Spacer()
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("Tilgængelig", comment: ""))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Mac heartbeat status
                        HStack {
                            Text(NSLocalizedString("Mac Status", comment: ""))
                            Spacer()
                            if let heartbeat = lastMacHeartbeat {
                                VStack(alignment: .trailing, spacing: 4) {
                                    if Date().timeIntervalSince(heartbeat) < 120 {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 8, height: 8)
                                            Text(NSLocalizedString("Online", comment: ""))
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.orange)
                                                .frame(width: 8, height: 8)
                                            Text(NSLocalizedString("Offline", comment: ""))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    Text(timeAgoString(from: heartbeat))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(NSLocalizedString("Ukendt", comment: ""))
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
                    Label(NSLocalizedString("iCloud Sync", comment: ""), systemImage: "icloud")
                } footer: {
                    Text(NSLocalizedString("Optagelser uploades automatisk til iCloud for transskribering på din Mac", comment: ""))
                }
                .onAppear {
                    refreshHeartbeat()
                }

                // Transcription Settings
                Section {
                    Picker(NSLocalizedString("Sprog", comment: ""), selection: $settings.selectedLanguage) {
                        Text(NSLocalizedString("Dansk", comment: "")).tag("da")
                        Text(NSLocalizedString("Engelsk", comment: "")).tag("en")
                        Text(NSLocalizedString("Svensk", comment: "")).tag("sv")
                        Text(NSLocalizedString("Norsk", comment: "")).tag("no")
                        Text(NSLocalizedString("Tysk", comment: "")).tag("de")
                        Text(NSLocalizedString("Fransk", comment: "")).tag("fr")
                        Text(NSLocalizedString("Spansk", comment: "")).tag("es")
                    }

                    Toggle(NSLocalizedString("Vis notifikationer", comment: ""), isOn: $settings.showNotifications)

                    Toggle(NSLocalizedString("Slet lyd efter transskribering", comment: ""), isOn: $settings.deleteAudioAfterTranscription)
                } header: {
                    Label(NSLocalizedString("Transskribering", comment: ""), systemImage: "doc.text")
                } footer: {
                    Text(String(format: NSLocalizedString("Transskribering sker på din Mac via %@ macOS appen", comment: ""), NSLocalizedString("app_name", comment: "")))
                }

                // LLM Prompts Settings
                Section {
                    NavigationLink(destination: PromptsEditorView()) {
                        HStack {
                            Text(NSLocalizedString("Rediger prompts", comment: ""))
                            Spacer()
                            Text("\(settings.transcriptionPrompts.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Label(NSLocalizedString("LLM Prompts", comment: ""), systemImage: "brain")
                } footer: {
                    Text(NSLocalizedString("Forudindstillede prompts til at bearbejde transskriptioner med LLM'er. Når du vælger en prompt under optagelse, sættes den valgte tekst først i transskriptionen. Dette gør det nemt at kopiere og indsætte direkte i en LLM (f.eks. ChatGPT). Du kan også bruge funktionen til at starte din transskription med en bestemt tekst.", comment: "LLM Prompts explanation"))
                }

                // Privacy Settings
                Section {
                    Toggle(NSLocalizedString("Tilføj lokation til optagelser", comment: ""), isOn: $settings.addLocationToRecordings)
                } header: {
                    Label(NSLocalizedString("Privatliv", comment: ""), systemImage: "hand.raised")
                } footer: {
                    Text(NSLocalizedString("Lokation kan hjælpe med at organisere optagelser", comment: ""))
                }

                // Storage Info
                Section {
                    HStack {
                        Text(NSLocalizedString("Optagelser", comment: ""))
                        Spacer()
                        Text(storageUsed)
                            .foregroundColor(.secondary)
                    }

                    Button(NSLocalizedString("Ryd cache", comment: "")) {
                        showingClearCacheAlert = true
                    }
                    .foregroundColor(.red)
                } header: {
                    Label(NSLocalizedString("Lagerplads", comment: ""), systemImage: "internaldrive")
                }

                // About Section
                Section {
                    HStack {
                        Text(NSLocalizedString("Version", comment: ""))
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    Button(String(format: NSLocalizedString("Om %@", comment: ""), NSLocalizedString("app_name", comment: ""))) {
                        showingAbout = true
                    }

                    Link(NSLocalizedString("Support", comment: ""), destination: URL(string: "https://omdethele.dk/apps")!)

                    Link(NSLocalizedString("Privatlivspolitik", comment: ""), destination: URL(string: "https://omdethele.dk/apps")!)
                } header: {
                    Label(NSLocalizedString("Om", comment: ""), systemImage: "info.circle")
                }
            }
            .navigationTitle(NSLocalizedString("Indstillinger", comment: ""))
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert(NSLocalizedString("Ryd cache", comment: ""), isPresented: $showingClearCacheAlert) {
                Button(NSLocalizedString("Annuller", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("Ryd cache", comment: ""), role: .destructive) {
                    clearCache()
                }
            } message: {
                Text(NSLocalizedString("Dette vil slette alle lokale optagelser og transskriptioner. Filer i iCloud påvirkes ikke.\n\nDenne handling kan ikke fortrydes.", comment: ""))
            }
            .alert(NSLocalizedString("Cache ryddet", comment: ""), isPresented: $cacheCleared) {
                Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Alle lokale filer er blevet slettet.", comment: ""))
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
            return NSLocalizedString("Sidst set: nu", comment: "")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: NSLocalizedString("Sidst set: %lld min siden", comment: ""), minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            if hours == 1 {
                return String(format: NSLocalizedString("Sidst set: %lld time siden", comment: ""), hours)
            } else {
                return String(format: NSLocalizedString("Sidst set: %lld timer siden", comment: ""), hours)
            }
        } else {
            let days = Int(interval / 86400)
            if days == 1 {
                return String(format: NSLocalizedString("Sidst set: %lld dag siden", comment: ""), days)
            } else {
                return String(format: NSLocalizedString("Sidst set: %lld dage siden", comment: ""), days)
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.blue)

                    Text(NSLocalizedString("app_name", comment: ""))
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("Om appen", comment: ""))
                            .font(.headline)

                        Text(String(format: NSLocalizedString("%@ gør det nemt at optage lyd på din iPhone og automatisk få det transskriberet til tekst via din Mac.", comment: ""), NSLocalizedString("app_name", comment: "")))
                            .font(.body)

                        Text(NSLocalizedString("Funktioner", comment: ""))
                            .font(.headline)
                            .padding(.top)

                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "mic.circle", title: NSLocalizedString("Høj kvalitet optagelse", comment: ""), description: NSLocalizedString("Optag lyd i høj kvalitet", comment: ""))
                            FeatureRow(icon: "icloud", title: NSLocalizedString("iCloud Sync", comment: ""), description: NSLocalizedString("Automatisk synkronisering", comment: ""))
                            FeatureRow(icon: "doc.text", title: NSLocalizedString("Transskribering", comment: ""), description: NSLocalizedString("Præcis tale-til-tekst", comment: ""))
                            FeatureRow(icon: "magnifyingglass", title: NSLocalizedString("Søgning", comment: ""), description: NSLocalizedString("Find hurtigt dine optagelser", comment: ""))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("Om", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Luk", comment: "")) {
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
