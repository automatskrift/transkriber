//
//  TranscriptionsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct TranscriptionsView: View {
    @State private var recordings: [Recording] = []

    var body: some View {
        NavigationStack {
            Group {
                if transcribedRecordings.isEmpty {
                    emptyState
                } else {
                    transcriptionsList
                }
            }
            .navigationTitle("Transskriptioner")
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

    private var transcriptionsList: some View {
        List {
            ForEach(transcribedRecordings) { recording in
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
                            Text(transcription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
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

            Text("Ingen transskriptioner endnu")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Dine optagelser vil automatisk blive transskriberet når de uploades til iCloud")
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
}

#Preview {
    TranscriptionsView()
}
