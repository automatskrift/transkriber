//
//  SearchView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Recording] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    emptyState
                } else if searchResults.isEmpty && !isSearching {
                    noResultsState
                } else {
                    searchResultsList
                }
            }
            .navigationTitle(NSLocalizedString("Søg", comment: ""))
            .searchable(text: $searchText, prompt: NSLocalizedString("Søg i optagelser og transskriptioner", comment: ""))
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("Søg i dine optagelser", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Find optagelser baseret på titel, tags, noter eller transskriptionstekst", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var noResultsState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("Ingen resultater", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("Prøv at søge efter noget andet", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { recording in
                NavigationLink(destination: RecordingDetailView(recording: recording)) {
                    RecordingRow(recording: recording)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        // TODO: Implement actual search
        // For now, load all recordings and filter
        Task {
            let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Recordings")

            guard FileManager.default.fileExists(atPath: recordingsDir.path) else {
                isSearching = false
                searchResults = []
                return
            }

            do {
                let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
                let jsonFiles = files.filter { $0.pathExtension == "json" }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let allRecordings = jsonFiles.compactMap { url -> Recording? in
                    guard let data = try? Data(contentsOf: url),
                          let recording = try? decoder.decode(Recording.self, from: data) else {
                        return nil
                    }
                    return recording
                }

                // Filter based on query
                let lowercasedQuery = query.lowercased()
                searchResults = allRecordings.filter { recording in
                    recording.title.lowercased().contains(lowercasedQuery) ||
                    recording.tags.contains { $0.lowercased().contains(lowercasedQuery) } ||
                    (recording.notes?.lowercased().contains(lowercasedQuery) ?? false) ||
                    (recording.transcriptionText?.lowercased().contains(lowercasedQuery) ?? false)
                }

                isSearching = false

            } catch {
                print("❌ Search error: \(error)")
                isSearching = false
                searchResults = []
            }
        }
    }
}

#Preview {
    SearchView()
}
