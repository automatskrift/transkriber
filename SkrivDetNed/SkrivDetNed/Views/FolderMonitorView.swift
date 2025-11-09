//
//  FolderMonitorView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct FolderMonitorView: View {
    @ObservedObject private var viewModel = FolderMonitorViewModel.shared
    @ObservedObject private var transcriptionVM = TranscriptionViewModel.shared
    @ObservedObject private var whisperService = WhisperService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Overvåget Folder Section
                GroupBox(label: Label("Overvåget Folder", systemImage: "folder")) {
                    VStack(spacing: 12) {
                        HStack {
                            if let folderURL = viewModel.selectedFolderURL {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folderURL.lastPathComponent)
                                        .font(.headline)
                                    Text(folderURL.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            } else {
                                Text("Ingen folder valgt")
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: viewModel.selectFolder) {
                                Label("Vælg Folder", systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Status
                        HStack {
                            Label {
                                Text("Status:")
                                    .foregroundColor(.secondary)
                            } icon: {
                                Circle()
                                    .fill(viewModel.statusColor)
                                    .frame(width: 8, height: 8)
                            }

                            Text(viewModel.statusText)
                                .fontWeight(.medium)

                            Spacer()

                            // Toggle monitoring button
                            if viewModel.selectedFolderURL != nil {
                                Button(action: viewModel.toggleMonitoring) {
                                    Text(viewModel.isMonitoring ? "Stop Overvågning" : "Start Overvågning")
                                        .frame(minWidth: 140)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(viewModel.isMonitoring ? .red : .green)
                            }
                        }

                        // Pending Files from local folder
                        if !viewModel.pendingFiles.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("I Kø (\(viewModel.pendingFiles.count))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: viewModel.clearPendingQueue) {
                                        Label("Ryd kø", systemImage: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.red)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.pendingFiles, id: \.self) { fileURL in
                                            LocalPendingFileCard(fileURL: fileURL, viewModel: viewModel)
                                        }
                                    }
                                }
                                .frame(height: 80)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Divider
                Divider()
                    .padding(.vertical, 8)

                // MARK: - iCloud Section
                GroupBox(label:
                    HStack {
                        Label("iCloud Optagelser", systemImage: "icloud")
                        Spacer()
                        Button(action: {
                            if let recordingsURL = iCloudSyncService.shared.getRecordingsFolderURL() {
                                NSWorkspace.shared.activateFileViewerSelecting([recordingsURL])
                            }
                        }) {
                            Label("Åbn folder", systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                ) {
                    VStack(spacing: 16) {
                        // Model downloading banner
                        if whisperService.isDownloadingModel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.blue)
                                        .imageScale(.large)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Downloader WhisperKit model")
                                            .font(.headline)

                                        if let modelName = whisperService.downloadingModelName {
                                            Text(modelName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if whisperService.downloadProgress > 0 {
                                        Text("\(Int(whisperService.downloadProgress * 100))%")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                }

                                ProgressView(value: whisperService.downloadProgress)
                                    .progressViewStyle(.linear)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)

                            Divider()
                        }

                        // Currently transcribing
                        if !transcriptionVM.activeTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Under Transkribering")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ForEach(transcriptionVM.activeTasks) { task in
                                    TranscriptionTaskRow(task: task)
                                }
                            }
                            Divider()
                        }

                        // Queued files
                        if !viewModel.iCloudQueuedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("I Kø (\(viewModel.iCloudQueuedFiles.count))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.iCloudQueuedFiles, id: \.url) { item in
                                            iCloudFileCard(url: item.url, metadata: item.metadata, status: .queued)
                                        }
                                    }
                                }
                                .frame(height: 100)
                            }
                            Divider()
                        }

                        // Completed files
                        if !viewModel.iCloudCompletedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Færdige (\(viewModel.iCloudCompletedFiles.count))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.iCloudCompletedFiles, id: \.url) { item in
                                            iCloudFileCard(url: item.url, metadata: item.metadata, status: .completed)
                                        }
                                    }
                                }
                                .frame(height: 100)
                            }
                            Divider()
                        }

                        // Failed files
                        if !viewModel.iCloudFailedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fejlede (\(viewModel.iCloudFailedFiles.count))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.iCloudFailedFiles, id: \.url) { item in
                                            iCloudFileCard(url: item.url, metadata: item.metadata, status: .failed)
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                        }

                        // Empty state for iCloud
                        if transcriptionVM.activeTasks.isEmpty &&
                           viewModel.iCloudQueuedFiles.isEmpty &&
                           viewModel.iCloudCompletedFiles.isEmpty &&
                           viewModel.iCloudFailedFiles.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "icloud")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Ingen filer i iCloud")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Empty State
                if viewModel.selectedFolderURL == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Vælg en folder for at komme i gang")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Appen vil automatisk overvåge folderen og transkribere nye lydfiler")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                if viewModel.selectedFolderURL != nil && !viewModel.isMonitoring &&
                   transcriptionVM.activeTasks.isEmpty &&
                   viewModel.pendingFiles.isEmpty &&
                   viewModel.iCloudQueuedFiles.isEmpty &&
                   viewModel.iCloudCompletedFiles.isEmpty &&
                   viewModel.iCloudFailedFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Klar til at starte")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Tryk 'Start Overvågning' for at begynde at overvåge folderen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - iCloud File Card
    @ViewBuilder
    private func iCloudFileCard(url: URL, metadata: RecordingMetadata, status: FileCardStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .imageScale(.medium)

                Spacer()

                // Info button (always visible)
                MetadataInfoButton(url: url, metadata: metadata)

                if status == .completed {
                    Button(action: {
                        let txtURL = url.deletingPathExtension().appendingPathExtension("txt")
                        if FileManager.default.fileExists(atPath: txtURL.path) {
                            NSWorkspace.shared.activateFileViewerSelecting([txtURL])
                        }
                    }) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Menu {
                        Button(action: {
                            Task {
                                // Redo transcription - update metadata to pending
                                if let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
                                    do {
                                        var updatedMetadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder)
                                            ?? RecordingMetadata(audioFileName: url.lastPathComponent, createdOnDevice: "macOS")

                                        // Clear error and reset to pending
                                        updatedMetadata.status = .pending
                                        updatedMetadata.errorMessage = nil
                                        updatedMetadata.lastAttemptedAt = nil
                                        updatedMetadata.transcriptionFileName = nil
                                        updatedMetadata.updatedAt = Date()

                                        try updatedMetadata.save(to: recordingsFolder)
                                        print("🔄 Reset completed file to pending for redo: \(url.lastPathComponent)")

                                        // Remove from processed files list so it can be retried
                                        FolderMonitorService.shared.removeFromProcessed(url)
                                        print("🔄 Removed from processed files list")

                                        // Delete old transcription file if exists
                                        let txtURL = url.deletingPathExtension().appendingPathExtension("txt")
                                        if FileManager.default.fileExists(atPath: txtURL.path) {
                                            try? FileManager.default.removeItem(at: txtURL)
                                            print("🗑️ Deleted old transcription file")
                                        }

                                        // Now add to queue
                                        await transcriptionVM.addToQueue(url)

                                        // Trigger immediate refresh to update UI
                                        await viewModel.refreshiCloudFileLists()
                                    } catch {
                                        print("❌ Failed to reset metadata for redo: \(error)")
                                    }
                                }
                            }
                        }) {
                            Label("Transcrriber igen", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                if status == .queued {
                    Menu {
                        Button(action: {
                            Task {
                                // Force start transcription
                                await transcriptionVM.addToQueue(url)
                            }
                        }) {
                            Label("Start nu", systemImage: "play.fill")
                        }

                        Button(role: .destructive, action: {
                            // Ignore file
                            viewModel.ignorePendingFile(url)
                        }) {
                            Label("Ignorer", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                if status == .failed {
                    Menu {
                        Button(action: {
                            Task {
                                // Retry transcription - first update metadata to pending
                                if let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
                                    do {
                                        var updatedMetadata = try RecordingMetadata.load(for: url.lastPathComponent, from: recordingsFolder)
                                            ?? RecordingMetadata(audioFileName: url.lastPathComponent, createdOnDevice: "macOS")

                                        // Clear error and reset to pending
                                        updatedMetadata.status = .pending
                                        updatedMetadata.errorMessage = nil
                                        updatedMetadata.lastAttemptedAt = nil
                                        updatedMetadata.updatedAt = Date()

                                        try updatedMetadata.save(to: recordingsFolder)
                                        print("🔄 Reset failed file to pending for retry: \(url.lastPathComponent)")

                                        // Remove from processed files list so it can be retried
                                        FolderMonitorService.shared.removeFromProcessed(url)
                                        print("🔄 Removed from processed files list")

                                        // Now add to queue
                                        await transcriptionVM.addToQueue(url)

                                        // Trigger immediate refresh to update UI
                                        await viewModel.refreshiCloudFileLists()
                                    } catch {
                                        print("❌ Failed to reset metadata for retry: \(error)")
                                    }
                                }
                            }
                        }) {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive, action: {
                            // Ignore file
                            viewModel.ignorePendingFile(url)
                        }) {
                            Label("Ignorer", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            Text(metadata.title ?? url.deletingPathExtension().lastPathComponent)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if let duration = metadata.duration {
                Text(formatDuration(duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if status == .failed, let error = metadata.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            Text(metadata.createdAt.timeAgoString())
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    enum FileCardStatus {
        case queued, completed, failed

        var icon: String {
            switch self {
            case .queued: return "clock"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .queued: return .orange
            case .completed: return .green
            case .failed: return .red
            }
        }
    }
}

// MARK: - Local Pending File Card
struct LocalPendingFileCard: View {
    let fileURL: URL
    let viewModel: FolderMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.orange)
                    .imageScale(.small)

                Spacer()

                // Info button - check if there's iCloud metadata for this file
                MetadataInfoButton(url: fileURL, metadata: getMetadata())

                Button(action: {
                    viewModel.ignorePendingFile(fileURL)
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Text(fileURL.lastPathComponent)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            Text("Venter...")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(width: 140)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func getMetadata() -> RecordingMetadata? {
        // Try to load metadata if this is an iCloud file
        guard let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() else {
            return nil
        }

        return try? RecordingMetadata.load(for: fileURL.lastPathComponent, from: recordingsFolder)
    }
}

// MARK: - Transcription Task Row
struct TranscriptionTaskRow: View {
    let task: TranscriptionTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.fileName)
                        .font(.headline)

                    Text("→ \(task.outputFileURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if case .processing(let progress) = task.status {
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
            }

            // Progress bar
            if case .processing(let progress) = task.status {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Metadata Info Button
struct MetadataInfoButton: View {
    let url: URL
    let metadata: RecordingMetadata?
    @State private var showingInfo = false

    init(url: URL, metadata: RecordingMetadata?) {
        self.url = url
        self.metadata = metadata
    }

    var body: some View {
        Button(action: {
            showingInfo = true
        }) {
            Image(systemName: "info.circle")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showingInfo, arrowEdge: .bottom) {
            MetadataInfoView(url: url, metadata: metadata)
        }
    }
}

struct MetadataInfoView: View {
    let url: URL
    let metadata: RecordingMetadata?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Metadata Info")
                    .font(.headline)
                Spacer()
                Button(action: {
                    copyToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Kopier til udklipsholder")
            }

            Divider()

            // File existence status
            HStack {
                Image(systemName: audioFileExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(audioFileExists ? .green : .red)
                Text(audioFileExists ? "Lydfil findes" : "Lydfil findes IKKE")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.bottom, 4)

            if audioFileExists {
                Text("Sti: \(url.path)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            Divider()

            ScrollView {
                if let metadata = metadata {
                    Text(metadataJSON)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Ingen JSON-fil fundet")
                            .font(.headline)
                        Text("Filen: \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .frame(width: 400, height: 300)
        }
        .padding()
    }

    private var audioFileExists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private var metadataJSON: String {
        guard let metadataValue = metadata else {
            return "Ingen metadata"
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(metadataValue),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "Kunne ikke encode metadata"
        }

        return jsonString
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(metadataJSON, forType: .string)
    }
}

#Preview {
    FolderMonitorView()
}
