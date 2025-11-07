//
//  AboutView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))

            // App Name
            Text("SkrivDetNed")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Version
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical)

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("Om SkrivDetNed")
                    .font(.headline)

                Text("SkrivDetNed er en intelligent macOS-applikation der automatisk transkriberer dine lydoptagelser ved hjælp af avanceret talegenkendelse.")
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("Funktioner:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    FeatureRow(icon: "folder.badge.gearshape", text: "Automatisk mappeovervågning")
                    FeatureRow(icon: "waveform", text: "AI-baseret transskribering")
                    FeatureRow(icon: "icloud", text: "iCloud Drive support")
                    FeatureRow(icon: "bell", text: "Notifikationer")
                    FeatureRow(icon: "lock.shield", text: "Lokal behandling - ingen cloud")
                }
                .font(.caption)
            }
            .frame(maxWidth: 400)

            Divider()
                .padding(.vertical)

            // Copyright
            VStack(spacing: 4) {
                Text("Copyright © 2025 Tomas Thøfner")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Alle rettigheder forbeholdes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Close button
            Button("Luk") {
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
