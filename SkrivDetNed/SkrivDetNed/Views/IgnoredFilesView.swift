//
//  IgnoredFilesView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import SwiftUI

struct IgnoredFilesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ignorerede Lydfiler")
                    .font(.headline)
                Spacer()
                Button("Luk") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if settings.ignoredFiles.isEmpty {
                emptyState
            } else {
                filesList
            }
        }
        .frame(width: 600, height: 400)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Ingen ignorerede filer")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Filer du vælger at ignorere vil blive vist her")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filesList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(settings.ignoredFiles.sorted()), id: \.self) { filePath in
                    IgnoredFileRow(filePath: filePath)
                    Divider()
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct IgnoredFileRow: View {
    let filePath: String
    @ObservedObject private var settings = AppSettings.shared

    private var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .foregroundColor(fileExists ? .orange : .gray)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(filePath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !fileExists {
                    Text("(Fil findes ikke længere)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Button(action: {
                unignoreFile(filePath)
            }) {
                Label("Fjern fra liste", systemImage: "arrow.uturn.backward")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Fjern fra ignorerede og tillad transskribering igen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    private func unignoreFile(_ filePath: String) {
        var ignoredFiles = settings.ignoredFiles
        ignoredFiles.remove(filePath)
        settings.ignoredFiles = ignoredFiles

        print("✅ Un-ignored file: \(fileName)")
    }
}

#Preview {
    IgnoredFilesView()
}
