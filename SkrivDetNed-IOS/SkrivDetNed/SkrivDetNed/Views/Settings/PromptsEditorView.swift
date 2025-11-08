//
//  PromptsEditorView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import SwiftUI

struct PromptsEditorView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingAddPrompt = false
    @State private var editingPrompt: TranscriptionPrompt?

    var body: some View {
        List {
            ForEach(settings.transcriptionPrompts) { prompt in
                Button(action: {
                    editingPrompt = prompt
                }) {
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
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deletePrompts)
            .onMove(perform: movePrompts)
        }
        .navigationTitle("LLM Prompts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddPrompt = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddPrompt) {
            PromptEditSheet(prompt: nil, onSave: { newPrompt in
                settings.addPrompt(newPrompt)
            })
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditSheet(prompt: prompt, onSave: { updatedPrompt in
                settings.updatePrompt(updatedPrompt)
            })
        }
    }

    private func deletePrompts(at offsets: IndexSet) {
        for index in offsets {
            let prompt = settings.transcriptionPrompts[index]
            settings.deletePrompt(prompt)
        }
    }

    private func movePrompts(from source: IndexSet, to destination: Int) {
        settings.transcriptionPrompts.move(fromOffsets: source, toOffset: destination)
        settings.savePrompts()
    }
}

struct PromptEditSheet: View {
    @Environment(\.dismiss) var dismiss
    let prompt: TranscriptionPrompt?
    let onSave: (TranscriptionPrompt) -> Void

    @State private var name: String = ""
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Navn", text: $name)
                } header: {
                    Text("Prompt Navn")
                } footer: {
                    Text("F.eks. \"Uddrag pointer\" eller \"Mødereferat\"")
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                } header: {
                    Text("Prompt Tekst")
                } footer: {
                    Text("Denne tekst vil blive foranstillet den transkriberede tekst. F.eks. \"Uddrag pointerne i følgende transkriberede tekst, og giv dem i punktform:\\n\\n\"")
                }

                Section {
                    Button("Eksempler") {
                        showExamples()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(prompt == nil ? "Ny Prompt" : "Rediger Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuller") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gem") {
                        savePrompt()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let prompt = prompt {
                    name = prompt.name
                    text = prompt.text
                }
            }
        }
    }

    private func savePrompt() {
        let newPrompt = TranscriptionPrompt(
            id: prompt?.id ?? UUID(),
            name: name,
            text: text
        )
        onSave(newPrompt)
        dismiss()
    }

    private func showExamples() {
        // Cycle through example prompts
        let examples = TranscriptionPrompt.defaultPrompts.filter { !$0.text.isEmpty }
        if let currentIndex = examples.firstIndex(where: { $0.text == text }) {
            let nextIndex = (currentIndex + 1) % examples.count
            name = examples[nextIndex].name
            text = examples[nextIndex].text
        } else if !examples.isEmpty {
            name = examples[0].name
            text = examples[0].text
        }
    }
}

#Preview {
    NavigationStack {
        PromptsEditorView()
    }
}
