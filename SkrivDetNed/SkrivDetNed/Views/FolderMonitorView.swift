//
//  FolderMonitorView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct FolderMonitorView: View {
    @StateObject private var viewModel = FolderMonitorViewModel()
    @ObservedObject private var transcriptionVM = TranscriptionViewModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Folder Selection
                GroupBox(label: Label("Overvåget Folder", systemImage: "folder")) {
                    VStack(spacing: 12) {
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
                                Text("Ingen folder valgt")
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: viewModel.selectFolder) {
                                Label("Vælg Folder", systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Status
                        HStack {
                            Label {
                                Text("Status:")
                                    .foregroundColor(.secondary)
                            } icon: {
                                Circle()
                                    .fill(viewModel.statusColor)
                                    .frame(width: 8, height: 8)
                            }

                            Text(viewModel.statusText)
                                .fontWeight(.medium)

                            Spacer()

                            // Toggle monitoring button
                            if viewModel.selectedFolderURL != nil {
                                Button(action: viewModel.toggleMonitoring) {
                                    Text(viewModel.isMonitoring ? "Stop Overvågning" : "Start Overvågning")
                                        .frame(minWidth: 140)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(viewModel.isMonitoring ? .red : .green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Active Transcriptions
                if !transcriptionVM.activeTasks.isEmpty {
                    GroupBox(label: Label("Kørende Transkriberinger", systemImage: "waveform")) {
                        VStack(spacing: 12) {
                            ForEach(transcriptionVM.activeTasks) { task in
                                TranscriptionTaskRow(task: task)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Pending Files
                if !viewModel.pendingFiles.isEmpty {
                    GroupBox(label: Label("I Kø", systemImage: "clock")) {
                        VStack(spacing: 8) {
                            ForEach(viewModel.pendingFiles, id: \.self) { fileURL in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.secondary)
                                    Text(fileURL.lastPathComponent)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("Venter...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Recent Completions
                if !viewModel.recentlyCompleted.isEmpty {
                    GroupBox(label: Label("Seneste Færdige", systemImage: "checkmark.circle")) {
                        VStack(spacing: 8) {
                            ForEach(viewModel.recentlyCompleted) { task in
                                CompletedTaskRow(task: task)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Empty state
                if viewModel.selectedFolderURL == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Vælg en folder for at komme i gang")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Appen vil automatisk overvåge folderen og transkribere nye lydfiler")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                if viewModel.selectedFolderURL != nil && !viewModel.isMonitoring &&
                   transcriptionVM.activeTasks.isEmpty &&
                   viewModel.pendingFiles.isEmpty &&
                   viewModel.recentlyCompleted.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("Klar til at starte")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Tryk 'Start Overvågning' for at begynde at overvåge folderen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct TranscriptionTaskRow: View {
    let task: TranscriptionTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.fileName)
                        .font(.headline)

                    Text("→ \(task.outputFileURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if case .processing(let progress) = task.status {
                    Text("\(Int(progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
            }

            // Progress bar
            if case .processing(let progress) = task.status {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CompletedTaskRow: View {
    let task: TranscriptionTask

    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.fileName)
                    .font(.subheadline)

                if let completedAt = task.completedAt {
                    Text(completedAt.timeAgoString())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch task.status {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        default:
            return "circle"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .secondary
        }
    }

    private var statusText: String {
        switch task.status {
        case .completed:
            if let duration = task.duration {
                return "Færdig (\(Int(duration))s)"
            }
            return "Færdig"
        case .failed(let error):
            return "Fejl"
        default:
            return ""
        }
    }
}

#Preview {
    FolderMonitorView()
}
