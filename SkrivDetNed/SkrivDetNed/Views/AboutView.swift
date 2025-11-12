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
        VStack(spacing: 16) {
            // App Icon
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            // App Name & Version
            VStack(spacing: 4) {
                Text(NSLocalizedString("SkrivDetNed", comment: "App name"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(format: NSLocalizedString("Version %@", comment: "Version label with number"), appVersion))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            // Description
            VStack(alignment: .leading, spacing: 12) {
                // Main description with iPhone integration
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "iphone.and.laptop")
                        .font(.title3)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Mac companion app for automatic transcription", comment: "About description"))
                            .font(.body)
                            .fontWeight(.medium)

                        Text(NSLocalizedString("Record audio on your iPhone using the companion app. Your recordings sync via iCloud and are automatically transcribed on your Mac.", comment: "About iPhone integration"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: 340)

            Divider()
                .padding(.vertical, 4)

            // Links
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://omdethele.dk/apps") {
                        openURL(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(NSLocalizedString("Website", comment: "Website link"))
                    }
                    .font(.caption)
                }
                .buttonStyle(.link)

                Text("•")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Button(action: {
                    if let url = URL(string: "https://apps.apple.com/app/skrivdetned") {
                        openURL(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "iphone")
                        Text(NSLocalizedString("iPhone App", comment: "iPhone app link"))
                    }
                    .font(.caption)
                }
                .buttonStyle(.link)
            }

            // Copyright
            Text(NSLocalizedString("© 2025 Tomas Thøfner", comment: "Copyright"))
                .font(.caption2)
                .foregroundColor(.secondary)

            // Close button
            Button(NSLocalizedString("Close", comment: "Close button")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(24)
        .frame(width: 400)
    }
}

#Preview {
    AboutView()
}
