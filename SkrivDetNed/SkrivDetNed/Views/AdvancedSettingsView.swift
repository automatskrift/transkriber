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
                Text("Avancerede Whisper Indstillinger")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Language Detection
                    GroupBox(label: Label("Sprog", systemImage: "globe")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Auto-detektér sprog", isOn: $settings.whisperAutoDetectLanguage)

                            if !settings.whisperAutoDetectLanguage {
                                HStack {
                                    Text("Valgt sprog:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(languageName(for: settings.selectedLanguage))
                                        .foregroundColor(.primary)
                                }
                            }

                            Text("Når aktiveret, vil Whisper automatisk detektere sproget i lydoptagelsen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Translation
                    GroupBox(label: Label("Oversættelse", systemImage: "character.book.closed")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Oversæt til engelsk", isOn: $settings.whisperTranslateToEnglish)

                            Text("Transskriberer og oversætter automatisk alt indhold til engelsk.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Temperature
                    GroupBox(label: Label("Temperatur", systemImage: "thermometer.medium")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Temperatur:")
                                Spacer()
                                Text(String(format: "%.1f", settings.whisperTemperature))
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $settings.whisperTemperature, in: 0.0...1.0, step: 0.1)

                            HStack {
                                Text("Konsistent (0.0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Kreativ (1.0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Lavere værdier giver mere konsistente resultater. Højere værdier kan hjælpe ved dårlig lydkvalitet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Initial Prompt
                    GroupBox(label: Label("Kontekst", systemImage: "text.bubble")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Initial prompt (valgfri):")
                                .font(.subheadline)

                            TextEditor(text: $settings.whisperInitialPrompt)
                                .frame(height: 80)
                                .font(.body)
                                .padding(4)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)

                            Text("Hjælper Whisper med kontekst, f.eks. navne, fagtermer eller emnet for optagelsen. Eksempel: \"Dette er et møde om softwareudvikling med Tomas og Anders.\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Timestamps
                    GroupBox(label: Label("Tidsstempler", systemImage: "clock")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Inkludér tidsstempler", isOn: $settings.whisperIncludeTimestamps)

                            Toggle("Ord-niveau tidsstempler", isOn: $settings.whisperWordLevelTimestamps)
                                .disabled(!settings.whisperIncludeTimestamps)

                            if settings.whisperIncludeTimestamps {
                                Text("Format: [00:01:23.456] Tekst her")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if settings.whisperWordLevelTimestamps {
                                    Text("Hvert ord får sit eget tidsstempel for præcis navigation.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(8)
                    }

                    // Performance
                    GroupBox(label: Label("Ydeevne", systemImage: "cpu")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("CPU tråde:")
                                Spacer()
                                Text(settings.whisperThreadCount == 0 ? "Auto" : "\(settings.whisperThreadCount)")
                                    .foregroundColor(.secondary)
                            }

                            Picker("", selection: $settings.whisperThreadCount) {
                                Text("Auto (Anbefalet)").tag(0)
                                Text("1 tråd").tag(1)
                                Text("2 tråde").tag(2)
                                Text("4 tråde").tag(4)
                                Text("8 tråde").tag(8)
                            }
                            .pickerStyle(.segmented)

                            Text("Auto vælger automatisk baseret på din CPU. Færre tråde bruger mindre batteri.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Segment Length
                    GroupBox(label: Label("Segment længde", systemImage: "waveform")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Max segment længde:")
                                Spacer()
                                Text(settings.whisperMaxSegmentLength == 0 ? "Standard" : "\(settings.whisperMaxSegmentLength)s")
                                    .foregroundColor(.secondary)
                            }

                            Picker("", selection: $settings.whisperMaxSegmentLength) {
                                Text("Standard (Anbefalet)").tag(0)
                                Text("10 sekunder").tag(10)
                                Text("20 sekunder").tag(20)
                                Text("30 sekunder").tag(30)
                                Text("60 sekunder").tag(60)
                            }
                            .pickerStyle(.segmented)

                            Text("Kortere segmenter processeres hurtigere, men kan miste kontekst mellem segmenter.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Reset button
                    HStack {
                        Spacer()
                        Button(action: resetToDefaults) {
                            Label("Nulstil til standardværdier", systemImage: "arrow.counterclockwise")
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
        settings.whisperTranslateToEnglish = false
        settings.whisperInitialPrompt = ""
        settings.whisperIncludeTimestamps = false
        settings.whisperWordLevelTimestamps = false
        settings.whisperThreadCount = 0
        settings.whisperMaxSegmentLength = 0
        settings.whisperAutoDetectLanguage = false
    }
}

#Preview {
    AdvancedSettingsView()
}
