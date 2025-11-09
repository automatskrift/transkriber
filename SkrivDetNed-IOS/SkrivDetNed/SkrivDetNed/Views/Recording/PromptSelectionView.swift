//
//  PromptSelectionView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import SwiftUI

struct PromptSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @Binding var selectedPrompt: TranscriptionPrompt?

    var body: some View {
        List {
            ForEach(settings.transcriptionPrompts) { prompt in
                Button(action: {
                    print("🔘 Prompt selected: \(prompt.name)")
                    selectedPrompt = prompt
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prompt.name)
                                .font(.headline)
                                .foregroundColor(.primary)

                            if !prompt.text.isEmpty {
                                Text(prompt.text)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        if selectedPrompt?.id == prompt.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(NSLocalizedString("Vælg LLM Prompt", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PromptSelectionView(selectedPrompt: .constant(nil))
    }
}
