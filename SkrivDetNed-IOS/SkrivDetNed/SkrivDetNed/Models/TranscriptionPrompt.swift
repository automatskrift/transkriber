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
            name: NSLocalizedString("Ingen", comment: ""),
            text: ""
        ),
        TranscriptionPrompt(
            name: NSLocalizedString("Uddrag pointer", comment: ""),
            text: NSLocalizedString("Uddrag pointerne i følgende transkriberede tekst, og giv dem i punktform:\n\n", comment: "")
        ),
        TranscriptionPrompt(
            name: NSLocalizedString("Opsummér", comment: ""),
            text: NSLocalizedString("Opsummér følgende transkriberede tekst kort og præcist:\n\n", comment: "")
        ),
        TranscriptionPrompt(
            name: NSLocalizedString("Handlingspunkter", comment: ""),
            text: NSLocalizedString("Identificer alle handlingspunkter og opgaver i følgende transkriberede tekst:\n\n", comment: "")
        ),
        TranscriptionPrompt(
            name: NSLocalizedString("Mødereferat", comment: ""),
            text: NSLocalizedString("Lav et professionelt mødereferat baseret på følgende transkriberede tekst:\n\n", comment: "")
        )
    ]
}
