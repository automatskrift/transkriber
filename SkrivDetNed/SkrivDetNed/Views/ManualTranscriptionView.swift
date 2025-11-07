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

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var transcriptionVM = TranscriptionViewModel.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // File Selection
                GroupBox(label: Label("Vælg Lydfil", systemImage: "doc")) {
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
                                if let duration = AudioFileService.shared.getAudioDuration(fileURL) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.secondary)
                                        Text("Varighed: \(formatDuration(duration))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)

                            // Output file
                            HStack {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                Text("Output:")
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

                                Text("Ingen fil valgt")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text("Vælg en lydfil til transskription")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }

                        // Buttons
                        HStack {
                            Button(action: selectFile) {
                                Label("Vælg Fil", systemImage: "folder")
                                    .frame(minWidth: 120)
                            }
                            .buttonStyle(.bordered)

                            if selectedFileURL != nil && !isTranscribing {
                                Button(action: clearSelection) {
                                    Label("Ryd", systemImage: "xmark")
                                }
                                .buttonStyle(.bordered)
                            }

                            Spacer()

                            if selectedFileURL != nil {
                                Button(action: startTranscription) {
                                    Label("Transkribér", systemImage: "play.fill")
                                        .frame(minWidth: 120)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isTranscribing || !hasModelDownloaded)
                            }
                        }

                        // Warning if no model downloaded
                        if !hasModelDownloaded {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Download en Whisper model i Indstillinger først")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Progress
                if isTranscribing {
                    GroupBox(label: Label("Transkriberer...", systemImage: "waveform.circle")) {
                        VStack(spacing: 12) {
                            ProgressView(value: transcriptionProgress)
                                .progressViewStyle(.linear)

                            HStack {
                                Text("\(Int(transcriptionProgress * 100))%")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)

                                Spacer()

                                if let fileURL = selectedFileURL,
                                   let duration = AudioFileService.shared.getAudioDuration(fileURL) {
                                    Text("Estimeret tid: ~\(Int(duration / 10))s")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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
                    GroupBox(label: Label("Færdig!", systemImage: "checkmark.circle.fill")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transskriptionen er gemt")
                                .font(.headline)

                            if let fileURL = selectedFileURL {
                                let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")

                                HStack {
                                    Text("Gemt til:")
                                        .foregroundColor(.secondary)
                                    Text(outputURL.lastPathComponent)
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)

                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                                }) {
                                    Label("Vis i Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
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

                        Text("Eller træk en lydfil hertil")
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
    }

    private var hasModelDownloaded: Bool {
        FileSystemHelper.shared.modelExists(settings.selectedModelType)
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
        panel.prompt = "Vælg Lydfil"
        panel.message = "Vælg en lydfil til transskription"

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

        isTranscribing = true
        transcriptionProgress = 0.0
        transcriptionResult = nil
        errorMessage = nil

        Task {
            do {
                let modelType = settings.selectedModelType
                let transcription = try await WhisperService.shared.transcribe(
                    audioURL: fileURL,
                    modelType: modelType
                ) { progress in
                    Task { @MainActor in
                        transcriptionProgress = progress
                    }
                }

                // Save to file
                let outputURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                try transcription.write(to: outputURL, atomically: true, encoding: .utf8)

                transcriptionResult = transcription
                isTranscribing = false

            } catch {
                errorMessage = error.localizedDescription
                isTranscribing = false
                transcriptionProgress = 0.0
            }
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

#Preview {
    ManualTranscriptionView()
}
