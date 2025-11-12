//
//  TranscriptionsViewModel.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TranscriptionsViewModel: ObservableObject {
    static let shared = TranscriptionsViewModel()

    @Published var transcriptions: [TranscriptionRecord] = []
    @Published var filteredTranscriptions: [TranscriptionRecord] = []
    @Published var searchText = ""
    @Published var sortOption: TranscriptionDatabase.SortOption = .dateDescending
    @Published var filterSource: String? = nil
    @Published var filterLanguage: String? = nil
    @Published var filterModel: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var selectedTranscriptions: Set<UUID> = []

    private let database = TranscriptionDatabase.shared

    private init() {
        // Auto-load when initialized
        Task {
            await loadTranscriptions()
        }
    }

    // MARK: - Data Loading

    func loadTranscriptions() async {
        isLoading = true
        errorMessage = nil

        do {
            let records = try await database.fetchSorted(by: sortOption)
            transcriptions = records
            applyFilters()
            print("📚 Loaded \(records.count) transcriptions from database")
        } catch {
            errorMessage = "Failed to load transcriptions: \(error.localizedDescription)"
            print("❌ Failed to load transcriptions: \(error)")
        }

        isLoading = false
    }

    // MARK: - Search & Filter

    func search() async {
        guard !searchText.isEmpty else {
            await loadTranscriptions()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let results = try await database.search(query: searchText)
            transcriptions = results
            applyFilters()
            print("🔍 Found \(results.count) transcriptions matching '\(searchText)'")
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            print("❌ Search failed: \(error)")
        }

        isLoading = false
    }

    func applyFilters() {
        var filtered = transcriptions

        // Apply source filter
        if let source = filterSource {
            filtered = filtered.filter { $0.source == source }
        }

        // Apply language filter
        if let language = filterLanguage {
            filtered = filtered.filter { $0.language == language }
        }

        // Apply model filter
        if let model = filterModel {
            filtered = filtered.filter { $0.modelUsed == model }
        }

        filteredTranscriptions = filtered
    }

    func clearFilters() {
        filterSource = nil
        filterLanguage = nil
        filterModel = nil
        applyFilters()
    }

    // MARK: - Sorting

    func setSortOption(_ option: TranscriptionDatabase.SortOption) async {
        sortOption = option
        await loadTranscriptions()
    }

    // MARK: - Actions

    func deleteTranscription(_ record: TranscriptionRecord) async {
        do {
            try await database.delete(id: record.id)

            // Remove from local arrays
            transcriptions.removeAll { $0.id == record.id }
            filteredTranscriptions.removeAll { $0.id == record.id }

            print("🗑️ Deleted transcription: \(record.audioFileName)")
        } catch {
            errorMessage = "Failed to delete transcription: \(error.localizedDescription)"
            print("❌ Failed to delete: \(error)")
        }
    }

    func deleteSelected() async {
        guard !selectedTranscriptions.isEmpty else { return }

        do {
            try await database.deleteMultiple(ids: Array(selectedTranscriptions))

            // Remove from local arrays
            transcriptions.removeAll { selectedTranscriptions.contains($0.id) }
            filteredTranscriptions.removeAll { selectedTranscriptions.contains($0.id) }

            print("🗑️ Deleted \(selectedTranscriptions.count) transcriptions")
            selectedTranscriptions.removeAll()
        } catch {
            errorMessage = "Failed to delete transcriptions: \(error.localizedDescription)"
            print("❌ Failed to delete: \(error)")
        }
    }

    func updateNotes(for record: TranscriptionRecord, notes: String?) async {
        do {
            try await database.updateNotes(id: record.id, notes: notes)

            // Update local record
            if let index = transcriptions.firstIndex(where: { $0.id == record.id }) {
                transcriptions[index].notes = notes
            }
            if let index = filteredTranscriptions.firstIndex(where: { $0.id == record.id }) {
                filteredTranscriptions[index].notes = notes
            }

            print("📝 Updated notes for: \(record.audioFileName)")
        } catch {
            errorMessage = "Failed to update notes: \(error.localizedDescription)"
            print("❌ Failed to update notes: \(error)")
        }
    }

    func updateTags(for record: TranscriptionRecord, tags: [String]) async {
        do {
            try await database.updateTags(id: record.id, tags: tags)

            // Update local record
            let tagString = tags.joined(separator: ", ")
            if let index = transcriptions.firstIndex(where: { $0.id == record.id }) {
                transcriptions[index].tags = tagString
            }
            if let index = filteredTranscriptions.firstIndex(where: { $0.id == record.id }) {
                filteredTranscriptions[index].tags = tagString
            }

            print("🏷️ Updated tags for: \(record.audioFileName)")
        } catch {
            errorMessage = "Failed to update tags: \(error.localizedDescription)"
            print("❌ Failed to update tags: \(error)")
        }
    }

    // MARK: - Export

    func exportToCSV() -> String {
        var csv = "Audio File,Transcribed At,Duration,Words,Model,Language,Source\n"

        for record in filteredTranscriptions {
            let row = "\"\(record.audioFileName)\",\"\(record.transcribedAt)\",\(record.duration),\(record.wordCount),\(record.modelUsed),\(record.language ?? ""),\(record.source)\n"
            csv += row
        }

        return csv
    }

    func exportToJSON() throws -> Data {
        struct ExportRecord: Codable {
            let audioFileName: String
            let transcriptionText: String
            let transcribedAt: Date
            let duration: Double
            let wordCount: Int32
            let modelUsed: String
            let language: String?
            let source: String
            let tags: [String]
            let notes: String?
        }

        let exportRecords = filteredTranscriptions.map { record in
            ExportRecord(
                audioFileName: record.audioFileName,
                transcriptionText: record.transcriptionText,
                transcribedAt: record.transcribedAt,
                duration: record.duration,
                wordCount: record.wordCount,
                modelUsed: record.modelUsed,
                language: record.language,
                source: record.source,
                tags: record.tagArray,
                notes: record.notes
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportRecords)
    }

    // MARK: - Statistics

    func getStatistics() async -> TranscriptionStatistics? {
        do {
            return try await database.getStatistics()
        } catch {
            print("❌ Failed to get statistics: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    func getUniqueLanguages() -> [String] {
        let languages = transcriptions.compactMap { $0.language }
        return Array(Set(languages)).sorted()
    }

    func getUniqueModels() -> [String] {
        let models = transcriptions.map { $0.modelUsed }
        return Array(Set(models)).sorted()
    }

    func getSources() -> [String] {
        return ["manual", "folder", "icloud"]
    }
}