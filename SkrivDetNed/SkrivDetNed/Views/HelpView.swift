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
                    Text(NSLocalizedString("SkrivDetNed hjælp", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(NSLocalizedString("SkrivDetNed transkriberer automatisk dine lydoptagelser.", comment: ""))
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
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Getting started section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("**Kom godt i gang:**", comment: ""))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            HelpStepView(
                                number: "1",
                                text: NSLocalizedString("Download en model i Indstillinger → Modeller", comment: ""),
                                icon: "arrow.down.circle.fill"
                            )

                            HelpStepView(
                                number: "2",
                                text: NSLocalizedString("Vælg en mappe at overvåge i Indstillinger → Mappeovervågning", comment: ""),
                                icon: "folder.fill"
                            )

                            HelpStepView(
                                number: "3",
                                text: NSLocalizedString("Placer eller optag lydfiler i den valgte mappe", comment: ""),
                                icon: "waveform"
                            )

                            HelpStepView(
                                number: "4",
                                text: NSLocalizedString("Transkriptionen starter automatisk", comment: ""),
                                icon: "play.circle.fill"
                            )
                        }
                    }

                    Divider()

                    // Supported formats section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("**Understøttede formater:**", comment: ""))
                            .font(.headline)

                        Text(NSLocalizedString("M4A, MP3, WAV, AIFF, CAF, AAC, FLAC", comment: ""))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Tips section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("**Tips:**", comment: ""))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            HelpTipView(
                                text: NSLocalizedString("Brug menulinjen til hurtig adgang", comment: ""),
                                icon: "menubar.rectangle"
                            )

                            HelpTipView(
                                text: NSLocalizedString("Find transskriptioner ved siden af dine lydfiler (.txt)", comment: ""),
                                icon: "doc.text.fill"
                            )

                            HelpTipView(
                                text: NSLocalizedString("Juster indstillinger for bedre resultater", comment: ""),
                                icon: "slider.horizontal.3"
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 550)
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

#Preview {
    HelpView()
}
