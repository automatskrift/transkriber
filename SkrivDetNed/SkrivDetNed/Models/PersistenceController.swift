//
//  PersistenceController.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import CoreData
import Foundation

class PersistenceController {
    static let shared = PersistenceController()

    // Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Add sample data for previews
        for i in 0..<5 {
            let record = TranscriptionRecord(context: viewContext)
            record.id = UUID()
            record.audioFileName = "sample_\(i).m4a"
            record.audioFilePath = "/path/to/sample_\(i).m4a"
            record.transcriptionText = "This is sample transcription text number \(i). It contains multiple sentences to demonstrate the text preview functionality."
            record.source = ["manual", "folder", "icloud"][i % 3]
            record.createdAt = Date().addingTimeInterval(TimeInterval(-3600 * i))
            record.transcribedAt = Date().addingTimeInterval(TimeInterval(-3600 * i + 1800))
            record.duration = Double(120 + i * 30)
            record.wordCount = Int32(50 + i * 10)
            record.modelUsed = ["tiny", "base", "small", "medium", "large"][i % 5]
            record.language = "da"
            record.iCloudSynced = i % 2 == 0
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SkrivDetNed")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Set up the persistent store location
            let storeURL = getDocumentsDirectory().appendingPathComponent("SkrivDetNed.sqlite")
            container.persistentStoreDescriptions.first!.url = storeURL

            // Enable automatic migration
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            }
        }

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ Core Data failed to load: \(error), \(error.userInfo)")

                // In production, you might want to handle this more gracefully
                // For now, we'll try to recover by deleting the store and recreating it
                if !inMemory {
                    print("🔄 Attempting to recover by recreating the database...")
                    self.deleteAndRecreateStore()
                }
            } else {
                print("✅ Core Data loaded successfully")
                print("   Store URL: \(storeDescription.url?.path ?? "unknown")")
            }
        }

        // Configure for performance
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0].appendingPathComponent("SkrivDetNed")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        return documentsDirectory
    }

    private func deleteAndRecreateStore() {
        let storeURL = getDocumentsDirectory().appendingPathComponent("SkrivDetNed.sqlite")
        let storeURLWAL = getDocumentsDirectory().appendingPathComponent("SkrivDetNed.sqlite-wal")
        let storeURLSHM = getDocumentsDirectory().appendingPathComponent("SkrivDetNed.sqlite-shm")

        // Delete all store files
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURLWAL)
        try? FileManager.default.removeItem(at: storeURLSHM)

        // Reload stores
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Failed to recover Core Data: \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data store recreated successfully")
            }
        }
    }

    // MARK: - Core Data Saving support

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
                print("💾 Core Data context saved")
            } catch {
                let nsError = error as NSError
                print("❌ Failed to save Core Data context: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Batch operations

    func deleteAll() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TranscriptionRecord.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        try container.viewContext.execute(deleteRequest)
        save()
        print("🗑️ Deleted all transcription records")
    }
}

// MARK: - TranscriptionRecord Core Data Class

import CoreData

@objc(TranscriptionRecord)
public class TranscriptionRecord: NSManagedObject {

}

extension TranscriptionRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptionRecord> {
        return NSFetchRequest<TranscriptionRecord>(entityName: "TranscriptionRecord")
    }

    @NSManaged public var id: UUID
    @NSManaged public var audioFileName: String
    @NSManaged public var audioFilePath: String
    @NSManaged public var transcriptionText: String
    @NSManaged public var transcriptionFilePath: String?
    @NSManaged public var source: String
    @NSManaged public var createdAt: Date
    @NSManaged public var transcribedAt: Date
    @NSManaged public var duration: Double
    @NSManaged public var wordCount: Int32
    @NSManaged public var modelUsed: String
    @NSManaged public var language: String?
    @NSManaged public var notes: String?
    @NSManaged public var tags: String?
    @NSManaged public var iCloudSynced: Bool
    @NSManaged public var marksData: Data?

    // Computed properties for UI
    var sourceIcon: String {
        switch source {
        case "manual": return "hand.tap"
        case "folder": return "folder"
        case "icloud": return "icloud"
        default: return "questionmark.circle"
        }
    }

    var sourceDisplayName: String {
        switch source {
        case "manual": return NSLocalizedString("Manual", comment: "Manual source")
        case "folder": return NSLocalizedString("Folder", comment: "Folder source")
        case "icloud": return "iCloud"
        default: return source
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var marks: [Double]? {
        guard let data = marksData else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }

    var tagArray: [String] {
        guard let tags = tags, !tags.isEmpty else { return [] }
        return tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

extension TranscriptionRecord: Identifiable {
    // Identifiable conformance for SwiftUI
}