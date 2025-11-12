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
    @State private var downloadedModels: Set<String> = []
    @State private var showDeleteAlert = false
    @State private var modelToDelete: WhisperModelType?
    @State private var showMemoryWarning = false
    @State private var pendingModelSelection: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Models Section
                GroupBox(label: Label(NSLocalizedString("WhisperKit Modeller", comment: ""), systemImage: "cpu")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("Modeller downloades automatisk første gang de bruges", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: openModelsFolder) {
                                Label(NSLocalizedString("Åbn model-folder", comment: ""), systemImage: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        Divider()

                        ForEach(WhisperModelType.allCases) { modelType in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(modelType.displayName)
                                            .font(.headline)

                                        // Show downloaded indicator
                                        if isModelDownloaded(modelType) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                        }
                                    }
                                    Text(modelType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Delete button for downloaded models
                                if isModelDownloaded(modelType) {
                                    Button(action: {
                                        modelToDelete = modelType
                                        showDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .help(NSLocalizedString("Slet model", comment: ""))
                                }

                                if settings.selectedModel == modelType.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }

                                Button(settings.selectedModel == modelType.rawValue ? NSLocalizedString("Valgt", comment: "") : NSLocalizedString("Vælg", comment: "")) {
                                    selectModel(modelType)
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
                            Text(NSLocalizedString("Sprog", comment: "") + ":")
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
        .alert(NSLocalizedString("Slet model?", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("Slet", comment: ""), role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
            }
            Button(NSLocalizedString("Annuller", comment: ""), role: .cancel) {}
        } message: {
            if let model = modelToDelete {
                Text(String(format: NSLocalizedString("Er du sikker på at du vil slette %@? Du kan altid downloade den igen senere.", comment: ""), model.displayName))
            }
        }
        .alert(NSLocalizedString("Hukommelsesadvarsel", comment: "Memory warning title"), isPresented: $showMemoryWarning) {
            Button(NSLocalizedString("Fortsæt alligevel", comment: "Continue anyway button")) {
                if let modelName = pendingModelSelection {
                    settings.selectedModel = modelName
                }
                pendingModelSelection = nil
            }
            Button(NSLocalizedString("Vælg mindre model", comment: "Choose smaller model button"), role: .cancel) {
                pendingModelSelection = nil
            }
        } message: {
            let totalMemory = SystemRequirements.shared.getTotalMemory()
            let totalMemoryGB = ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)

            let messageFormat = NSLocalizedString("Large modellen kræver cirka 6GB RAM for optimal ydeevne.\n\nDit system har %@ total RAM.\n\nDette kan medføre:\n• Langsom transskriptionshastighed\n• Midlertidig systemfrysning\n• Mulige app-nedbrud\n\nVi anbefaler Medium eller Small model for bedre stabilitet.", comment: "Memory warning message")

            Text(String(format: messageFormat, totalMemoryGB))
        }
        .onAppear {
            viewModel.refreshModels()
            checkDownloadedModels()
        }
    }

    private func openModelsFolder() {
        // WhisperKit stores models in ~/Documents/huggingface/models/ by default
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not get documents directory")
            return
        }

        let huggingfaceModelsDir = documentsURL
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        // Check if folder exists, if not open the huggingface folder or documents folder
        var folderToOpen = huggingfaceModelsDir
        if !fileManager.fileExists(atPath: huggingfaceModelsDir.path) {
            let huggingfaceDir = documentsURL.appendingPathComponent("huggingface")
            if fileManager.fileExists(atPath: huggingfaceDir.path) {
                folderToOpen = huggingfaceDir
            } else {
                folderToOpen = documentsURL
            }
        }

        print("📂 Opening models folder: \(folderToOpen.path)")
        NSWorkspace.shared.activateFileViewerSelecting([folderToOpen])
    }

    private func checkDownloadedModels() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let modelsBaseDir = documentsURL
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        guard fileManager.fileExists(atPath: modelsBaseDir.path) else {
            downloadedModels = []
            return
        }

        var downloaded = Set<String>()

        // Check each model type
        for modelType in WhisperModelType.allCases {
            let modelVariant: String
            switch modelType {
            case .tiny: modelVariant = "openai_whisper-tiny"
            case .base: modelVariant = "openai_whisper-base"
            case .small: modelVariant = "openai_whisper-small"
            case .medium: modelVariant = "openai_whisper-medium"
            case .large: modelVariant = "openai_whisper-large-v3"
            }

            let modelPath = modelsBaseDir.appendingPathComponent(modelVariant)
            if fileManager.fileExists(atPath: modelPath.path) {
                downloaded.insert(modelType.rawValue)
                print("✅ Found downloaded model: \(modelVariant)")
            }
        }

        downloadedModels = downloaded
    }

    private func isModelDownloaded(_ modelType: WhisperModelType) -> Bool {
        return downloadedModels.contains(modelType.rawValue)
    }

    private func selectModel(_ modelType: WhisperModelType) {
        // Check memory for large model
        if modelType == .large {
            let memCheck = SystemRequirements.shared.hasSufficientMemory(for: modelType)
            if memCheck.warning != nil {
                // Show warning but allow selection
                pendingModelSelection = modelType.rawValue
                showMemoryWarning = true
                return
            }
        }

        // Direct selection for other models
        settings.selectedModel = modelType.rawValue
    }

    private func deleteModel(_ modelType: WhisperModelType) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not get documents directory")
            return
        }

        let modelsBaseDir = documentsURL
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")

        let modelVariant: String
        switch modelType {
        case .tiny: modelVariant = "openai_whisper-tiny"
        case .base: modelVariant = "openai_whisper-base"
        case .small: modelVariant = "openai_whisper-small"
        case .medium: modelVariant = "openai_whisper-medium"
        case .large: modelVariant = "openai_whisper-large-v3"
        }

        let modelPath = modelsBaseDir.appendingPathComponent(modelVariant)

        do {
            if fileManager.fileExists(atPath: modelPath.path) {
                try fileManager.removeItem(at: modelPath)
                print("🗑️ Deleted model: \(modelVariant) at \(modelPath.path)")

                // Update downloaded models set
                downloadedModels.remove(modelType.rawValue)

                // If this was the selected model, reset to base
                if settings.selectedModel == modelType.rawValue {
                    settings.selectedModel = WhisperModelType.base.rawValue
                    print("⚠️ Deleted selected model, reset to Base")
                }
            }
        } catch {
            print("❌ Failed to delete model: \(error)")
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
