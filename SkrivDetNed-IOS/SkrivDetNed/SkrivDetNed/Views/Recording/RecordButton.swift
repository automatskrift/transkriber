//
//  RecordButton.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let isPaused: Bool
    let action: () -> Void

    @State private var isPressing = false
    @State private var pulseAnimation = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring (pulsing when recording)
                Circle()
                    .stroke(buttonColor, lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isRecording && !isPaused ? (pulseAnimation ? 1.1 : 1.0) : 1.0)
                    .opacity(isRecording && !isPaused ? (pulseAnimation ? 0.5 : 1.0) : 1.0)
                    .animation(
                        isRecording && !isPaused ?
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                        value: pulseAnimation
                    )

                // Middle ring
                Circle()
                    .stroke(buttonColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)

                // Inner button
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 80, height: 80)

                    // Stop icon when recording
                    if isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white)
                            .frame(width: 30, height: 30)
                    } else {
                        // Record icon
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    }
                }
                .scaleEffect(isPressing ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
            }
        }
        .buttonStyle(RecordButtonStyle(isPressing: $isPressing))
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                pulseAnimation = true
            } else {
                pulseAnimation = false
            }
        }
        .onAppear {
            if isRecording && !isPaused {
                pulseAnimation = true
            }
        }
    }

    private var buttonColor: Color {
        if isPaused {
            return .orange
        } else if isRecording {
            return .red
        } else {
            return .red
        }
    }
}

struct RecordButtonStyle: ButtonStyle {
    @Binding var isPressing: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressing = newValue
            }
    }
}

#Preview {
    VStack(spacing: 50) {
        RecordButton(isRecording: false, isPaused: false, action: {})
        RecordButton(isRecording: true, isPaused: false, action: {})
        RecordButton(isRecording: true, isPaused: true, action: {})
    }
    .padding()
}
