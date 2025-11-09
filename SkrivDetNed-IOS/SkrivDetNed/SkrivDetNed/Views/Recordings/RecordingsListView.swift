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
    @State private var searchText = ""
    @Environment(\.scenePhase) private var scenePhase

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
                    recordingsList
                }
            }
            .navigationTitle(NSLocalizedString("Optagelser", comment: ""))
            .searchable(text: $searchText, prompt: NSLocalizedString("Søg i optagelser...", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker(NSLocalizedString("Sorter efter", comment: ""), selection: $viewModel.sortOrder) {
                            Label(NSLocalizedString("Nyeste først", comment: ""), systemImage: "arrow.down").tag(SortOrder.newestFirst)
                            Label(NSLocalizedString("Ældste først", comment: ""), systemImage: "arrow.up").tag(SortOrder.oldestFirst)
                            Label(NSLocalizedString("Navn", comment: ""), systemImage: "textformat").tag(SortOrder.name)
                            Label(NSLocalizedString("Størrelse", comment: ""), systemImage: "arrow.up.arrow.down").tag(SortOrder.size)
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
            .alert(NSLocalizedString("Slet optagelse", comment: ""), isPresented: $showingDeleteAlert, presenting: recordingToDelete) { recording in
                Button(NSLocalizedString("Slet", comment: ""), role: .destructive) {
                    viewModel.deleteRecording(recording)
                }
                Button(NSLocalizedString("Annuller", comment: ""), role: .cancel) {}
            } message: { recording in
                Text(String(format: NSLocalizedString("Er du sikker på du vil slette '%@'?", comment: ""), recording.title))
            }
            .sheet(item: $recordingToShare) { recording in
                ShareSheet(recording: recording)
            }
        }
    }

    private var filteredRecordings: [Recording] {
        if searchText.isEmpty {
            return viewModel.recordings
        }

        return viewModel.recordings.filter { recording in
            recording.title.localizedCaseInsensitiveContains(searchText) ||
            recording.fileName.localizedCaseInsensitiveContains(searchText) ||
            (recording.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            recording.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
            (recording.transcriptionText?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(filteredRecordings) { recording in
                NavigationLink(destination: RecordingDetailView(recording: recording)) {
                    RecordingRow(recording: recording)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        recordingToDelete = recording
                        showingDeleteAlert = true
                    } label: {
                        Label(NSLocalizedString("Slet", comment: ""), systemImage: "trash")
                    }

                    Button {
                        recordingToShare = recording
                    } label: {
                        Label(NSLocalizedString("Del", comment: ""), systemImage: "square.and.arrow.up")
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

            Text(NSLocalizedString("Ingen optagelser endnu", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Gå til Optag-fanen for at lave din første optagelse", comment: ""))
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
