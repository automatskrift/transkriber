//
//  BookmarkManager.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 11/11/2025.
//

import Foundation

/// Manages security-scoped bookmarks for persistent file access in sandboxed environment
class BookmarkManager {
    static let shared = BookmarkManager()

    private let bookmarkKey = "FolderMonitorBookmark"
    private var currentAccessingURL: URL?

    private init() {}

    /// Creates and saves a security-scoped bookmark for the given URL
    /// - Parameter url: The folder URL selected by the user
    /// - Returns: True if bookmark was created and saved successfully
    func saveBookmark(for url: URL) throws {
        // Create a security-scoped bookmark
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Save to UserDefaults
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        UserDefaults.standard.set(url.path, forKey: "\(bookmarkKey)_path")

        print("✅ Saved security-scoped bookmark for: \(url.path)")
    }

    /// Resolves and starts accessing a previously saved bookmark
    /// - Returns: The resolved URL if successful, nil otherwise
    func resolveBookmark() -> URL? {
        print("🔍 BookmarkManager.resolveBookmark() called")

        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            print("   ⚠️ No saved bookmark found in UserDefaults")
            print("   📋 UserDefaults keys: \(UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.contains("Bookmark") })")
            return nil
        }

        print("   ✓ Found bookmark data (\(bookmarkData.count) bytes)")

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            print("   ✓ Resolved bookmark to URL: \(url.path)")
            print("   📊 Bookmark is stale: \(isStale)")

            if isStale {
                print("   ⚠️ Bookmark is stale, recreating...")
                // Try to save a new bookmark
                try? saveBookmark(for: url)
            }

            // Start accessing the security-scoped resource
            print("   🔓 Attempting to start accessing security-scoped resource...")
            guard url.startAccessingSecurityScopedResource() else {
                print("   ❌ Failed to start accessing security-scoped resource")
                print("   📁 URL path: \(url.path)")
                print("   📁 URL exists: \(FileManager.default.fileExists(atPath: url.path))")
                return nil
            }

            currentAccessingURL = url
            print("   ✅ Resolved and accessing security-scoped bookmark: \(url.path)")
            return url

        } catch {
            print("   ❌ Failed to resolve bookmark: \(error)")
            print("   📋 Error type: \(type(of: error))")
            return nil
        }
    }

    /// Stops accessing the current security-scoped resource
    func stopAccessing() {
        if let url = currentAccessingURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessingURL = nil
            print("✅ Stopped accessing security-scoped resource")
        }
    }

    /// Removes the saved bookmark
    func removeBookmark() {
        stopAccessing()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: "\(bookmarkKey)_path")
        print("✅ Removed saved bookmark")
    }

    /// Gets the path of the saved bookmark without accessing it
    func getSavedBookmarkPath() -> String? {
        return UserDefaults.standard.string(forKey: "\(bookmarkKey)_path")
    }

    /// Checks if a bookmark exists
    var hasBookmark: Bool {
        return UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }
}
