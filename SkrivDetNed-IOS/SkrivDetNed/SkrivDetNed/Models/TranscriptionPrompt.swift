//
//  TranscriptionPrompt.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import Foundation

struct TranscriptionPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var text: String

    init(id: UUID = UUID(), name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }

    // Default prompts
    static let defaultPrompts: [TranscriptionPrompt] = [
        TranscriptionPrompt(
            name: "Ingen",
            text: ""
        ),
        TranscriptionPrompt(
            name: "Uddrag pointer",
            text: "Uddrag pointerne i følgende transkriberede tekst, og giv dem i punktform:\n\n"
        ),
        TranscriptionPrompt(
            name: "Opsummér",
            text: "Opsummér følgende transkriberede tekst kort og præcist:\n\n"
        ),
        TranscriptionPrompt(
            name: "Handlingspunkter",
            text: "Identificer alle handlingspunkter og opgaver i følgende transkriberede tekst:\n\n"
        ),
        TranscriptionPrompt(
            name: "Mødereferat",
            text: "Lav et professionelt mødereferat baseret på følgende transkriberede tekst:\n\n"
        )
    ]
}
