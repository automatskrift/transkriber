//
//  RecordingRow.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: recording.cloudStatus.icon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 18))
            }

            // Recording info
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(2)

                // Only show details if not actively transcribing
                if recording.cloudStatus != .transcribing {
                    // Duration and file size on one line
                    HStack(spacing: 8) {
                        Label(recording.formattedDuration, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(recording.formattedFileSize, systemImage: "doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Time ago on separate line
                    Text(timeAgoString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Status on separate line with icon
                HStack(spacing: 6) {
                    Image(systemName: recording.cloudStatus.icon)
                        .foregroundColor(statusColor)
                        .font(.caption)

                    Text(recording.cloudStatus.displayName)
                        .font(.caption)
                        .foregroundColor(statusColor)

                    if recording.cloudStatus == .uploading || recording.cloudStatus == .transcribing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if !recording.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(recording.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            Spacer()

            // iCloud status icon (smaller, on the side)
            Image(systemName: iCloudIconName)
                .foregroundColor(iCloudIconColor)
                .font(.title3)
        }
        .padding(.vertical, 8)
    }

    private var timeAgoString: String {
        let now = Date()
        let interval = now.timeIntervalSince(recording.createdAt)

        if interval < 60 {
            return "For et øjeblik siden"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "For \(minutes) minut\(minutes == 1 ? "" : "ter") siden"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "For \(hours) time\(hours == 1 ? "" : "r") siden"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "For \(days) dag\(days == 1 ? "" : "e") siden"
        } else if interval < 2592000 {
            let weeks = Int(interval / 604800)
            return "For \(weeks) uge\(weeks == 1 ? "" : "r") siden"
        } else if interval < 31536000 {
            let months = Int(interval / 2592000)
            return "For \(months) måned\(months == 1 ? "" : "er") siden"
        } else {
            let years = Int(interval / 31536000)
            return "For \(years) år siden"
        }
    }

    private var statusColor: Color {
        switch recording.cloudStatus.color {
        case "gray": return .gray
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }

    private var iCloudIconName: String {
        switch recording.cloudStatus {
        case .local:
            return "iphone"
        case .uploading:
            return "icloud.and.arrow.up"
        case .synced, .pending, .transcribing, .completed:
            return "icloud.and.arrow.down.fill"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    private var iCloudIconColor: Color {
        switch recording.cloudStatus {
        case .local:
            return .gray
        case .uploading:
            return .blue
        case .synced:
            return .green
        case .pending, .transcribing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

#Preview {
    List {
        // Local only
        RecordingRow(recording: {
            var rec = Recording(
                fileName: "local.m4a",
                localURL: URL(fileURLWithPath: "/tmp/local.m4a"),
                duration: 125,
                fileSize: 1024000
            )
            rec.title = "Kun lokal"
            rec.cloudStatus = .local
            return rec
        }())

        // Uploading
        RecordingRow(recording: {
            var rec = Recording(
                fileName: "uploading.m4a",
                localURL: URL(fileURLWithPath: "/tmp/uploading.m4a"),
                duration: 180,
                fileSize: 2048000
            )
            rec.title = "Uploader..."
            rec.cloudStatus = .uploading
            return rec
        }())

        // Synced to iCloud
        RecordingRow(recording: {
            var rec = Recording(
                fileName: "synced.m4a",
                localURL: URL(fileURLWithPath: "/tmp/synced.m4a"),
                duration: 240,
                fileSize: 3072000
            )
            rec.title = "Synkroniseret"
            rec.cloudStatus = .synced
            return rec
        }())

        // Transcribing
        RecordingRow(recording: {
            var rec = Recording(
                fileName: "transcribing.m4a",
                localURL: URL(fileURLWithPath: "/tmp/transcribing.m4a"),
                duration: 3665,
                fileSize: 5242880
            )
            rec.title = "Møde med team"
            rec.tags = ["møde", "arbejde"]
            rec.cloudStatus = .transcribing
            return rec
        }())

        // Completed
        RecordingRow(recording: {
            var rec = Recording(
                fileName: "completed.m4a",
                localURL: URL(fileURLWithPath: "/tmp/completed.m4a"),
                duration: 450,
                fileSize: 4096000
            )
            rec.title = "Transskriberet"
            rec.cloudStatus = .completed
            rec.hasTranscription = true
            return rec
        }())

        // Failed
        RecordingRow(recording: {
            var rec = Recording(
                fileName: "failed.m4a",
                localURL: URL(fileURLWithPath: "/tmp/failed.m4a"),
                duration: 60,
                fileSize: 512000
            )
            rec.title = "Upload fejlede"
            rec.cloudStatus = .failed
            return rec
        }())
    }
}
