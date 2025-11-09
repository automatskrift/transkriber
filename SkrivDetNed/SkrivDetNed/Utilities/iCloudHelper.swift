//
//  iCloudHelper.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

class iCloudHelper {
    static let shared = iCloudHelper()

    private init() {}

    func isICloudURL(_ url: URL) -> Bool {
        return url.path.contains("/Library/Mobile Documents/") ||
               url.path.contains("/iCloud~")
    }

    func isICloudPlaceholder(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent
        return fileName.hasPrefix(".") && fileName.hasSuffix(".icloud")
    }

    func getActualURL(from placeholderURL: URL) -> URL? {
        guard isICloudPlaceholder(placeholderURL) else {
            return placeholderURL
        }

        let fileName = placeholderURL.lastPathComponent
        // Remove the leading "." and trailing ".icloud"
        let actualFileName = String(fileName.dropFirst().dropLast(7))
        return placeholderURL.deletingLastPathComponent().appendingPathComponent(actualFileName)
    }

    func startDownloading(_ url: URL) throws {
        guard isICloudURL(url) else { return }

        let fileManager = FileManager.default

        // If it's a placeholder, trigger download
        if isICloudPlaceholder(url) {
            if let actualURL = getActualURL(from: url) {
                try fileManager.startDownloadingUbiquitousItem(at: actualURL)
            }
        } else {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        }
    }

    func isDownloaded(_ url: URL) throws -> Bool {
        guard isICloudURL(url) else { return true }

        // Check if file is downloaded
        let resourceValues = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])

        if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
            return downloadStatus == .current
        }

        return false
    }

    func waitForDownload(_ url: URL, timeout: TimeInterval = 60.0) async throws -> Bool {
        guard isICloudURL(url) else { return true }

        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if try isDownloaded(url) {
                return true
            }

            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        return false
    }
}
