//
//  RecordingView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // Large record button
                RecordButton(
                    isRecording: viewModel.isRecording,
                    isPaused: viewModel.isPaused,
                    action: { viewModel.toggleRecording() }
                )

                // Waveform visualization
                if viewModel.isRecording {
                    WaveformView(levels: viewModel.audioLevels)
                        .frame(height: 100)
                        .padding(.horizontal)
                }

                // Timer and file size
                VStack(spacing: 8) {
                    Text(viewModel.formattedDuration)
                        .font(.system(size: 48, weight: .thin, design: .rounded))
                        .monospacedDigit()

                    Text(viewModel.estimatedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Control buttons
                if viewModel.isRecording {
                    HStack(spacing: 40) {
                        // Pause/Resume button
                        Button(action: { viewModel.togglePause() }) {
                            Label(
                                viewModel.isPaused ? "Fortsæt" : "Pause",
                                systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                            )
                            .font(.headline)
                        }
                        .buttonStyle(.bordered)

                        // Cancel button
                        Button(role: .destructive, action: { viewModel.cancelRecording() }) {
                            Label("Annuller", systemImage: "xmark")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()

                // Metadata input (when recording)
                if viewModel.isRecording {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Titel (valgfri)", systemImage: "text.cursor")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("F.eks. Møde med team", text: $viewModel.recordingTitle)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Tags (valgfri)", systemImage: "tag")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("F.eks. #møde #arbejde", text: $viewModel.recordingTags)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Noter (valgfri)", systemImage: "note.text")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextEditor(text: $viewModel.recordingNotes)
                                .frame(height: 80)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Optag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .alert("Fejl", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Ukendt fejl")
            }
            .alert("Optagelse gemt", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Din optagelse er gemt og bliver nu uploadet til iCloud.")
            }
        }
    }
}

#Preview {
    RecordingView()
}
