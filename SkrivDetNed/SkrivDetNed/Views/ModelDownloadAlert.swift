//
//  ModelDownloadAlert.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import SwiftUI

struct ModelDownloadAlert: View {
    let modelName: String
    @Binding var isPresented: Bool
    @EnvironmentObject var whisperService: WhisperService

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .symbolEffect(.pulse, value: whisperService.isDownloadingModel)

            // Title
            Text(NSLocalizedString("Downloading Whisper Model", comment: "Download alert title"))
                .font(.title2)
                .fontWeight(.semibold)

            // Model name
            Text(modelName)
                .font(.headline)
                .foregroundColor(.secondary)

            // Explanation
            VStack(spacing: 12) {
                Text(NSLocalizedString("The AI model needs to be downloaded to your computer.", comment: "Download explanation"))
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("This is a one-time download.", comment: "One-time download"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(NSLocalizedString("Download time depends on your internet connection speed.", comment: "Download time info"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // Model size info
            GroupBox {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Model Size", comment: "Model size label"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(getModelSizeText(for: modelName))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
            }

            // Progress indicator (always show when downloading)
            if whisperService.isDownloadingModel {
                VStack(spacing: 8) {
                    if whisperService.downloadProgress > 0 && whisperService.downloadProgress < 1 {
                        ProgressView(value: whisperService.downloadProgress)
                            .progressViewStyle(.linear)

                        Text(String(format: NSLocalizedString("Downloading: %d%%", comment: "Download percentage"), Int(whisperService.downloadProgress * 100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)

                        Text(NSLocalizedString("Starting download...", comment: "Starting download"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Single OK button
            Button(NSLocalizedString("OK", comment: "OK button")) {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }

    private func getModelSizeText(for model: String) -> String {
        // Approximate sizes for Whisper models
        switch model.lowercased() {
        case let m where m.contains("tiny"):
            return "~39 MB"
        case let m where m.contains("base"):
            return "~74 MB"
        case let m where m.contains("small"):
            return "~244 MB"
        case let m where m.contains("medium"):
            return "~769 MB"
        case let m where m.contains("large"):
            return "~1.55 GB"
        default:
            return NSLocalizedString("Size varies", comment: "Unknown model size")
        }
    }
}

struct ModelDownloadAlert_Previews: PreviewProvider {
    static var previews: some View {
        ModelDownloadAlert(
            modelName: "Whisper Large",
            isPresented: .constant(true)
        )
        .environmentObject(WhisperService.shared)
    }
}