//
//  MonitorFolderView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 12/11/2025.
//

import SwiftUI

struct MonitorFolderView: View {
    @EnvironmentObject private var viewModel: FolderMonitorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Monitor Folder", comment: "Monitor Folder page title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(NSLocalizedString("Configure automatic monitoring of a local folder for new audio files.", comment: "Monitor Folder page description"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                // MARK: - Monitored Folder Section
                GroupBox(label: Label(NSLocalizedString("Monitored Folder", comment: "Monitored Folder section title"), systemImage: "folder")) {
                    VStack(spacing: 16) {
                        // Folder display
                        HStack {
                            if let folderURL = viewModel.selectedFolderURL {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folderURL.lastPathComponent)
                                        .font(.headline)
                                    Text(folderURL.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            } else {
                                Text(NSLocalizedString("No folder selected", comment: "No folder selected text"))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: viewModel.selectFolder) {
                                Label(NSLocalizedString("Select Folder", comment: "Select Folder button"), systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        // Status display
                        HStack {
                            Label {
                                Text(NSLocalizedString("Status:", comment: "Status label"))
                                    .foregroundColor(.secondary)
                            } icon: {
                                Circle()
                                    .fill(viewModel.statusColor)
                                    .frame(width: 10, height: 10)
                            }

                            Text(viewModel.statusText)
                                .fontWeight(.medium)

                            Spacer()
                        }

                        // Control buttons
                        HStack(spacing: 12) {
                            if viewModel.selectedFolderURL != nil {
                                Button(action: viewModel.toggleMonitoring) {
                                    HStack {
                                        Image(systemName: viewModel.isMonitoring ? "stop.fill" : "play.fill")
                                        Text(viewModel.isMonitoring ? NSLocalizedString("Stop Monitoring", comment: "Stop Monitoring button") : NSLocalizedString("Start Monitoring", comment: "Start Monitoring button"))
                                    }
                                    .frame(minWidth: 160)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(viewModel.isMonitoring ? .red : .green)
                                .controlSize(.large)
                            }

                            Spacer()
                        }
                    }
                    .padding(4)
                }

                // MARK: - Info about queue
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .imageScale(.large)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Files found will be added to the transcription queue.", comment: "Queue info text"))
                            .font(.body)
                        Text(NSLocalizedString("Go to the Monitoring tab to see progress", comment: "Monitoring tab hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(8)

                // MARK: - Information Section
                GroupBox(label: Label(NSLocalizedString("How it works", comment: "How it works section title"), systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "1.circle.fill",
                            title: NSLocalizedString("Choose folder", comment: "Step 1 title"),
                            description: NSLocalizedString("Select a local folder on your Mac to monitor.", comment: "Step 1 description")
                        )

                        InfoRow(
                            icon: "2.circle.fill",
                            title: NSLocalizedString("Start monitoring", comment: "Step 2 title"),
                            description: NSLocalizedString("Click 'Start Monitoring' to begin monitoring the folder.", comment: "Step 2 description")
                        )

                        InfoRow(
                            icon: "3.circle.fill",
                            title: NSLocalizedString("Automatic transcription", comment: "Step 3 title"),
                            description: NSLocalizedString("When new audio files are added to the folder, they are automatically transcribed.", comment: "Step 3 description")
                        )

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)

                            Text(NSLocalizedString("Monitoring continues even after you restart the app.", comment: "Monitoring persistence info"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(4)
                }

                // MARK: - Supported Formats
                GroupBox(label: Label(NSLocalizedString("Supported formats", comment: "Supported formats section title"), systemImage: "waveform")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("The following audio formats are supported:", comment: "Supported formats description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach(["M4A", "MP3", "WAV", "AIFF", "CAF", "AAC", "FLAC"], id: \.self) { format in
                                Text(format)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert(NSLocalizedString("Error", comment: "Error alert title"), isPresented: $viewModel.showError) {
            Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    MainActor.assumeIsolated {
        MonitorFolderView()
            .environmentObject(FolderMonitorViewModel.shared)
    }
}
