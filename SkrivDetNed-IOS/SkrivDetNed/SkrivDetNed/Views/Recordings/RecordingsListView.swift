//
//  RecordingsListView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct RecordingsListView: View {
    @StateObject private var viewModel = RecordingsListViewModel()
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: Recording?
    @State private var recordingToShare: Recording?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }
            .navigationTitle("Optagelser")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sorter efter", selection: $viewModel.sortOrder) {
                            Label("Nyeste først", systemImage: "arrow.down").tag(SortOrder.newestFirst)
                            Label("Ældste først", systemImage: "arrow.up").tag(SortOrder.oldestFirst)
                            Label("Navn", systemImage: "textformat").tag(SortOrder.name)
                            Label("Størrelse", systemImage: "arrow.up.arrow.down").tag(SortOrder.size)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                // Reload recordings when view appears (e.g., after app restart)
                viewModel.loadRecordings()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Reload when app becomes active (e.g., returning from background)
                    viewModel.loadRecordings()
                }
            }
            .alert("Slet optagelse", isPresented: $showingDeleteAlert, presenting: recordingToDelete) { recording in
                Button("Slet", role: .destructive) {
                    viewModel.deleteRecording(recording)
                }
                Button("Annuller", role: .cancel) {}
            } message: { recording in
                Text("Er du sikker på du vil slette '\(recording.title)'?")
            }
            .sheet(item: $recordingToShare) { recording in
                ShareSheet(recording: recording)
            }
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(viewModel.recordings) { recording in
                NavigationLink(destination: RecordingDetailView(recording: recording)) {
                    RecordingRow(recording: recording)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    } label: {
                        Label("Slet", systemImage: "trash")
                    }

                    Button {
                        recordingToShare = recording
                    } label: {
                        Label("Del", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("Ingen optagelser endnu")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Gå til Optag-fanen for at lave din første optagelse")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let recording: Recording

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create array of items to share
        var itemsToShare: [Any] = []

        // Add audio file if it exists
        if FileManager.default.fileExists(atPath: recording.localURL.path) {
            itemsToShare.append(recording.localURL)
        }

        // Add transcription text if available
        if let transcription = recording.transcriptionText, !transcription.isEmpty {
            itemsToShare.append(transcription)
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    RecordingsListView()
}
