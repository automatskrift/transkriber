//
//  TranscriptionsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionsView: View {
    // Use @ObservedObject for singletons to avoid AttributeGraph cycles
    @ObservedObject private var viewModel = TranscriptionsViewModel.shared
    @State private var showingSortMenu = false
    @State private var showingFilterMenu = false
    @State private var showingExportMenu = false
    @State private var selectedRecord: TranscriptionRecord?

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and controls
            headerView

            Divider()

            // Main content
            if viewModel.isLoading {
                ProgressView(NSLocalizedString("Loading transcriptions...", comment: "Loading transcriptions message"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTranscriptions.isEmpty {
                emptyState
            } else {
                transcriptionsList
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(item: $selectedRecord) { record in
            TranscriptionDetailView(record: record)
        }
        .task {
            await viewModel.loadTranscriptions()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(NSLocalizedString("Search transcriptions...", comment: "Search placeholder"), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        Task {
                            await viewModel.loadTranscriptions()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            // Sort button
            Menu {
                ForEach(TranscriptionDatabase.SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        Task {
                            await viewModel.setSortOption(option)
                        }
                    }) {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(NSLocalizedString("Sort", comment: "Sort button"), systemImage: "arrow.up.arrow.down")
                    .frame(minWidth: 80)
            }
            .menuStyle(.borderlessButton)

            // Filter button
            Menu {
                // Source filter
                Menu(NSLocalizedString("Source", comment: "Source filter")) {
                    Button(NSLocalizedString("All", comment: "All sources")) {
                        viewModel.filterSource = nil
                        viewModel.applyFilters()
                    }
                    Divider()
                    ForEach(viewModel.getSources(), id: \.self) { source in
                        Button(sourceDisplayName(source)) {
                            viewModel.filterSource = source
                            viewModel.applyFilters()
                        }
                    }
                }

                // Language filter
                if !viewModel.getUniqueLanguages().isEmpty {
                    Menu(NSLocalizedString("Language", comment: "Language filter")) {
                        Button(NSLocalizedString("All", comment: "All languages")) {
                            viewModel.filterLanguage = nil
                            viewModel.applyFilters()
                        }
                        Divider()
                        ForEach(viewModel.getUniqueLanguages(), id: \.self) { language in
                            Button(language) {
                                viewModel.filterLanguage = language
                                viewModel.applyFilters()
                            }
                        }
                    }
                }

                // Model filter
                if !viewModel.getUniqueModels().isEmpty {
                    Menu(NSLocalizedString("Model", comment: "Model filter")) {
                        Button(NSLocalizedString("All", comment: "All models")) {
                            viewModel.filterModel = nil
                            viewModel.applyFilters()
                        }
                        Divider()
                        ForEach(viewModel.getUniqueModels(), id: \.self) { model in
                            Button(model.capitalized) {
                                viewModel.filterModel = model
                                viewModel.applyFilters()
                            }
                        }
                    }
                }

                Divider()

                Button(NSLocalizedString("Clear Filters", comment: "Clear filters")) {
                    viewModel.clearFilters()
                }
                .disabled(viewModel.filterSource == nil && viewModel.filterLanguage == nil && viewModel.filterModel == nil)
            } label: {
                Label(NSLocalizedString("Filter", comment: "Filter button"), systemImage: "line.3.horizontal.decrease.circle")
                    .frame(minWidth: 80)
            }
            .menuStyle(.borderlessButton)

            // Export button
            Menu {
                Button(action: exportCSV) {
                    Label(NSLocalizedString("Export as CSV", comment: "Export as CSV option"), systemImage: "tablecells")
                }
                Button(action: exportJSON) {
                    Label(NSLocalizedString("Export as JSON", comment: "Export as JSON option"), systemImage: "curlybraces")
                }
            } label: {
                Label(NSLocalizedString("Export", comment: "Export button"), systemImage: "square.and.arrow.up")
                    .frame(minWidth: 80)
            }
            .menuStyle(.borderlessButton)
            .disabled(viewModel.filteredTranscriptions.isEmpty)
        }
        .padding()
    }

    // MARK: - Transcriptions List

    private var transcriptionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredTranscriptions) { record in
                    DatabaseTranscriptionRow(
                        record: record,
                        isSelected: viewModel.selectedTranscriptions.contains(record.id),
                        onSelect: {
                            if viewModel.selectedTranscriptions.contains(record.id) {
                                viewModel.selectedTranscriptions.remove(record.id)
                            } else {
                                viewModel.selectedTranscriptions.insert(record.id)
                            }
                        },
                        onView: {
                            selectedRecord = record
                        },
                        onDelete: {
                            Task {
                                await viewModel.deleteTranscription(record)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(viewModel.searchText.isEmpty ?
                NSLocalizedString("No transcriptions yet", comment: "Empty state") :
                NSLocalizedString("No results found", comment: "No search results"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(viewModel.searchText.isEmpty ?
                NSLocalizedString("When you transcribe files, they will appear here", comment: "Empty state description") :
                NSLocalizedString("Try searching for something else", comment: "No results description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if viewModel.filterSource != nil || viewModel.filterLanguage != nil || viewModel.filterModel != nil {
                Button(NSLocalizedString("Clear Filters", comment: "Clear filters")) {
                    viewModel.clearFilters()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Functions

    private func sourceDisplayName(_ source: String) -> String {
        switch source {
        case "manual": return NSLocalizedString("Manual", comment: "Manual source")
        case "folder": return NSLocalizedString("Folder", comment: "Folder source")
        case "icloud": return "iCloud"
        default: return source
        }
    }

    private func exportCSV() {
        let csv = viewModel.exportToCSV()
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "transcriptions_\(Date().timeIntervalSince1970).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                print("✅ Exported CSV to: \(url.path)")
            } catch {
                print("❌ Failed to export CSV: \(error)")
            }
        }
    }

    private func exportJSON() {
        do {
            let jsonData = try viewModel.exportToJSON()
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "transcriptions_\(Date().timeIntervalSince1970).json"
            savePanel.allowedContentTypes = [.json]

            if savePanel.runModal() == .OK, let url = savePanel.url {
                try jsonData.write(to: url)
                print("✅ Exported JSON to: \(url.path)")
            }
        } catch {
            print("❌ Failed to export JSON: \(error)")
        }
    }
}

// MARK: - Database Transcription Row

struct DatabaseTranscriptionRow: View {
    let record: TranscriptionRecord
    let isSelected: Bool
    let onSelect: () -> Void
    let onView: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Selection checkbox
                    Button(action: onSelect) {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Icon based on source
                    Image(systemName: record.sourceIcon)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.audioFileName)
                            .font(.headline)

                        HStack(spacing: 8) {
                            Text(record.transcribedAt.timeAgoString())
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if record.iCloudSynced {
                                Image(systemName: "icloud.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            if !record.tagArray.isEmpty {
                                ForEach(record.tagArray.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Metadata
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(record.formattedDuration, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("\(record.wordCount) words", systemImage: "textformat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Actions
                    HStack(spacing: 8) {
                        Button(action: onView) {
                            Label(NSLocalizedString("View", comment: "View button"), systemImage: "eye")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.transcriptionText, forType: .string)
                        }) {
                            Label(NSLocalizedString("Copy", comment: "Copy button"), systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)

                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label(NSLocalizedString("Delete", comment: "Delete button"), systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }

                // Expandable transcription preview
                if isExpanded {
                    Divider()

                    ScrollView {
                        Text(record.transcriptionText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }

                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Label(
                        isExpanded ? NSLocalizedString("Show less", comment: "Collapse") : NSLocalizedString("Show preview", comment: "Expand"),
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
        }
        .confirmationDialog(
            NSLocalizedString("Delete Transcription?", comment: "Delete confirmation"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(NSLocalizedString("Delete", comment: "Delete"), role: .destructive) {
                onDelete()
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("This will remove the transcription from the database. The original files will not be deleted.", comment: "Delete message"))
        }
    }
}

// MARK: - Transcription Detail View

struct TranscriptionDetailView: View {
    let record: TranscriptionRecord
    @Environment(\.dismiss) var dismiss
    @State private var notes: String = ""
    @State private var tagText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.audioFileName)
                        .font(.headline)

                    HStack {
                        Text(String(format: NSLocalizedString("%d words • %@ • %@", comment: "Details"),
                                  record.wordCount,
                                  record.formattedDuration,
                                  record.modelUsed.capitalized))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Copy button
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.transcriptionText, forType: .string)
                }) {
                    Label(NSLocalizedString("Copy", comment: "Copy"), systemImage: "doc.on.doc")
                }

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Transcription text
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Transcription", comment: "Transcription header"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(record.transcriptionText)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Details", comment: "Details header"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            DetailRow(label: NSLocalizedString("Source", comment: "Source"), value: record.sourceDisplayName)
                            DetailRow(label: NSLocalizedString("Model", comment: "Model"), value: record.modelUsed.capitalized)
                            DetailRow(label: NSLocalizedString("Language", comment: "Language"), value: record.language ?? "Auto")
                            DetailRow(label: NSLocalizedString("Duration", comment: "Duration"), value: record.formattedDuration)
                            DetailRow(label: NSLocalizedString("Created", comment: "Created"), value: record.createdAt.formatted())
                            DetailRow(label: NSLocalizedString("Transcribed", comment: "Transcribed"), value: record.transcribedAt.formatted())
                        }
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Tags", comment: "Tags"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        TextField(NSLocalizedString("Add tags (comma separated)", comment: "Tags placeholder"), text: $tagText)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                tagText = record.tags ?? ""
                            }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Notes", comment: "Notes"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .onAppear {
                                notes = record.notes ?? ""
                            }
                    }
                }
                .padding()
            }

            // Save button
            HStack {
                Spacer()
                Button(NSLocalizedString("Save Changes", comment: "Save button")) {
                    Task {
                        let tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        await TranscriptionsViewModel.shared.updateTags(for: record, tags: tags)
                        await TranscriptionsViewModel.shared.updateNotes(for: record, notes: notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

#Preview {
    TranscriptionsView()
}