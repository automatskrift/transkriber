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
    @State private var markButtonPressed = false
    @State private var showingHelp = false

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
                        ProgressView(NSLocalizedString("Forbereder optagelse...", comment: ""))
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
                HStack(spacing: 16) {
                    // Pause/Resume button
                    Button(action: { viewModel.togglePause() }) {
                        VStack(spacing: 6) {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                                .font(.title2)
                            Text(viewModel.isPaused ? NSLocalizedString("Fortsæt", comment: "") : NSLocalizedString("Pause", comment: ""))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(minWidth: 80)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isInitializingRecording)

                    // Mark button with feedback
                    Button(action: {
                        viewModel.addMark()
                        // Trigger visual feedback
                        markButtonPressed = true
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        // Reset animation after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            markButtonPressed = false
                        }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: "flag.fill")
                                .font(.title2)
                            Text(NSLocalizedString("Mark", comment: ""))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(minWidth: 70)
                    }
                    .buttonStyle(.bordered)
                    .tint(markButtonPressed ? .orange : .blue)
                    .scaleEffect(markButtonPressed ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: markButtonPressed)
                    .disabled(viewModel.isInitializingRecording || viewModel.isPaused)

                    // Cancel button
                    Button(role: .destructive, action: {
                        if viewModel.duration > 3 {
                            showingCancelConfirmation = true
                        } else {
                            viewModel.cancelRecording()
                        }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.title2)
                            Text(NSLocalizedString("Annuller", comment: ""))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(minWidth: 80)
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
                        Label(NSLocalizedString("LLM Prompt (valgfri)", comment: ""), systemImage: "brain")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        NavigationLink(destination: PromptSelectionView(selectedPrompt: $viewModel.selectedPrompt)) {
                            HStack {
                                Text(viewModel.selectedPrompt?.name ?? NSLocalizedString("Ingen", comment: ""))
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
                        Label(NSLocalizedString("Titel (valgfri)", comment: ""), systemImage: "text.cursor")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField(NSLocalizedString("F.eks. Møde med team", comment: ""), text: $viewModel.recordingTitle)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(NSLocalizedString("Tags (valgfri)", comment: ""), systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField(NSLocalizedString("F.eks. #møde #arbejde", comment: ""), text: $viewModel.recordingTags)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(NSLocalizedString("Noter (valgfri)", comment: ""), systemImage: "note.text")
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
            .overlay(
                // Success toast notification
                VStack {
                    if viewModel.showSuccess {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Optagelse gemt", comment: ""))
                                    .font(.headline)
                                Text(NSLocalizedString("Uploades til iCloud", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
                .padding(.top, 100)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showSuccess)
                .onChange(of: viewModel.showSuccess) { _, newValue in
                    if newValue {
                        // Auto-dismiss after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            viewModel.showSuccess = false
                        }
                    }
                }
            )
            .navigationTitle(NSLocalizedString("Optag", comment: ""))
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpSheetView()
            }
            .alert(NSLocalizedString("Fejl", comment: ""), isPresented: $viewModel.showError) {
                Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? NSLocalizedString("Ukendt fejl", comment: ""))
            }
            .alert(NSLocalizedString("Annuller optagelse?", comment: ""), isPresented: $showingCancelConfirmation) {
                Button(NSLocalizedString("Fortsæt optagelse", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("Annuller", comment: ""), role: .destructive) {
                    viewModel.cancelRecording()
                }
            } message: {
                Text(NSLocalizedString("Er du sikker på at du vil annullere denne optagelse? Dette kan ikke fortrydes.", comment: ""))
            }
        }
    }
}

// MARK: - Help Sheet View
struct HelpSheetView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Icon
                    HStack {
                        Spacer()
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.top)

                    // Title
                    Text(NSLocalizedString("Sådan bruges appen", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)

                    // Main description
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("Denne app er designet til at arbejde sammen med macOS-appen af samme navn.", comment: ""))
                            .font(.body)

                        Text(NSLocalizedString("Sådan fungerer det:", comment: ""))
                            .font(.headline)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            HelpStepRow(
                                number: "1",
                                title: NSLocalizedString("Optag på iPhone", comment: ""),
                                description: NSLocalizedString("Tryk på den store optagelsesknap for at starte optagelse", comment: "")
                            )

                            HelpStepRow(
                                number: "2",
                                title: NSLocalizedString("Automatisk upload", comment: ""),
                                description: NSLocalizedString("Optagelsen uploades automatisk til iCloud", comment: "")
                            )

                            HelpStepRow(
                                number: "3",
                                title: NSLocalizedString("Mac transskriberer", comment: ""),
                                description: NSLocalizedString("Din Mac detecterer den nye optagelse og transskriberer den automatisk med Whisper AI", comment: "")
                            )

                            HelpStepRow(
                                number: "4",
                                title: NSLocalizedString("Hent resultat", comment: ""),
                                description: NSLocalizedString("Transskriptionen synkroniseres tilbage til din iPhone", comment: "")
                            )
                        }

                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("Du skal have macOS-appen installeret og køre for at få transskriptioner", comment: ""))
                                    .font(.callout)
                            }

                            HStack(spacing: 12) {
                                Image(systemName: "icloud.fill")
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("Sørg for at iCloud Sync er aktiveret i Indstillinger", comment: ""))
                                    .font(.callout)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("Hjælp", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Luk", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HelpStepRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                Text(number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    RecordingView()
}
