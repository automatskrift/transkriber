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
    @State private var isTranscribing = false
    @State private var transcriptionProgress: Double = 0.0
    @State private var transcriptionResult: String?
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var showTranscriptionExistsAlert = false
    @State private var showIgnoredFileAlert = false

    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @EnvironmentObject private var whisperService: WhisperService

    // Computed properties to avoid AttributeGraph cycles
    private var isFileInQueue: Bool {
        guard let fileURL = selectedFileURL else { return false }
        return transcriptionVM.isInQueue(fileURL)
    }

    private var isFileActive: Bool {
        guard let fileURL = selectedFileURL else { return false }
        return transcriptionVM.activeTasks.contains(where: { $0.audioFileURL == fileURL })
    }

    // Get the actual progress from transcriptionVM for the selected file
    private var actualTranscriptionProgress: Double {
        guard let fileURL = selectedFileURL else { return 0.0 }

        // Find the active task for this file
        if let task = transcriptionVM.activeTasks.first(where: { $0.audioFileURL == fileURL }) {
            if case .processing(let progress) = task.status {
                return progress
            }
        }

        return transcriptionProgress
    }

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

                            if selectedFileURL != nil && !isTranscribing {
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
                                .disabled(isTranscribing)
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

                // Model Loading Progress (combines download + initialization)
                if whisperService.isDownloadingModel {
                    GroupBox(label: Label(NSLocalizedString("Indlæser WhisperKit model", comment: ""), systemImage: "arrow.down.circle.fill")) {
                        VStack(spacing: 12) {
                            if let modelName = whisperService.downloadingModelName {
                                Text(modelName)
                                    .font(.headline)
                            }

                            ProgressView()
                                .progressViewStyle(.linear)

                            Text(NSLocalizedString("Dette kan tage flere minutter første gang", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Progress
                if isTranscribing {
                    if isFileInQueue && !isFileActive {
                        // File is waiting in queue
                        GroupBox(label: Label(NSLocalizedString("Venter i kø...", comment: "Waiting in transcription queue"), systemImage: "clock")) {
                            VStack(spacing: 12) {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.linear)
                                        .scaleEffect(x: 1, y: 0.5, anchor: .center)

                                    Spacer()
                                }

                                Text(NSLocalizedString("Venter på at andre transskriptioner bliver færdige", comment: "Waiting for other transcriptions"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Cancel button for queued tasks
                                Button(action: cancelTranscription) {
                                    Label(NSLocalizedString("Annuller", comment: "Cancel transcription"), systemImage: "xmark.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // File is being transcribed
                        GroupBox(label: Label(NSLocalizedString("Transkriberer...", comment: ""), systemImage: "waveform.circle")) {
                            VStack(spacing: 12) {
                                // Real-time transcription preview
                                if !whisperService.currentTranscribingText.isEmpty {
                                    HStack {
                                        Text(whisperService.currentTranscribingText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }

                                ProgressView(value: actualTranscriptionProgress)
                                    .progressViewStyle(.linear)

                                HStack {
                                    Text("\(Int(actualTranscriptionProgress * 100))%")
                                        .font(.headline)
                                        .foregroundColor(.accentColor)

                                    Spacer()

                                    if let fileURL = selectedFileURL {
                                        EstimatedTimeView(fileURL: fileURL)
                                    }
                                }

                                // Cancel button for active transcription
                                Button(action: cancelTranscription) {
                                    Label(NSLocalizedString("Stop Transskription", comment: "Stop transcription"), systemImage: "stop.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .padding(.vertical, 8)
                        }
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
                if selectedFileURL == nil && !isTranscribing {
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
        transcriptionProgress = 0.0
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

        print("🚀 proceedWithTranscription called for: \(fileURL.lastPathComponent)")

        isTranscribing = true
        transcriptionProgress = 0.0
        transcriptionResult = nil
        errorMessage = nil

        print("   isTranscribing = true, progress = 0.0")

        Task {
            print("   📝 Calling addToQueue...")
            // Add to the shared transcription queue to ensure serialized processing
            await transcriptionVM.addToQueue(fileURL)
            print("   ✅ addToQueue returned")

            // Monitor the task progress
            while isTranscribing {
                // Check if this file is being processed
                if let activeTask = transcriptionVM.activeTasks.first(where: { $0.audioFileURL == fileURL }) {
                    switch activeTask.status {
                    case .processing(let progress):
                        await MainActor.run {
                            transcriptionProgress = progress
                        }
                    case .completed:
                        // Transcription completed successfully
                        print("[SAVEPROBLEM] 🎉 ManualTranscriptionView: Task completed in activeTasks!")

                        // First check temp location (where it's saved due to sandboxing)
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempOutputURL = tempDir.appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + ".txt")

                        print("[SAVEPROBLEM] 📂 Checking temp location: \(tempOutputURL.path)")
                        print("[SAVEPROBLEM] 📂 File exists at temp location: \(FileManager.default.fileExists(atPath: tempOutputURL.path))")

                        if let text = try? String(contentsOf: tempOutputURL, encoding: .utf8) {
                            print("[SAVEPROBLEM] ✅ Successfully read text from temp location (\(text.count) chars)")

                            // Show save dialog BEFORE setting isTranscribing = false
                            // This prevents the while loop from exiting before the dialog is shown
                            print("[SAVEPROBLEM] 💾 Showing save dialog...")
                            await MainActor.run {
                                self.showSaveDialog(text: text, originalFileName: fileURL.lastPathComponent)
                            }
                            print("[SAVEPROBLEM] 💾 Save dialog shown")

                            // Now update UI state
                            await MainActor.run {
                                transcriptionResult = text
                                isTranscribing = false  // This will exit the while loop
                            }
                        } else {
                            print("[SAVEPROBLEM] ⚠️ Could not read from temp location, trying original location")
                            // Fallback: try original location
                            let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                            print("[SAVEPROBLEM] 📂 Checking original location: \(outputURL.path)")

                            if let text = try? String(contentsOf: outputURL, encoding: .utf8) {
                                print("[SAVEPROBLEM] ✅ Successfully read text from original location (\(text.count) chars)")

                                // Show save dialog BEFORE setting isTranscribing = false
                                print("[SAVEPROBLEM] 💾 Showing save dialog for original location...")
                                await MainActor.run {
                                    self.showSaveDialog(text: text, originalFileName: fileURL.lastPathComponent)
                                }
                                print("[SAVEPROBLEM] 💾 Save dialog shown")

                                // Now update UI state
                                await MainActor.run {
                                    transcriptionResult = text
                                    isTranscribing = false  // This will exit the while loop
                                }
                            } else {
                                print("[SAVEPROBLEM] ❌ Could not read text from either location!")
                                await MainActor.run {
                                    isTranscribing = false
                                }
                            }
                        }
                    case .failed(let error):
                        // Transcription failed
                        await MainActor.run {
                            errorMessage = error
                            isTranscribing = false
                            transcriptionProgress = 0.0
                        }
                    default:
                        break
                    }
                } else {
                    // Check if it's in the completed tasks (finished before we started monitoring)
                    if let completedTask = transcriptionVM.completedTasks.first(where: { $0.audioFileURL == fileURL }) {
                        print("[SAVEPROBLEM] 📋 Found in completedTasks with status: \(completedTask.status)")
                        switch completedTask.status {
                        case .completed:
                            print("[SAVEPROBLEM] 🎉 ManualTranscriptionView: Task found in completedTasks!")

                            // First check temp location
                            let tempDir = FileManager.default.temporaryDirectory
                            let tempOutputURL = tempDir.appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + ".txt")

                            print("[SAVEPROBLEM] 📂 Checking temp location: \(tempOutputURL.path)")

                            if let text = try? String(contentsOf: tempOutputURL, encoding: .utf8) {
                                print("[SAVEPROBLEM] ✅ Successfully read text from temp location (\(text.count) chars)")

                                // Show save dialog BEFORE setting isTranscribing = false
                                print("[SAVEPROBLEM] 💾 Showing save dialog (from completedTasks)...")
                                await MainActor.run {
                                    self.showSaveDialog(text: text, originalFileName: fileURL.lastPathComponent)
                                }
                                print("[SAVEPROBLEM] 💾 Save dialog shown")

                                // Now update UI state
                                await MainActor.run {
                                    transcriptionResult = text
                                    isTranscribing = false
                                }
                            } else {
                                // Fallback: try original location
                                let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                                print("[SAVEPROBLEM] 📂 Checking original location: \(outputURL.path)")

                                if let text = try? String(contentsOf: outputURL, encoding: .utf8) {
                                    print("[SAVEPROBLEM] ✅ Successfully read text from original location (\(text.count) chars)")

                                    // Show save dialog
                                    print("[SAVEPROBLEM] 💾 Showing save dialog for original location (from completedTasks)...")
                                    await MainActor.run {
                                        self.showSaveDialog(text: text, originalFileName: fileURL.lastPathComponent)
                                    }
                                    print("[SAVEPROBLEM] 💾 Save dialog shown")

                                    await MainActor.run {
                                        transcriptionResult = text
                                        isTranscribing = false
                                    }
                                } else {
                                    print("[SAVEPROBLEM] ❌ Could not read text from either location (completedTasks)!")
                                    await MainActor.run {
                                        isTranscribing = false
                                    }
                                }
                            }
                        case .failed(let error):
                            await MainActor.run {
                                errorMessage = error
                                isTranscribing = false
                                transcriptionProgress = 0.0
                            }
                        default:
                            break
                        }
                    }
                }

                // Small delay before checking again
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }

    private func cancelTranscription() {
        guard selectedFileURL != nil else { return }

        // Cancel the transcription through the view model
        transcriptionVM.cancelCurrentTranscription()

        // Reset local state
        isTranscribing = false
        transcriptionProgress = 0.0
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
