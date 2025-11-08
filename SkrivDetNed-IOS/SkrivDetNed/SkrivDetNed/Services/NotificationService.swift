//
//  NotificationService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private init() {
        checkAuthorizationStatus()
        setupNotificationObservers()
    }

    /// Request notification permission
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            isAuthorized = granted

            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied by user")
            }

            return granted

        } catch {
            print("⚠️ Notification permission error: \(error.localizedDescription)")
            // This is expected if notifications are disabled in Settings
            // Don't treat as critical error
            isAuthorized = false
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    /// Send notification when transcription is ready
    func notifyTranscriptionReady(for title: String, recordingId: UUID) async {
        guard isAuthorized else {
            print("⚠️ Cannot send notification - not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Transskription klar"
        content.body = "'\(title)' er færdig transskriberet"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["recordingId": recordingId.uuidString]

        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "transcription-\(recordingId.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📬 Notification scheduled for: \(title)")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }

    /// Send notification when upload completes
    func notifyUploadComplete(for title: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upload fuldført"
        content.body = "'\(title)' er uploadet til iCloud"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "upload-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Failed to schedule upload notification: \(error)")
        }
    }

    /// Send notification when upload fails
    func notifyUploadFailed(for title: String, error: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upload fejlede"
        content.body = "'\(title)' kunne ikke uploades: \(error)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "upload-failed-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Failed to schedule error notification: \(error)")
        }
    }

    /// Clear all notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🧹 Cleared all notifications")
    }

    /// Clear badge count
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Listen for transcription received notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTranscriptionReceived),
            name: NSNotification.Name("TranscriptionReceived"),
            object: nil
        )
    }

    @objc private func handleTranscriptionReceived(_ notification: Notification) {
        guard let audioFileName = notification.userInfo?["audioFileName"] as? String else {
            return
        }

        Task {
            // Load the recording to get its title
            let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Recordings")

            do {
                let files = try FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil)
                let jsonFiles = files.filter { $0.pathExtension == "json" }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                for file in jsonFiles {
                    if let data = try? Data(contentsOf: file),
                       let recording = try? decoder.decode(Recording.self, from: data),
                       recording.fileName == audioFileName {

                        // Send notification
                        await notifyTranscriptionReady(for: recording.title, recordingId: recording.id)
                        break
                    }
                }
            } catch {
                print("❌ Failed to find recording for notification: \(error)")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
