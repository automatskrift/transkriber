//
//  SkrivDetNedApp.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import UserNotifications

@main
struct SkrivDetNedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showingAbout = false
    @State private var showingHelp = false

    // Initialize Core Data
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showingAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showingHelp) {
                    HelpView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(String(format: NSLocalizedString("Om %@", comment: ""), NSLocalizedString("SkrivDetNed", comment: ""))) {
                    showingAbout = true
                }
            }

            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("Sådan bruges SkrivDetNed", comment: "")) {
                    showingHelp = true
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar immediately for responsiveness
        menuBarManager = MenuBarManager.shared

        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Defer heavy initialization to background
        Task {
            // Small delay to let UI render first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Setup application support directories
            do {
                _ = try FileSystemHelper.shared.createApplicationSupportDirectory()
                _ = try FileSystemHelper.shared.createModelsDirectory()
            } catch {
                print("Failed to create application support directories: \(error)")
            }

            // Start heartbeat to let iOS know Mac is online
            await MainActor.run {
                iCloudSyncService.shared.startHeartbeat()
            }

            // Restore folder monitoring if it was enabled
            await MainActor.run {
                if AppSettings.shared.isMonitoringEnabled {
                    print("📂 Restoring folder monitoring on app launch...")
                    let restored = FolderMonitorService.shared.restoreMonitoringFromBookmark()
                    if restored {
                        print("✅ Folder monitoring restored successfully")
                    } else {
                        print("⚠️ Failed to restore folder monitoring")
                        // Reset the flag if restoration failed
                        AppSettings.shared.isMonitoringEnabled = false
                    }
                }
            }

            // Migrate existing transcriptions to Core Data (first launch after update)
            // Do this last and with a longer delay as it's not urgent
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                print("🗄️ Checking for existing transcriptions to import...")
                Task {
                    await TranscriptionDatabase.shared.importExistingTranscriptions()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop heartbeat when app quits
        Task { @MainActor in
            iCloudSyncService.shared.stopHeartbeat()
        }

        // Clean up folder monitoring resources
        Task { @MainActor in
            if FolderMonitorService.shared.isMonitoring {
                // Note: Don't call stopMonitoring() as it would disable the feature
                // Just clean up the security-scoped resource access
                BookmarkManager.shared.stopAccessing()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window is closed, keep running in background
        return false
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        completionHandler()
    }
}
