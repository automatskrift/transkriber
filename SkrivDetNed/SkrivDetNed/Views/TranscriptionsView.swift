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

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Søg i transskriptioner...", text: $searchText)
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

            // Content
            if filteredTasks.isEmpty {
                emptyState
            } else {
                transcriptionsList
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private var filteredTasks: [TranscriptionTask] {
        let completed = transcriptionVM.completedTasks.filter { $0.status == .completed }

        if searchText.isEmpty {
            return completed
        }

        return completed.filter { task in
            task.fileName.localizedCaseInsensitiveContains(searchText) ||
            (loadTranscriptionText(for: task)?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func loadTranscriptionText(for task: TranscriptionTask) -> String? {
        guard FileManager.default.fileExists(atPath: task.outputFileURL.path) else {
            return nil
        }
        return try? String(contentsOf: task.outputFileURL, encoding: .utf8)
    }

    private var transcriptionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredTasks) { task in
                    TranscriptionRow(task: task)
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

            Text(searchText.isEmpty ? "Ingen transskriptioner endnu" : "Ingen resultater")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                 "Når du transskriberer filer, vil de dukke op her" :
                 "Prøv at søge efter noget andet")
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
                                Label("Vis tekst", systemImage: "doc.text.magnifyingglass")
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
                                Label("Kopier", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        // Open transcription file button
                        if FileManager.default.fileExists(atPath: task.outputFileURL.path) {
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([task.outputFileURL])
                            }) {
                                Label("Vis fil", systemImage: "folder")
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
                                Label(isExpanded ? "Vis mindre" : "Vis mere", systemImage: isExpanded ? "chevron.up" : "chevron.down")
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
                        Label("Varighed: \(Int(duration))s", systemImage: "clock")

                        Spacer()

                        if let transcription = transcriptionText {
                            Label("\(transcription.split(separator: " ").count) ord", systemImage: "textformat")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(8)
        }
        .onAppear {
            loadTranscription()
        }
        .sheet(isPresented: $showingTextWindow) {
            if let text = transcriptionText {
                TranscriptionTextWindow(text: text, fileName: task.fileName)
            }
        }
    }

    private func loadTranscription() {
        guard FileManager.default.fileExists(atPath: task.outputFileURL.path) else {
            return
        }
        transcriptionText = try? String(contentsOf: task.outputFileURL, encoding: .utf8)
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
                    Text("\(text.split(separator: " ").count) ord")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    Label("Kopier", systemImage: "doc.on.doc")
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
