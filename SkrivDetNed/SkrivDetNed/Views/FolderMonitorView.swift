//
//  FolderMonitorView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct FolderMonitorView: View {
    @EnvironmentObject private var viewModel: FolderMonitorViewModel
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @EnvironmentObject private var whisperService: WhisperService

    // Computed property to avoid AttributeGraph cycle
    private var processingTasks: [TranscriptionTask] {
        transcriptionVM.activeTasks.filter { task in
            if case .processing = task.status {
                return true
            }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Active Transcription Section
                // Only show tasks that are actively processing, not pending ones
                if whisperService.isDownloadingModel || whisperService.isLoadingModel || !processingTasks.isEmpty {
                    GroupBox(label: Label(NSLocalizedString("Aktuel opgave", comment: "Current task"), systemImage: "waveform.circle")) {
                        VStack(spacing: 16) {
                            // Model downloading banner
                            if whisperService.isDownloadingModel {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.blue)
                                            .imageScale(.large)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(NSLocalizedString("Downloader WhisperKit model", comment: ""))
                                                .font(.headline)

                                            if let modelName = whisperService.downloadingModelName {
                                                Text(modelName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            // Show percentage progress if available
                                            if whisperService.downloadProgress > 0 {
                                                Text(String(format: NSLocalizedString("Download: %d%%", comment: "Download progress percentage"), Int(whisperService.downloadProgress * 100)))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        ProgressView(value: whisperService.downloadProgress)
                                            .frame(width: 60)
                                    }
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // Model loading banner
                            if whisperService.isLoadingModel {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "cpu")
                                            .foregroundColor(.orange)
                                            .imageScale(.large)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(NSLocalizedString("Indlæser WhisperKit model", comment: ""))
                                                .font(.headline)

                                            if let modelName = whisperService.downloadingModelName {
                                                Text(modelName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Text(NSLocalizedString("Indlæser model i hukommelsen...", comment: ""))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        ProgressView()
                                            .frame(width: 60)
                                    }
                                }
                                .padding(12)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // Currently transcribing (only show tasks that are actually processing)
                            if !processingTasks.isEmpty {
                                ForEach(processingTasks) { task in
                                    TranscriptionTaskRow(task: task)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Divider()
                        .padding(.vertical, 8)
                }

                // MARK: - Pending Queue Section
                // Show ALL pending files from all sources (Manual, Folder Monitor, iCloud)
                if !transcriptionVM.pendingQueue.isEmpty {
                    GroupBox(label: Label(NSLocalizedString("Pending Files", comment: "Pending files section"), systemImage: "clock")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(String(format: NSLocalizedString("In Queue (%lld)", comment: "Queue count"), transcriptionVM.pendingQueue.count))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(NSLocalizedString("These files are waiting for transcription", comment: "Pending queue description"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            // Use the simpler reorderable queue view
                            SimpleReorderableQueueView()
                                .environmentObject(transcriptionVM)
                        }
                        .padding(.vertical, 8)
                    }

                    Divider()
                        .padding(.vertical, 8)
                }

                // MARK: - iCloud Section
                GroupBox(label:
                    HStack {
                        Label(NSLocalizedString("iCloud Optagelser", comment: ""), systemImage: "icloud")
                        Spacer()
                        Button(action: {
                            if let recordingsURL = iCloudSyncService.shared.getRecordingsFolderURL() {
                                NSWorkspace.shared.activateFileViewerSelecting([recordingsURL])
                            }
                        }) {
                            Label(NSLocalizedString("Åbn folder", comment: ""), systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                ) {
                    VStack(spacing: 16) {

                        // Queued files
                        if !viewModel.iCloudQueuedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: NSLocalizedString("I Kø (%lld)", comment: ""), viewModel.iCloudQueuedFiles.count))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.iCloudQueuedFiles, id: \.url) { item in
                                            iCloudFileCard(url: item.url, metadata: item.metadata, status: .queued)
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                            }
                            Divider()
                        }

                        // Completed files
                        if !viewModel.iCloudCompletedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: NSLocalizedString("Færdige (%lld)", comment: ""), viewModel.iCloudCompletedFiles.count))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.iCloudCompletedFiles, id: \.url) { item in
                                            iCloudFileCard(url: item.url, metadata: item.metadata, status: .completed)
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                            }
                            Divider()
                        }

                        // Failed files
                        if !viewModel.iCloudFailedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: NSLocalizedString("Fejlede (%lld)", comment: ""), viewModel.iCloudFailedFiles.count))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.iCloudFailedFiles, id: \.url) { item in
                                            iCloudFileCard(url: item.url, metadata: item.metadata, status: .failed)
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
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
                                Text(NSLocalizedString("Ingen filer i iCloud", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - iCloud File Card
    @ViewBuilder
    private func iCloudFileCard(url: URL, metadata: RecordingMetadata, status: FileCardStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // First line: Icon + filename + buttons
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .imageScale(.small)

                Text(metadata.title ?? url.deletingPathExtension().lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

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
                            Label(NSLocalizedString("Transkribér igen", comment: ""), systemImage: "arrow.clockwise")
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
                            Label(NSLocalizedString("Start nu", comment: ""), systemImage: "play.fill")
                        }

                        Button(role: .destructive, action: {
                            // Ignore file
                            viewModel.ignorePendingFile(url)
                        }) {
                            Label(NSLocalizedString("Ignorer", comment: ""), systemImage: "xmark.circle")
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
                            Label(NSLocalizedString("Retry", comment: ""), systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive, action: {
                            // Ignore file
                            viewModel.ignorePendingFile(url)
                        }) {
                            Label(NSLocalizedString("Ignorer", comment: ""), systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            // Second line: Duration and time ago on same line
            HStack(spacing: 4) {
                if let duration = metadata.duration {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(metadata.createdAt.timeAgoString())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Third line: Error message (if failed)
            if status == .failed, let error = metadata.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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


// MARK: - Pending File Card (Simple version for unified queue)
struct PendingFileCard: View {
    let fileURL: URL
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // First line: Icon + filename + source + remove button
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundColor(.orange)
                    .imageScale(.small)

                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                // Source indicator
                if let source = getFileSource() {
                    Text(source)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }

                // Remove button
                Button(action: {
                    transcriptionVM.removeFileFromProcessing(fileURL)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("Remove from queue", comment: "Remove from queue tooltip"))
            }

            // Second line: Status
            Text(NSLocalizedString("Waiting...", comment: "Pending file status"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragging ? Color.accentColor : Color.orange.opacity(0.3), lineWidth: isDragging ? 2 : 1)
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        // Removed onDrag here - it's now handled by SimpleReorderableQueueView
    }

    private func getFileSource() -> String? {
        // Determine source based on file path
        if let iCloudFolder = iCloudSyncService.shared.getRecordingsFolderURL(),
           fileURL.path.hasPrefix(iCloudFolder.path) {
            return "iCloud"
        } else if let monitoredFolder = FolderMonitorService.shared.monitoredFolder,
                  fileURL.path.hasPrefix(monitoredFolder.path) {
            return NSLocalizedString("Folder", comment: "Folder source badge")
        } else {
            return NSLocalizedString("Manual", comment: "Manual source badge")
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
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("Remove from queue", comment: "Remove file from queue tooltip"))
            }

            Text(fileURL.lastPathComponent)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            Text(NSLocalizedString("Venter...", comment: ""))
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
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @EnvironmentObject private var whisperService: WhisperService

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

                    // Cancel button for active transcription
                    Button(action: {
                        transcriptionVM.cancelCurrentTranscription()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .help(NSLocalizedString("Stop transskription", comment: "Stop transcription"))
                }
            }

            // Real-time transcription preview
            if case .processing = task.status, !whisperService.currentTranscribingText.isEmpty {
                Text(whisperService.currentTranscribingText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
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

    @State private var audioFileExists = false
    @State private var metadataJSON = ""
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("Metadata Info", comment: ""))
                    .font(.headline)
                Spacer()
                Button(action: {
                    copyToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("Kopier til udklipsholder", comment: ""))
                .disabled(metadataJSON.isEmpty)
            }

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // File existence status
                HStack {
                    Image(systemName: audioFileExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(audioFileExists ? .green : .red)
                    Text(audioFileExists ? NSLocalizedString("Lydfil findes", comment: "") : NSLocalizedString("Lydfil findes IKKE", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.bottom, 4)

                if audioFileExists {
                    Text(String(format: NSLocalizedString("Sti: %@", comment: ""), url.path))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }

                Divider()

                ScrollView {
                    if metadata != nil && !metadataJSON.isEmpty {
                        Text(metadataJSON)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("Ingen JSON-fil fundet", comment: ""))
                                .font(.headline)
                            Text(String(format: NSLocalizedString("Filen: %@", comment: ""), url.lastPathComponent))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .frame(width: 400, height: 300)
            }
        }
        .padding()
        .task {
            // Load data asynchronously
            await loadMetadataInfo()
        }
    }

    private func loadMetadataInfo() async {
        // Run in background to avoid blocking UI
        await Task.detached(priority: .userInitiated) {
            // Check file existence
            let exists = FileManager.default.fileExists(atPath: url.path)

            // Generate JSON string
            // Encode metadata on main actor
            let jsonString: String
            if let metadataValue = metadata {
                jsonString = await MainActor.run {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                    if let data = try? encoder.encode(metadataValue),
                       let json = String(data: data, encoding: .utf8) {
                        return json
                    }
                    return ""
                }
            } else {
                jsonString = ""
            }

            // Update UI on main actor
            await MainActor.run {
                audioFileExists = exists
                metadataJSON = jsonString
                isLoading = false
            }
        }.value
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(metadataJSON, forType: .string)
    }
}

#Preview {
    MainActor.assumeIsolated {
        FolderMonitorView()
            .environmentObject(FolderMonitorViewModel.shared)
            .environmentObject(TranscriptionViewModel.shared)
            .environmentObject(WhisperService.shared)
    }
}
