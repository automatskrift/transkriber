//
//  RecordingLiveActivityWidget.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import SwiftUI
import ActivityKit
import WidgetKit

@available(iOS 16.1, *)
struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen/banner UI
            RecordingLiveActivityView(context: context)
                .activityBackgroundTint(Color.blue.opacity(0.2))
                .activitySystemActionForegroundColor(Color.blue)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "waveform.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Optager")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(context.state.fileName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if context.state.isPaused {
                            Text(timerInterval: context.attributes.startTime...context.state.pausedAt!, pauseTime: context.state.pausedAt)
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()
                            Text("Pause")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Waveform visualization
                        HStack(spacing: 2) {
                            ForEach(0..<12, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(context.state.isPaused ? Color.orange.opacity(0.3) : Color.red.opacity(0.8))
                                    .frame(width: 3, height: CGFloat.random(in: 8...24))
                            }
                        }
                        .frame(height: 30)
                    }
                    .padding(.top, 8)
                }

            } compactLeading: {
                // Compact leading (left side of notch)
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "waveform.circle.fill")
                    .foregroundColor(context.state.isPaused ? .orange : .red)
                    .font(.system(size: 18))

            } compactTrailing: {
                // Compact trailing (right side of notch)
                if context.state.isPaused, let pausedAt = context.state.pausedAt {
                    Text(timerInterval: context.attributes.startTime...pausedAt, pauseTime: pausedAt)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                } else {
                    Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }

            } minimal: {
                // Minimal (when multiple activities)
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

@available(iOS 16.1, *)
struct RecordingLiveActivityView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Recording icon
            ZStack {
                Circle()
                    .fill(context.state.isPaused ? Color.orange : Color.red)
                    .frame(width: 44, height: 44)

                Image(systemName: context.state.isPaused ? "pause.fill" : "waveform")
                    .foregroundColor(.white)
                    .font(.title3)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isPaused ? "Optagelse sat på pause" : "Optager...")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(context.state.fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                if context.state.isPaused, let pausedAt = context.state.pausedAt {
                    Text(timerInterval: context.attributes.startTime...pausedAt, pauseTime: pausedAt)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Text(formatTime(context.attributes.startTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Startede \(formatter.string(from: date))"
    }
}

@available(iOS 16.1, *)
#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: RecordingActivityAttributes(startTime: Date().addingTimeInterval(-125))) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingActivityAttributes.ContentState(isPaused: false, fileName: "Møde.m4a", pausedAt: nil, totalPausedDuration: 0)
    RecordingActivityAttributes.ContentState(isPaused: true, fileName: "Lang optagelse.m4a", pausedAt: Date(), totalPausedDuration: 0)
}

@available(iOS 16.1, *)
#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: RecordingActivityAttributes(startTime: Date().addingTimeInterval(-125))) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingActivityAttributes.ContentState(isPaused: false, fileName: "Møde.m4a", pausedAt: nil, totalPausedDuration: 0)
}

@available(iOS 16.1, *)
#Preview("Lock Screen", as: .content, using: RecordingActivityAttributes(startTime: Date().addingTimeInterval(-125))) {
    RecordingLiveActivityWidget()
} contentStates: {
    RecordingActivityAttributes.ContentState(isPaused: false, fileName: "Møde.m4a", pausedAt: nil, totalPausedDuration: 0)
    RecordingActivityAttributes.ContentState(isPaused: true, fileName: "Lang optagelse.m4a", pausedAt: Date(), totalPausedDuration: 0)
}
