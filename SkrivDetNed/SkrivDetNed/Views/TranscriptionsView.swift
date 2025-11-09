//
//  TranscriptionsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import SwiftUI

struct TranscriptionsView: View {
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @State private var searchText = ""
    @State private var filteredTasks: [TranscriptionTask] = []
    @State private var isActive = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(NSLocalizedString("Søg i transskriptioner...", comment: ""), text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()

            Divider()

            // Content - only show if view is active
            if isActive {
                if filteredTasks.isEmpty {
                    emptyState
                } else {
                    transcriptionsList
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onChange(of: searchText) {
            if isActive {
                updateFilteredTasks()
            }
        }
        .onChange(of: transcriptionVM.completedTasks.count) {
            if isActive {
                updateFilteredTasks()
            }
        }
        .onAppear {
            // Delay to ensure smooth transition
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                isActive = true
                updateFilteredTasks()
            }
        }
        .onDisappear {
            isActive = false
        }
    }

    private func updateFilteredTasks() {
        // Perform filtering asynchronously to avoid blocking UI
        Task { @MainActor in
            let completed = transcriptionVM.completedTasks.filter { $0.status == .completed }

            if searchText.isEmpty {
                filteredTasks = completed
            } else {
                // Only filter by filename to avoid loading all transcription files
                // Users can open individual transcriptions to search content
                filteredTasks = completed.filter { task in
                    task.fileName.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }

    private var transcriptionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredTasks) { task in
                    TranscriptionRow(task: task)
                        .id(task.id) // Ensure stable identity
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? NSLocalizedString("Ingen transskriptioner endnu", comment: "") : NSLocalizedString("Ingen resultater", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                 NSLocalizedString("Når du transskriberer filer, vil de dukke op her", comment: "") :
                 NSLocalizedString("Prøv at søge efter noget andet", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct TranscriptionRow: View {
    let task: TranscriptionTask
    @State private var transcriptionText: String?
    @State private var isExpanded = false
    @State private var showingTextWindow = false
    @State private var fileExists = false
    @State private var hasLoaded = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.fileName)
                            .font(.headline)

                        if let completedAt = task.completedAt {
                            Text(completedAt.timeAgoString())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Actions
                    HStack(spacing: 8) {
                        // Show text in window button
                        if transcriptionText != nil {
                            Button(action: {
                                showingTextWindow = true
                            }) {
                                Label(NSLocalizedString("Vis tekst", comment: ""), systemImage: "doc.text.magnifyingglass")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        // Copy text button
                        if let transcription = transcriptionText {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(transcription, forType: .string)
                            }) {
                                Label(NSLocalizedString("Kopier", comment: ""), systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        // Open transcription file button
                        if fileExists {
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([task.outputFileURL])
                            }) {
                                Label(NSLocalizedString("Vis fil", comment: ""), systemImage: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                // Transcription preview
                if let transcription = transcriptionText {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        if isExpanded {
                            ScrollView {
                                Text(transcription)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 300)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        } else {
                            Text(transcription)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(5)
                                .textSelection(.enabled)
                        }

                        // Show expand/collapse button if text is long
                        if transcription.count > 200 {
                            Button(action: { isExpanded.toggle() }) {
                                Label(isExpanded ? NSLocalizedString("Vis mindre", comment: "") : NSLocalizedString("Vis mere", comment: ""), systemImage: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                // Metadata
                if let duration = task.duration {
                    Divider()

                    HStack {
                        Label(String(format: NSLocalizedString("Varighed: %llds", comment: ""), Int(duration)), systemImage: "clock")

                        Spacer()

                        if let transcription = transcriptionText {
                            Label(String(format: NSLocalizedString("%lld ord", comment: ""), transcription.split(separator: " ").count), systemImage: "textformat")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
        .task(id: task.id) {
            // Only load once per task
            guard !hasLoaded else { return }

            // Don't block - run everything in background
            await Task.detached(priority: .background) {
                // Mark as loaded immediately to prevent duplicate loads
                await MainActor.run { hasLoaded = true }

                // Check if file exists
                let exists = FileManager.default.fileExists(atPath: task.outputFileURL.path)

                await MainActor.run {
                    fileExists = exists
                }

                guard exists, !Task.isCancelled else { return }

                // Load file content
                guard let text = try? String(contentsOf: task.outputFileURL, encoding: .utf8),
                      !Task.isCancelled else { return }

                await MainActor.run {
                    transcriptionText = text
                }
            }.value
        }
        .sheet(isPresented: $showingTextWindow) {
            if let text = transcriptionText {
                TranscriptionTextWindow(text: text, fileName: task.fileName)
            }
        }
    }
}

struct TranscriptionTextWindow: View {
    let text: String
    let fileName: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName)
                        .font(.headline)
                    Text(String(format: NSLocalizedString("%lld ord", comment: ""), text.split(separator: " ").count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    Label(NSLocalizedString("Kopier", comment: ""), systemImage: "doc.on.doc")
                }

                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable text content
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500)
    }
}

#Preview {
    TranscriptionsView()
        .environmentObject(TranscriptionViewModel.shared)
}
