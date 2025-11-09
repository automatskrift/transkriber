//
//  TranscriptionsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct TranscriptionsView: View {
    @State private var recordings: [Recording] = []
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if filteredRecordings.isEmpty {
                    if searchText.isEmpty {
                        emptyState
                    } else {
                        searchEmptyState
                    }
                } else {
                    transcriptionsList
                }
            }
            .navigationTitle(NSLocalizedString("Transskriptioner", comment: ""))
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: NSLocalizedString("Søg i transskriptioner", comment: "")
            )
            .onAppear {
                loadRecordings()
            }
            .refreshable {
                loadRecordings()
            }
        }
    }

    private var transcribedRecordings: [Recording] {
        recordings.filter { $0.hasTranscription || $0.transcriptionText != nil }
    }

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty {
            return transcribedRecordings
        }

        let lowercasedSearch = searchText.lowercased()
        return transcribedRecordings.filter { recording in
            // Search in title
            if recording.title.lowercased().contains(lowercasedSearch) {
                return true
            }

            // Search in transcription text
            if let transcription = recording.transcriptionText,
               transcription.lowercased().contains(lowercasedSearch) {
                return true
            }

            // Search in tags
            if recording.tags.contains(where: { $0.lowercased().contains(lowercasedSearch) }) {
                return true
            }

            // Search in notes
            if let notes = recording.notes,
               notes.lowercased().contains(lowercasedSearch) {
                return true
            }

            return false
        }
    }

    private var transcriptionsList: some View {
        List {
            ForEach(filteredRecordings) { recording in
                NavigationLink(destination: RecordingDetailView(recording: recording)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(recording.title)
                                .font(.headline)

                            Spacer()

                            Image(systemName: recording.cloudStatus.icon)
                                .foregroundColor(statusColor(for: recording))
                                .font(.caption)
                        }

                        if let transcription = recording.transcriptionText {
                            Text(highlightedText(transcription))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }

                        HStack {
                            Label(recording.formattedDate, systemImage: "clock")
                            Spacer()
                            Label(recording.formattedDuration, systemImage: "waveform")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("Ingen transskriptioner endnu", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Dine optagelser vil automatisk blive transskriberet når de uploades til iCloud", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var searchEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("Ingen resultater", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Prøv at søge efter noget andet", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private func loadRecordings() {
        let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings")

        guard FileManager.default.fileExists(atPath: recordingsDir.path) else {
            recordings = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            recordings = jsonFiles.compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let recording = try? decoder.decode(Recording.self, from: data) else {
                    return nil
                }
                return recording
            }
            .sorted { $0.createdAt > $1.createdAt }

        } catch {
            print("❌ Failed to load recordings: \(error)")
            recordings = []
        }
    }

    private func statusColor(for recording: Recording) -> Color {
        switch recording.cloudStatus.color {
        case "gray": return .gray
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }

    private func highlightedText(_ text: String) -> String {
        guard !searchText.isEmpty else { return text }

        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()

        // Find first occurrence of search text
        guard let range = lowercasedText.range(of: lowercasedSearch) else {
            return text
        }

        // Get context around the match (50 chars before and after)
        let contextLength = 50
        let startIndex = text.index(
            range.lowerBound,
            offsetBy: -contextLength,
            limitedBy: text.startIndex
        ) ?? text.startIndex

        let endIndex = text.index(
            range.upperBound,
            offsetBy: contextLength,
            limitedBy: text.endIndex
        ) ?? text.endIndex

        var result = String(text[startIndex..<endIndex])

        // Add ellipsis if needed
        if startIndex != text.startIndex {
            result = "..." + result
        }
        if endIndex != text.endIndex {
            result = result + "..."
        }

        return result
    }
}

#Preview {
    TranscriptionsView()
}
