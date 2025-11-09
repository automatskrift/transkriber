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
    @State private var showingCancelConfirmation = false
    @State private var showRecordingUI = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 40)

                    // Large record button
                    RecordButton(
                        isRecording: viewModel.isRecording,
                        isPaused: viewModel.isPaused,
                        action: { viewModel.toggleRecording() }
                    )

                // Waveform visualization
                ZStack {
                    if viewModel.isRecording {
                        WaveformView(levels: viewModel.audioLevels)
                            .frame(height: 100)
                            .padding(.horizontal)
                    } else if viewModel.isInitializingRecording {
                        ProgressView("Forbereder optagelse...")
                            .frame(height: 100)
                    }
                }
                .frame(height: (viewModel.isRecording || viewModel.isInitializingRecording) ? 100 : 0)
                .opacity((viewModel.isRecording || viewModel.isInitializingRecording) ? (showRecordingUI ? 1 : 0) : 0)
                .animation(.easeIn(duration: 0.4), value: showRecordingUI)

                // Timer and file size
                VStack(spacing: 8) {
                    Text(viewModel.formattedDuration)
                        .font(.system(size: 48, weight: .thin, design: .rounded))
                        .monospacedDigit()

                    if viewModel.isRecording || viewModel.isInitializingRecording {
                        Text(viewModel.estimatedFileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Control buttons
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
                    .disabled(viewModel.isInitializingRecording)

                    // Mark button
                    Button(action: { viewModel.addMark() }) {
                        Label("Mark", systemImage: "flag.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isInitializingRecording || viewModel.isPaused)

                    // Cancel button
                    Button(role: .destructive, action: {
                        if viewModel.duration > 3 {
                            showingCancelConfirmation = true
                        } else {
                            viewModel.cancelRecording()
                        }
                    }) {
                        Label("Annuller", systemImage: "xmark")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isInitializingRecording)
                }
                .frame(height: (viewModel.isRecording || viewModel.isInitializingRecording) ? nil : 0)
                .opacity((viewModel.isRecording || viewModel.isInitializingRecording) ? (showRecordingUI ? 1 : 0) : 0)
                .animation(.easeIn(duration: 0.4).delay(0.1), value: showRecordingUI)

                // Metadata input (when recording)
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("LLM Prompt (valgfri)", systemImage: "brain")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        NavigationLink(destination: PromptSelectionView(selectedPrompt: $viewModel.selectedPrompt)) {
                            HStack {
                                Text(viewModel.selectedPrompt?.name ?? "Ingen")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

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
                .frame(height: (viewModel.isRecording || viewModel.isInitializingRecording) ? nil : 0)
                .clipped()
                .opacity((viewModel.isRecording || viewModel.isInitializingRecording) ? (showRecordingUI ? 1 : 0) : 0)
                .disabled(viewModel.isInitializingRecording)
                .animation(.easeIn(duration: 0.4).delay(0.2), value: showRecordingUI)

                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    // Dismiss keyboard when tapping outside text fields
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
            .navigationTitle("Optag")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.isRecording) { _, newValue in
                if newValue {
                    // When recording starts, trigger fade-in animation
                    withAnimation {
                        showRecordingUI = true
                    }
                } else {
                    // Reset when recording stops
                    showRecordingUI = false
                }
            }
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
            .alert("Annuller optagelse?", isPresented: $showingCancelConfirmation) {
                Button("Fortsæt optagelse", role: .cancel) {}
                Button("Annuller", role: .destructive) {
                    viewModel.cancelRecording()
                }
            } message: {
                Text("Er du sikker på at du vil annullere denne optagelse? Dette kan ikke fortrydes.")
            }
        }
    }
}

#Preview {
    RecordingView()
}
