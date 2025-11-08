//
//  SkrivDetNedApp.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import WidgetKit
import ActivityKit

@main
struct SkrivDetNedApp: App {
    @StateObject private var notificationService = NotificationService.shared

    init() {
        // Request notification permission on startup
        Task {
            await NotificationService.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Check iCloud availability
                    iCloudSyncService.shared.checkiCloudAvailability()

                    // Check for stuck and existing transcriptions from iCloud
                    Task {
                        await iCloudSyncService.shared.checkForStuckTranscriptions()
                        await iCloudSyncService.shared.checkForExistingTranscriptions()
                    }
                }
        }
    }
}
