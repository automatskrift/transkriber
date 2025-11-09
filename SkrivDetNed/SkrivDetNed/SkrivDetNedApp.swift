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
        // Setup menu bar
        Task { @MainActor in
            menuBarManager = MenuBarManager.shared
        }

        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Setup application support directories
        do {
            _ = try FileSystemHelper.shared.createApplicationSupportDirectory()
            _ = try FileSystemHelper.shared.createModelsDirectory()
        } catch {
            print("Failed to create application support directories: \(error)")
        }

        // Start heartbeat to let iOS know Mac is online
        Task { @MainActor in
            iCloudSyncService.shared.startHeartbeat()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop heartbeat when app quits
        Task { @MainActor in
            iCloudSyncService.shared.stopHeartbeat()
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
