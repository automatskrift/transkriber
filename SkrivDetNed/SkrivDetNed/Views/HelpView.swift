//
//  HelpView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 09/11/2025.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("SkrivDetNed Help", comment: "Help window title"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(NSLocalizedString("Automatic transcription for your voice recordings", comment: "Help subtitle"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick Start
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("**Quick Start**", comment: "Quick start section title"))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            HelpStepView(
                                number: "1",
                                text: NSLocalizedString("Enable iCloud sync in Settings", comment: "Quick start step 1"),
                                icon: "icloud.fill"
                            )

                            HelpStepView(
                                number: "2",
                                text: NSLocalizedString("Record audio on your iPhone using the companion app", comment: "Quick start step 2"),
                                icon: "iphone.radiowaves.left.and.right"
                            )

                            HelpStepView(
                                number: "3",
                                text: NSLocalizedString("Transcription starts automatically on your Mac", comment: "Quick start step 3"),
                                icon: "play.circle.fill"
                            )
                        }
                    }

                    Divider()

                    // iCloud Sync (detailed)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.accentColor)
                            Text(NSLocalizedString("**iCloud Sync (Recommended)**", comment: "iCloud section title"))
                                .font(.headline)
                        }

                        Text(NSLocalizedString("The easiest way to use SkrivDetNed is together with the companion iPhone app:", comment: "iCloud description intro"))
                            .font(.body)

                        VStack(alignment: .leading, spacing: 6) {
                            BulletPoint(text: NSLocalizedString("Record audio on your iPhone", comment: "iCloud bullet 1"))
                            BulletPoint(text: NSLocalizedString("Files sync automatically via iCloud", comment: "iCloud bullet 2"))
                            BulletPoint(text: NSLocalizedString("Mac app transcribes them in the background", comment: "iCloud bullet 3"))
                            BulletPoint(text: NSLocalizedString("View transcriptions on both devices", comment: "iCloud bullet 4"))
                        }
                        .font(.body)
                        .foregroundColor(.secondary)

                        Text(NSLocalizedString("**Note:** Both devices must be signed in to the same iCloud account and have iCloud Drive enabled.", comment: "iCloud note"))
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }

                    Divider()

                    // Local Folder Monitoring
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(NSLocalizedString("**Local Folder Monitoring**", comment: "Folder monitoring section title"))
                                .font(.headline)
                        }

                        Text(NSLocalizedString("You can also monitor a local folder on your Mac:", comment: "Folder monitoring intro"))
                            .font(.body)

                        VStack(alignment: .leading, spacing: 8) {
                            HelpStepView(
                                number: "1",
                                text: NSLocalizedString("Go to Monitoring tab", comment: "Folder monitoring step 1"),
                                icon: "folder.fill"
                            )

                            HelpStepView(
                                number: "2",
                                text: NSLocalizedString("Select a folder to monitor", comment: "Folder monitoring step 2"),
                                icon: "folder.badge.plus"
                            )

                            HelpStepView(
                                number: "3",
                                text: NSLocalizedString("Start monitoring", comment: "Folder monitoring step 3"),
                                icon: "play.circle.fill"
                            )

                            HelpStepView(
                                number: "4",
                                text: NSLocalizedString("Any audio file added to this folder will be transcribed automatically", comment: "Folder monitoring step 4"),
                                icon: "waveform"
                            )
                        }
                    }

                    Divider()

                    // Manual Transcription
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.accentColor)
                            Text(NSLocalizedString("**Manual Transcription**", comment: "Manual transcription section title"))
                                .font(.headline)
                        }

                        Text(NSLocalizedString("For one-off transcriptions:", comment: "Manual transcription intro"))
                            .font(.body)

                        VStack(alignment: .leading, spacing: 6) {
                            BulletPoint(text: NSLocalizedString("Go to the Manual tab", comment: "Manual bullet 1"))
                            BulletPoint(text: NSLocalizedString("Select an audio file", comment: "Manual bullet 2"))
                            BulletPoint(text: NSLocalizedString("Click Transcribe", comment: "Manual bullet 3"))
                        }
                        .font(.body)
                        .foregroundColor(.secondary)

                        Text(NSLocalizedString("The transcription will be saved as a .txt file next to your audio file.", comment: "Manual note"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    Divider()

                    // Models
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.accentColor)
                            Text(NSLocalizedString("**AI Models**", comment: "Models section title"))
                                .font(.headline)
                        }

                        Text(NSLocalizedString("SkrivDetNed uses WhisperKit for transcription. Models are downloaded automatically the first time you transcribe.", comment: "Models description"))
                            .font(.body)

                        Text(NSLocalizedString("**Model selection:**", comment: "Model selection title"))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            ModelDescriptionView(name: "Tiny", description: NSLocalizedString("Fastest, least accurate", comment: "Tiny model desc"))
                            ModelDescriptionView(name: "Base", description: NSLocalizedString("Good balance (recommended)", comment: "Base model desc"))
                            ModelDescriptionView(name: "Small", description: NSLocalizedString("Better accuracy, slower", comment: "Small model desc"))
                            ModelDescriptionView(name: "Medium", description: NSLocalizedString("High accuracy, requires more resources", comment: "Medium model desc"))
                            ModelDescriptionView(name: "Large", description: NSLocalizedString("Best accuracy, recommended for non-English languages", comment: "Large model desc"))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Divider()

                    // Supported formats
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("**Supported Audio Formats**", comment: "Formats section title"))
                            .font(.headline)

                        Text(NSLocalizedString("M4A, MP3, WAV, AIFF, CAF, AAC, FLAC", comment: "Supported formats list"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("**Tips**", comment: "Tips section title"))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            HelpTipView(
                                text: NSLocalizedString("Use the menu bar icon for quick status updates", comment: "Tip 1"),
                                icon: "menubar.rectangle"
                            )

                            HelpTipView(
                                text: NSLocalizedString("Transcriptions are saved as .txt files next to audio files", comment: "Tip 2"),
                                icon: "doc.text.fill"
                            )

                            HelpTipView(
                                text: NSLocalizedString("All transcriptions are processed in a queue - one at a time", comment: "Tip 3"),
                                icon: "list.number"
                            )

                            HelpTipView(
                                text: NSLocalizedString("Adjust language settings for better accuracy", comment: "Tip 4"),
                                icon: "globe"
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }
}

struct HelpStepView: View {
    let number: String
    let text: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 28, height: 28)

                Text(number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(text)
                    .font(.body)
            }
        }
    }
}

struct HelpTipView: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.body)
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
            Text(text)
                .font(.body)
        }
    }
}

struct ModelDescriptionView: View {
    let name: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Text("•")
            Text("**\(name):**")
                .fontWeight(.medium)
            Text(description)
        }
    }
}

#Preview {
    HelpView()
}
