//
//  AboutView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            // App Name
            Text(NSLocalizedString("SkrivDetNed", comment: ""))
                .font(.largeTitle)
                .fontWeight(.bold)

            // Version
            Text("Version \(appVersion)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical)

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: NSLocalizedString("Om %@", comment: ""), NSLocalizedString("SkrivDetNed", comment: "")))
                    .font(.headline)

                Text(String(format: NSLocalizedString("%@ er en intelligent macOS-applikation der automatisk transkriberer dine lydoptagelser ved hjælp af avanceret talegenkendelse.", comment: ""), NSLocalizedString("SkrivDetNed", comment: "")))
                    .font(.body)
                    .foregroundColor(.secondary)

                Text(NSLocalizedString("Funktioner:", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    FeatureRow(icon: "folder.badge.gearshape", text: NSLocalizedString("Automatisk mappeovervågning", comment: ""))
                    FeatureRow(icon: "waveform", text: NSLocalizedString("AI-baseret transskribering", comment: ""))
                    FeatureRow(icon: "icloud", text: NSLocalizedString("iCloud Drive support", comment: ""))
                    FeatureRow(icon: "bell", text: NSLocalizedString("Notifikationer", comment: ""))
                    FeatureRow(icon: "lock.shield", text: NSLocalizedString("Lokal behandling - ingen cloud", comment: ""))
                }
                .font(.caption)
            }
            .frame(maxWidth: 400)

            Divider()
                .padding(.vertical)

            // Website link
            Button(action: {
                if let url = URL(string: "https://omdethele.dk/apps") {
                    openURL(url)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text(NSLocalizedString("Besøg hjemmeside", comment: ""))
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                }
            }
            .buttonStyle(.link)
            .controlSize(.large)

            // Copyright
            VStack(spacing: 4) {
                Text(NSLocalizedString("Copyright © 2025 Tomas Thøfner", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(NSLocalizedString("Alle rettigheder forbeholdes", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Close button
            Button(NSLocalizedString("Luk", comment: "")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding(32)
        .frame(width: 500)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AboutView()
}
