//
//  ManualTranscriptionView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ManualTranscriptionView: View {
    @State private var selectedFileURL: URL?
    @State private var transcriptionResult: String?
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var showTranscriptionExistsAlert = false
    @State private var showIgnoredFileAlert = false
    @State private var fileAddedToQueue = false  // Track if file was added to queue

    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @EnvironmentObject private var whisperService: WhisperService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // File Selection
                GroupBox(label: Label(NSLocalizedString("Vælg Lydfil", comment: ""), systemImage: "doc")) {
                    VStack(spacing: 16) {
                        if let fileURL = selectedFileURL {
                            // Selected file info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "waveform")
                                        .font(.title)
                                        .foregroundColor(.accentColor)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(fileURL.lastPathComponent)
                                            .font(.headline)

                                        Text(fileURL.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()
                                }

                                // File info
                                FileInfoView(fileURL: fileURL)
                            }
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)

                            // Output file
                            HStack {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                Text(NSLocalizedString("Output:", comment: ""))
                                    .foregroundColor(.secondary)
                                Text(fileURL.deletingPathExtension().appendingPathExtension("txt").lastPathComponent)
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)

                        } else {
                            // No file selected
                            VStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)

                                Text(NSLocalizedString("Ingen fil valgt", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text(NSLocalizedString("Vælg en lydfil til transskription", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }

                        // Buttons
                        HStack {
                            Button(action: selectFile) {
                                Label(NSLocalizedString("Vælg Fil", comment: ""), systemImage: "folder")
                                    .frame(minWidth: 120)
                            }
                            .buttonStyle(.bordered)

                            if selectedFileURL != nil && !fileAddedToQueue {
                                Button(action: clearSelection) {
                                    Label(NSLocalizedString("Ryd", comment: ""), systemImage: "xmark")
                                }
                                .buttonStyle(.bordered)
                            }

                            Spacer()

                            if selectedFileURL != nil {
                                Button(action: startTranscription) {
                                    Label(NSLocalizedString("Transkribér", comment: ""), systemImage: "play.fill")
                                        .frame(minWidth: 120)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(fileAddedToQueue)
                            }
                        }

                        // Info about automatic model download
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("Modellen downloades automatisk ved første brug", comment: "Info about WhisperKit auto-download"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Model Download Progress
                if whisperService.isDownloadingModel {
                    GroupBox(label: Label(NSLocalizedString("Downloader WhisperKit model", comment: ""), systemImage: "arrow.down.circle.fill")) {
                        VStack(spacing: 12) {
                            if let modelName = whisperService.downloadingModelName {
                                Text(modelName)
                                    .font(.headline)
                            }

                            ProgressView(value: whisperService.downloadProgress)
                                .progressViewStyle(.linear)

                            // Show percentage progress if available
                            if whisperService.downloadProgress > 0 {
                                Text("Download: \(Int(whisperService.downloadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(NSLocalizedString("Dette kan tage flere minutter første gang", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Model Loading Progress
                if whisperService.isLoadingModel {
                    GroupBox(label: Label(NSLocalizedString("Indlæser WhisperKit model", comment: ""), systemImage: "cpu")) {
                        VStack(spacing: 12) {
                            if let modelName = whisperService.downloadingModelName {
                                Text(modelName)
                                    .font(.headline)
                            }

                            ProgressView()
                                .progressViewStyle(.linear)

                            Text(NSLocalizedString("Indlæser model i hukommelsen...", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // File added to queue message
                if fileAddedToQueue {
                    GroupBox(label: Label(NSLocalizedString("Added to Queue", comment: "File added to queue"), systemImage: "clock")) {
                        VStack(spacing: 12) {
                            Text(NSLocalizedString("File has been added to the transcription queue", comment: "Queue confirmation message"))
                                .font(.body)
                                .foregroundColor(.secondary)

                            Text(NSLocalizedString("Go to the Monitoring tab to see progress", comment: "Monitoring tab hint"))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                Button(action: {
                                    // Reset to select new file
                                    selectedFileURL = nil
                                    fileAddedToQueue = false
                                    transcriptionResult = nil
                                    errorMessage = nil
                                }) {
                                    Label(NSLocalizedString("Transcribe Another File", comment: "Transcribe another file button"), systemImage: "doc.badge.plus")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Error message
                if let error = errorMessage {
                    GroupBox {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Success message
                if let result = transcriptionResult {
                    GroupBox(label: Label(NSLocalizedString("Færdig", comment: ""), systemImage: "checkmark.circle.fill")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("Transskriptionen er klar", comment: ""))
                                .font(.headline)

                            if let fileURL = selectedFileURL {
                                let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")

                                HStack(spacing: 12) {
                                    Button(action: {
                                        saveTranscriptionAs(text: result, suggestedFilename: outputURL.lastPathComponent)
                                    }) {
                                        Label(NSLocalizedString("Gem som...", comment: ""), systemImage: "square.and.arrow.down")
                                    }
                                    .buttonStyle(.borderedProminent)

                                    // Only show "Vis i Finder" if file actually exists at the expected location
                                    if FileManager.default.fileExists(atPath: outputURL.path) {
                                        Button(action: {
                                            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                                        }) {
                                            Label(NSLocalizedString("Vis i Finder", comment: ""), systemImage: "folder")
                                        }
                                        .buttonStyle(.bordered)

                                        Text(NSLocalizedString("Gemt til:", comment: ""))
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        Text(outputURL.lastPathComponent)
                                            .fontWeight(.medium)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Drag and drop area
                if selectedFileURL == nil && !fileAddedToQueue {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)

                        Text(NSLocalizedString("Eller træk en lydfil hertil", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(.secondary.opacity(0.3))
                    )
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .overlay {
            // Show download alert only when actually downloading (not when just loading)
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
            }
        }
        .alert(NSLocalizedString("Fil er ignoreret", comment: "File is ignored"), isPresented: $showIgnoredFileAlert) {
            Button(NSLocalizedString("Ja, transkribér alligevel", comment: "Yes, transcribe anyway")) {
                // Remove from ignored list and proceed with transcription
                if let fileURL = selectedFileURL {
                    var ignoredSet = settings.ignoredFiles
                    ignoredSet.remove(fileURL.path)
                    settings.ignoredFiles = ignoredSet
                    print("🔓 Removed from ignored files list: \(fileURL.lastPathComponent)")
                }
                proceedWithTranscription()
            }
            Button(NSLocalizedString("Nej", comment: "No"), role: .cancel) {
                // Do nothing, just dismiss
            }
        } message: {
            if let fileURL = selectedFileURL {
                Text(String(format: NSLocalizedString("%@ er på ignore-listen. Vil du transkribere den alligevel?", comment: "File is on ignore list, transcribe anyway?"), fileURL.lastPathComponent))
            }
        }
        .alert(NSLocalizedString("Fil allerede transkriberet", comment: "File already transcribed"), isPresented: $showTranscriptionExistsAlert) {
            Button(NSLocalizedString("Ja, transkribér igen", comment: "Yes, transcribe again")) {
                // Delete existing transcription file and clear processed status before proceeding
                if let fileURL = selectedFileURL {
                    let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                    try? FileManager.default.removeItem(at: outputURL)
                    print("🗑️ Deleted existing transcription to allow re-transcription: \(outputURL.lastPathComponent)")

                    // Remove from processed files list so it can be transcribed again
                    FolderMonitorService.shared.processedFiles.remove(fileURL.path)
                    print("🔓 Removed from processed files list")

                    // Reset iCloud metadata if this is an iCloud file
                    if let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL(),
                       fileURL.path.contains(recordingsFolder.path) {
                        if var metadata = try? RecordingMetadata.load(for: fileURL.lastPathComponent, from: recordingsFolder) {
                            metadata.status = .pending
                            metadata.errorMessage = nil
                            metadata.lastAttemptedAt = nil
                            metadata.updatedAt = Date()
                            try? metadata.save(to: recordingsFolder)
                            print("🔄 Reset iCloud metadata to pending status")
                        }
                    }
                }
                proceedWithTranscription()
            }
            Button(NSLocalizedString("Nej", comment: "No"), role: .cancel) {
                // Do nothing, just dismiss
            }
        } message: {
            if let fileURL = selectedFileURL {
                Text(String(format: NSLocalizedString("%@ er allerede transkriberet. Vil du transkribere den igen?", comment: "File already transcribed, transcribe again?"), fileURL.lastPathComponent))
            }
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .audio,
            UTType(filenameExtension: "m4a")!,
            UTType(filenameExtension: "mp3")!,
            UTType(filenameExtension: "wav")!,
            UTType(filenameExtension: "aiff")!,
            UTType(filenameExtension: "caf")!
        ]
        panel.prompt = NSLocalizedString("Vælg Lydfil", comment: "")
        panel.message = NSLocalizedString("Vælg en lydfil til transskription", comment: "")

        panel.begin { response in
            if response == .OK, let url = panel.url {
                selectedFileURL = url
                transcriptionResult = nil
                errorMessage = nil
            }
        }
    }

    private func clearSelection() {
        selectedFileURL = nil
        transcriptionResult = nil
        errorMessage = nil
        fileAddedToQueue = false
    }

    private func startTranscription() {
        guard let fileURL = selectedFileURL else { return }

        // Check if file is on ignore list
        if settings.ignoredFiles.contains(fileURL.path) {
            showIgnoredFileAlert = true
            return
        }

        // Check if transcription already exists (either .txt file exists OR file is in processed list)
        let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
        let hasTranscriptionFile = FileManager.default.fileExists(atPath: outputURL.path)
        let isInProcessedList = FolderMonitorService.shared.processedFiles.contains(fileURL.path)

        if hasTranscriptionFile || isInProcessedList {
            print("🔍 File already processed - txt exists: \(hasTranscriptionFile), in processed list: \(isInProcessedList)")
            showTranscriptionExistsAlert = true
            return
        }

        // Start the transcription
        proceedWithTranscription()
    }

    private func proceedWithTranscription() {
        guard let fileURL = selectedFileURL else {
            print("❌ proceedWithTranscription: No file selected")
            return
        }

        print("🚀 Manuel transkription: Adding \(fileURL.lastPathComponent) to queue")

        // Reset state
        transcriptionResult = nil
        errorMessage = nil

        // Add to queue and show confirmation
        Task {
            await transcriptionVM.addToQueue(fileURL)
            print("✅ File added to queue")

            // Show "Added to Queue" message
            await MainActor.run {
                fileAddedToQueue = true
            }

            // Monitor for completion to show save dialog
            while true {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds

                // Check if transcription is complete
                if let completedTask = transcriptionVM.completedTasks.first(where: { $0.audioFileURL == fileURL }) {
                    switch completedTask.status {
                    case .completed:
                        print("🎉 Transcription completed")

                        // Check temp location for transcription
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempOutputURL = tempDir.appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + ".txt")

                        if let text = try? String(contentsOf: tempOutputURL, encoding: .utf8) {
                            print("✅ Read text from temp location")
                            await MainActor.run {
                                self.showSaveDialog(text: text, originalFileName: fileURL.lastPathComponent)
                                transcriptionResult = text
                                fileAddedToQueue = false
                            }
                        } else {
                            // Fallback: try original location
                            let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                            if let text = try? String(contentsOf: outputURL, encoding: .utf8) {
                                print("✅ Read text from original location")
                                await MainActor.run {
                                    self.showSaveDialog(text: text, originalFileName: fileURL.lastPathComponent)
                                    transcriptionResult = text
                                    fileAddedToQueue = false
                                }
                            }
                        }
                        return // Exit monitoring

                    case .failed(let error):
                        await MainActor.run {
                            errorMessage = error
                            fileAddedToQueue = false
                        }
                        return // Exit monitoring

                    default:
                        break
                    }
                }
            }
        }
    }

    private func cancelTranscription() {
        guard let fileURL = selectedFileURL else { return }

        // Remove file from queue/processing through the view model
        transcriptionVM.removeFileFromProcessing(fileURL)

        // Reset local state
        fileAddedToQueue = false
        errorMessage = NSLocalizedString("Transskription afbrudt", comment: "Transcription cancelled")
    }

    private func showSaveDialog(text: String, originalFileName: String) {
        print("[SAVEPROBLEM] 🔔 showSaveDialog called")
        print("[SAVEPROBLEM]    Original filename: \(originalFileName)")
        print("[SAVEPROBLEM]    Text length: \(text.count)")
        print("[SAVEPROBLEM]    Thread: \(Thread.current)")
        print("[SAVEPROBLEM]    Is main thread: \(Thread.isMainThread)")

        // Generate suggested filename from audio file name
        let baseName = (originalFileName as NSString).deletingPathExtension
        let suggestedFilename = "\(baseName).txt"
        print("[SAVEPROBLEM]    Suggested filename: \(suggestedFilename)")

        saveTranscriptionAs(text: text, suggestedFilename: suggestedFilename)
        print("[SAVEPROBLEM] 🔔 saveTranscriptionAs returned")
    }

    private func saveTranscriptionAs(text: String, suggestedFilename: String) {
        print("[SAVEPROBLEM] 💾 saveTranscriptionAs: Creating NSSavePanel")
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.prompt = NSLocalizedString("Gem", comment: "")
        savePanel.message = NSLocalizedString("Vælg hvor transskriptionen skal gemmes", comment: "")

        print("[SAVEPROBLEM] 💾 saveTranscriptionAs: Calling savePanel.runModal()")
        let response = savePanel.runModal()
        print("[SAVEPROBLEM] 💾 Save panel returned: response = \(response == .OK ? "OK" : "Cancel")")

        guard response == .OK, let url = savePanel.url else {
            print("[SAVEPROBLEM] 💾 User cancelled or no URL selected")
            return
        }

        print("[SAVEPROBLEM] 💾 User selected: \(url.path)")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            print("[SAVEPROBLEM] ✅ Saved transcription to: \(url.path)")

            // Show success feedback
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            print("[SAVEPROBLEM] ❌ Failed to save transcription: \(error)")
            self.errorMessage = NSLocalizedString("Kunne ikke gemme fil: ", comment: "") + error.localizedDescription
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            // Check if it's an audio file
            if FileSystemHelper.shared.isAudioFile(url) {
                DispatchQueue.main.async {
                    selectedFileURL = url
                    transcriptionResult = nil
                    errorMessage = nil
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Helper views for async operations
struct FileInfoView: View {
    let fileURL: URL
    @State private var duration: TimeInterval?

    var body: some View {
        Group {
            if let duration = duration {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(String(format: NSLocalizedString("Varighed: %@", comment: ""), formatDuration(duration)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            duration = await AudioFileService.shared.getAudioDuration(fileURL)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct EstimatedTimeView: View {
    let fileURL: URL
    @State private var duration: TimeInterval?

    var body: some View {
        Group {
            if let duration = duration {
                Text(String(format: NSLocalizedString("Estimeret tid: ~%llds", comment: ""), Int(duration / 10)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            duration = await AudioFileService.shared.getAudioDuration(fileURL)
        }
    }
}

#Preview {
    ManualTranscriptionView()
        .environmentObject(TranscriptionViewModel.shared)
}
