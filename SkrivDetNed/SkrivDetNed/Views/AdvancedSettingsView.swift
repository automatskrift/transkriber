//
//  AdvancedSettingsView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("Avancerede Whisper Indstillinger", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Language Detection
                    GroupBox(label: Label(NSLocalizedString("Sprog", comment: ""), systemImage: "globe")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(NSLocalizedString("Auto-detektér sprog", comment: ""), isOn: $settings.whisperAutoDetectLanguage)

                            if !settings.whisperAutoDetectLanguage {
                                HStack {
                                    Text(NSLocalizedString("Valgt sprog:", comment: ""))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(languageName(for: settings.selectedLanguage))
                                        .foregroundColor(.primary)
                                }
                            }

                            Text(NSLocalizedString("Når aktiveret, vil Whisper automatisk detektere sproget i lydoptagelsen.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Translation
                    GroupBox(label: Label(NSLocalizedString("Oversættelse", comment: ""), systemImage: "character.book.closed")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(NSLocalizedString("Oversæt til engelsk", comment: ""), isOn: $settings.whisperTranslateToEnglish)

                            Text(NSLocalizedString("Transskriberer og oversætter automatisk alt indhold til engelsk.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Temperature
                    GroupBox(label: Label(NSLocalizedString("Temperatur", comment: ""), systemImage: "thermometer.medium")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("Temperatur", comment: "") + ":")
                                Spacer()
                                Text(String(format: "%.1f", settings.whisperTemperature))
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $settings.whisperTemperature, in: 0.0...1.0, step: 0.1)

                            HStack {
                                Text(NSLocalizedString("Konsistent (0.0)", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(NSLocalizedString("Kreativ (1.0)", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(NSLocalizedString("Lavere værdier giver mere konsistente resultater. Højere værdier kan hjælpe ved dårlig lydkvalitet.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Initial Prompt
                    GroupBox(label: Label(NSLocalizedString("Kontekst", comment: ""), systemImage: "text.bubble")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("Initial prompt (valgfri):", comment: ""))
                                    .font(.subheadline)
                                Spacer()
                                Text("\(settings.whisperInitialPrompt.count)/1000")
                                    .font(.caption)
                                    .foregroundColor(settings.whisperInitialPrompt.count > 1000 ? .red : .secondary)
                            }

                            TextEditor(text: Binding(
                                get: { settings.whisperInitialPrompt },
                                set: { newValue in
                                    if newValue.count <= 1000 {
                                        settings.whisperInitialPrompt = newValue
                                    } else {
                                        settings.whisperInitialPrompt = String(newValue.prefix(1000))
                                    }
                                }
                            ))
                                .frame(height: 80)
                                .font(.body)
                                .padding(4)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)

                            Text(NSLocalizedString("Hjælper Whisper med kontekst, f.eks. navne, fagtermer eller emnet for optagelsen. Eksempel: \"Dette er et møde om softwareudvikling med Tomas og Anders.\" (Maks 1000 tegn)", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Timestamps
                    GroupBox(label: Label(NSLocalizedString("Tidsstempler", comment: ""), systemImage: "clock")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(NSLocalizedString("Inkludér tidsstempler", comment: ""), isOn: $settings.whisperIncludeTimestamps)

                            Toggle(NSLocalizedString("Ord-niveau tidsstempler", comment: ""), isOn: $settings.whisperWordLevelTimestamps)
                                .disabled(!settings.whisperIncludeTimestamps)

                            if settings.whisperIncludeTimestamps {
                                Text(NSLocalizedString("Format: [00:01:23.456] Tekst her", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if settings.whisperWordLevelTimestamps {
                                    Text(NSLocalizedString("Hvert ord får sit eget tidsstempel for præcis navigation.", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(8)
                    }

                    // Performance
                    GroupBox(label: Label(NSLocalizedString("Ydeevne", comment: ""), systemImage: "cpu")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("Samtidige workers:", comment: ""))
                                Spacer()
                                Text("\(settings.whisperThreadCount)")
                                    .foregroundColor(.secondary)
                            }

                            Stepper("", value: $settings.whisperThreadCount, in: 1...8)
                                .labelsHidden()

                            Text(NSLocalizedString("Flere workers kan øge hastigheden på kraftige Macs, men bruger mere hukommelse.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Divider()

                            Toggle(NSLocalizedString("Automatisk frigør hukommelse efter 5 minutter", comment: "Auto-unload model setting"), isOn: $settings.autoUnloadModel)

                            Text(NSLocalizedString("Frigører modellen fra hukommelsen efter 5 minutters inaktivitet. Anbefales for at spare RAM, især ved brug af Large modellen.", comment: "Auto-unload description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Reset button
                    HStack {
                        Spacer()
                        Button(action: resetToDefaults) {
                            Label(NSLocalizedString("Nulstil til standardværdier", comment: ""), systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }

    private func languageName(for code: String) -> String {
        let locale = Locale(identifier: "da")
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }

    private func resetToDefaults() {
        settings.whisperTemperature = 0.0
        settings.autoUnloadModel = true
        settings.whisperTranslateToEnglish = false
        settings.whisperInitialPrompt = ""
        settings.whisperIncludeTimestamps = false
        settings.whisperWordLevelTimestamps = false
        settings.whisperThreadCount = 1
        settings.whisperAutoDetectLanguage = false
    }
}

#Preview {
    AdvancedSettingsView()
}
