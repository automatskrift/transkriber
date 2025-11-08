//
//  WaveformView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct WaveformView: View {
    let levels: [Float]

    private let barCount = 50
    private let barSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: barWidth(geometry: geometry), height: barHeight(for: index, geometry: geometry))
                        .animation(.easeOut(duration: 0.1), value: levels)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = barSpacing * CGFloat(barCount - 1)
        let availableWidth = geometry.size.width - totalSpacing
        return availableWidth / CGFloat(barCount)
    }

    private func barHeight(for index: Int, geometry: GeometryProxy) -> CGFloat {
        let maxHeight = geometry.size.height

        // Get the audio level for this bar
        // We have up to 100 samples in levels array, map to barCount
        let sampleIndex = Int(CGFloat(index) / CGFloat(barCount) * CGFloat(levels.count))

        guard sampleIndex < levels.count else {
            return 4 // Minimum height
        }

        let level = levels[sampleIndex]

        // Normalize level from dB (-160 to 0) to 0-1
        let normalizedLevel = max(0, min(1, (level + 160) / 160))

        // Apply some smoothing and minimum height
        let height = max(4, CGFloat(normalizedLevel) * maxHeight)

        return height
    }

    private func barColor(for index: Int) -> Color {
        // Gradient from green to yellow to red
        let position = Float(index) / Float(barCount)

        if position < 0.6 {
            return .green
        } else if position < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    VStack {
        // Simulate some audio levels
        WaveformView(levels: (0..<100).map { _ in Float.random(in: -160...0) })
            .frame(height: 100)
            .padding()

        WaveformView(levels: (0..<100).map { index in
            // Simulate a wave pattern
            let wave = sin(Float(index) * 0.2) * 80
            return wave - 80
        })
        .frame(height: 100)
        .padding()

        // Empty state
        WaveformView(levels: [])
            .frame(height: 100)
            .padding()
    }
}
