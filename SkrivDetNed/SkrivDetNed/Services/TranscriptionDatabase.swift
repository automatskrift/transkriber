//
//  TranscriptionDatabase.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class TranscriptionDatabase: ObservableObject {
    static let shared = TranscriptionDatabase()
    private let persistenceController = PersistenceController.shared

    private init() {}

    // MARK: - Save Transcription

    func saveTranscription(
        audioFileName: String,
        audioFilePath: String,
        transcriptionText: String,
        transcriptionFilePath: String?,
        source: String,
        createdAt: Date = Date(),
        transcribedAt: Date = Date(),
        duration: Double = 0,
        modelUsed: String,
        language: String?,
        iCloudSynced: Bool = false,
        marks: [Double]? = nil
    ) async throws {
        let context = persistenceController.container.viewContext

        // Check if record already exists (by audio file path)
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "audioFilePath == %@", audioFilePath)

        let existingRecords = try context.fetch(fetchRequest)

        let record: TranscriptionRecord
        if let existing = existingRecords.first {
            // Update existing record
            print("📝 Updating existing transcription record for: \(audioFileName)")
            record = existing
        } else {
            // Create new record
            print("📝 Creating new transcription record for: \(audioFileName)")
            record = TranscriptionRecord(context: context)
            record.id = UUID()
        }

        // Set/update properties
        record.audioFileName = audioFileName
        record.audioFilePath = audioFilePath
        record.transcriptionText = transcriptionText
        record.transcriptionFilePath = transcriptionFilePath
        record.source = source
        record.createdAt = createdAt
        record.transcribedAt = transcribedAt
        record.duration = duration
        record.wordCount = Int32(transcriptionText.split(separator: " ").count)
        record.modelUsed = modelUsed
        record.language = language
        record.iCloudSynced = iCloudSynced

        // Convert marks array to JSON data
        if let marks = marks {
            record.marksData = try? JSONEncoder().encode(marks)
        }

        // Save context
        try context.save()
        print("💾 Transcription saved to database: \(audioFileName)")
    }

    // MARK: - Fetch Operations

    func fetchAll() async throws -> [TranscriptionRecord] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "transcribedAt", ascending: false)]

        return try context.fetch(fetchRequest)
    }

    func fetchRecent(limit: Int = 50) async throws -> [TranscriptionRecord] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "transcribedAt", ascending: false)]
        fetchRequest.fetchLimit = limit

        return try context.fetch(fetchRequest)
    }

    // MARK: - Search

    func search(query: String) async throws -> [TranscriptionRecord] {
        guard !query.isEmpty else {
            return try await fetchAll()
        }

        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()

        // Search in both filename and transcription text
        let fileNamePredicate = NSPredicate(format: "audioFileName CONTAINS[cd] %@", query)
        let textPredicate = NSPredicate(format: "transcriptionText CONTAINS[cd] %@", query)
        let tagsPredicate = NSPredicate(format: "tags CONTAINS[cd] %@", query)

        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            fileNamePredicate,
            textPredicate,
            tagsPredicate
        ])

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "transcribedAt", ascending: false)]

        return try context.fetch(fetchRequest)
    }

    // MARK: - Sorting

    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case durationDescending = "Longest First"
        case durationAscending = "Shortest First"
        case wordCountDescending = "Most Words"
        case wordCountAscending = "Fewest Words"

        var displayName: String {
            switch self {
            case .dateDescending: return NSLocalizedString("Newest First", comment: "Sort option")
            case .dateAscending: return NSLocalizedString("Oldest First", comment: "Sort option")
            case .nameAscending: return NSLocalizedString("Name (A-Z)", comment: "Sort option")
            case .nameDescending: return NSLocalizedString("Name (Z-A)", comment: "Sort option")
            case .durationDescending: return NSLocalizedString("Longest First", comment: "Sort option")
            case .durationAscending: return NSLocalizedString("Shortest First", comment: "Sort option")
            case .wordCountDescending: return NSLocalizedString("Most Words", comment: "Sort option")
            case .wordCountAscending: return NSLocalizedString("Fewest Words", comment: "Sort option")
            }
        }
    }

    func fetchSorted(by option: SortOption, searchQuery: String? = nil) async throws -> [TranscriptionRecord] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()

        // Apply search filter if provided
        if let query = searchQuery, !query.isEmpty {
            let fileNamePredicate = NSPredicate(format: "audioFileName CONTAINS[cd] %@", query)
            let textPredicate = NSPredicate(format: "transcriptionText CONTAINS[cd] %@", query)
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [fileNamePredicate, textPredicate])
        }

        // Apply sorting
        switch option {
        case .dateDescending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "transcribedAt", ascending: false)]
        case .dateAscending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "transcribedAt", ascending: true)]
        case .nameAscending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "audioFileName", ascending: true)]
        case .nameDescending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "audioFileName", ascending: false)]
        case .durationDescending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
        case .durationAscending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: true)]
        case .wordCountDescending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "wordCount", ascending: false)]
        case .wordCountAscending:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "wordCount", ascending: true)]
        }

        return try context.fetch(fetchRequest)
    }

    // MARK: - Filtering

    func fetchFiltered(
        source: String? = nil,
        language: String? = nil,
        modelUsed: String? = nil,
        iCloudOnly: Bool = false
    ) async throws -> [TranscriptionRecord] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()

        var predicates: [NSPredicate] = []

        if let source = source {
            predicates.append(NSPredicate(format: "source == %@", source))
        }

        if let language = language {
            predicates.append(NSPredicate(format: "language == %@", language))
        }

        if let modelUsed = modelUsed {
            predicates.append(NSPredicate(format: "modelUsed == %@", modelUsed))
        }

        if iCloudOnly {
            predicates.append(NSPredicate(format: "iCloudSynced == YES"))
        }

        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "transcribedAt", ascending: false)]

        return try context.fetch(fetchRequest)
    }

    // MARK: - Delete Operations

    func delete(id: UUID) async throws {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let record = try context.fetch(fetchRequest).first {
            context.delete(record)
            try context.save()
            print("🗑️ Deleted transcription record: \(record.audioFileName)")
        }
    }

    func deleteMultiple(ids: [UUID]) async throws {
        let context = persistenceController.container.viewContext

        for id in ids {
            let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            if let record = try context.fetch(fetchRequest).first {
                context.delete(record)
            }
        }

        try context.save()
        print("🗑️ Deleted \(ids.count) transcription records")
    }

    // MARK: - Update Operations

    func updateNotes(id: UUID, notes: String?) async throws {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let record = try context.fetch(fetchRequest).first {
            record.notes = notes
            try context.save()
            print("📝 Updated notes for: \(record.audioFileName)")
        }
    }

    func updateTags(id: UUID, tags: [String]) async throws {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let record = try context.fetch(fetchRequest).first {
            record.tags = tags.joined(separator: ", ")
            try context.save()
            print("🏷️ Updated tags for: \(record.audioFileName)")
        }
    }

    // MARK: - Migration

    func importExistingTranscriptions() async {
        print("🔄 Starting migration of existing transcriptions...")
        var importedCount = 0

        // Check local monitored folder
        if AppSettings.shared.isMonitoringEnabled,
           let folderURL = FolderMonitorService.shared.monitoredFolder {
            importedCount += await importFromFolder(folderURL, source: "folder")
        }

        // Check iCloud folder
        if AppSettings.shared.iCloudSyncEnabled,
           let iCloudFolder = iCloudSyncService.shared.getRecordingsFolderURL() {
            importedCount += await importFromFolder(iCloudFolder, source: "icloud")
        }

        print("✅ Migration complete: Imported \(importedCount) transcriptions")
    }

    private func importFromFolder(_ folderURL: URL, source: String) async -> Int {
        var importedCount = 0

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Find all .txt transcription files
            let transcriptionFiles = files.filter { $0.pathExtension == "txt" }

            for txtFile in transcriptionFiles {
                // Find corresponding audio file
                let baseName = txtFile.deletingPathExtension().lastPathComponent
                let audioExtensions = ["m4a", "mp3", "wav", "aiff", "caf", "aac", "flac"]

                var audioFileURL: URL?
                for ext in audioExtensions {
                    let possibleAudioFile = folderURL.appendingPathComponent("\(baseName).\(ext)")
                    if FileManager.default.fileExists(atPath: possibleAudioFile.path) {
                        audioFileURL = possibleAudioFile
                        break
                    }
                }

                // If we found the audio file, create a database record
                if let audioURL = audioFileURL {
                    // Check if already in database
                    let context = persistenceController.container.viewContext
                    let fetchRequest: NSFetchRequest<TranscriptionRecord> = TranscriptionRecord.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "audioFilePath == %@", audioURL.path)

                    if try context.fetch(fetchRequest).isEmpty {
                        // Not in database, import it
                        if let transcriptionText = try? String(contentsOf: txtFile, encoding: .utf8) {
                            // Get file dates
                            let audioAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
                            let txtAttributes = try? FileManager.default.attributesOfItem(atPath: txtFile.path)

                            let createdAt = audioAttributes?[.creationDate] as? Date ?? Date()
                            let transcribedAt = txtAttributes?[.modificationDate] as? Date ?? Date()

                            // Get duration if possible
                            let duration = await AudioFileService.shared.getAudioDuration(audioURL) ?? 0

                            // Try to detect model from file size (rough approximation)
                            let modelUsed = "unknown"

                            try await saveTranscription(
                                audioFileName: audioURL.lastPathComponent,
                                audioFilePath: audioURL.path,
                                transcriptionText: transcriptionText,
                                transcriptionFilePath: txtFile.path,
                                source: source,
                                createdAt: createdAt,
                                transcribedAt: transcribedAt,
                                duration: duration,
                                modelUsed: modelUsed,
                                language: AppSettings.shared.selectedLanguage,
                                iCloudSynced: source == "icloud"
                            )

                            importedCount += 1
                            print("   📥 Imported: \(audioURL.lastPathComponent)")
                        }
                    }
                }
            }
        } catch {
            print("⚠️ Failed to import from folder \(folderURL.path): \(error)")
        }

        return importedCount
    }

    // MARK: - Statistics

    func getStatistics() async throws -> TranscriptionStatistics {
        let records = try await fetchAll()

        let totalCount = records.count
        let totalDuration = records.reduce(0) { $0 + $1.duration }
        let totalWords = records.reduce(0) { $0 + Int($1.wordCount) }

        let sourceBreakdown = Dictionary(grouping: records, by: { $0.source })
            .mapValues { $0.count }

        let modelBreakdown = Dictionary(grouping: records, by: { $0.modelUsed })
            .mapValues { $0.count }

        return TranscriptionStatistics(
            totalTranscriptions: totalCount,
            totalDuration: totalDuration,
            totalWords: totalWords,
            sourceBreakdown: sourceBreakdown,
            modelBreakdown: modelBreakdown
        )
    }
}

struct TranscriptionStatistics {
    let totalTranscriptions: Int
    let totalDuration: Double
    let totalWords: Int
    let sourceBreakdown: [String: Int]
    let modelBreakdown: [String: Int]

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return String(format: "%d timer %d minutter", hours, minutes)
    }
}