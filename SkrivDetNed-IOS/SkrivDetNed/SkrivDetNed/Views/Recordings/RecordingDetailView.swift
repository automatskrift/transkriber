//
//  RecordingDetailView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import AVFoundation
import Combine

struct RecordingDetailView: View {
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayerService()
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Label(recording.formattedDate, systemImage: "calendar")
                        Spacer()
                        Label(recording.formattedFileSize, systemImage: "doc")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Audio player
                if FileManager.default.fileExists(atPath: recording.localURL.path) {
                    audioPlayerSection
                }

                // Tags
                if !recording.tags.isEmpty {
                    tagsSection
                }

                // Notes
                if let notes = recording.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                // Location
                if let locationName = recording.locationName {
                    locationSection(locationName)
                }

                // Transcription
                transcriptionSection

                // Status
                statusSection
            }
            .padding()
        }
        .navigationTitle("Detaljer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(recording: recording)
        }
    }

    private var audioPlayerSection: some View {
        VStack(spacing: 16) {
            // Waveform or progress
            ProgressView(value: audioPlayer.currentTime, total: recording.duration)
                .tint(.blue)

            // Time labels
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                Spacer()
                Text(formatTime(recording.duration))
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundColor(.secondary)

            // Playback controls
            HStack(spacing: 40) {
                Button {
                    audioPlayer.skipBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }

                Button {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play(url: recording.localURL)
                    }
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }

                Button {
                    audioPlayer.skipForward()
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tags", systemImage: "tag")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(recording.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Noter", systemImage: "note.text")
                .font(.headline)

            Text(notes)
                .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func locationSection(_ locationName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lokation", systemImage: "location")
                .font(.headline)

            HStack {
                Text(locationName)
                    .font(.body)

                Spacer()

                // Show map button if coordinates available
                if let lat = recording.latitude, let lon = recording.longitude {
                    Button {
                        let urlString = "maps://?ll=\(lat),\(lon)"
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Åbn i Kort", systemImage: "map")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transskription", systemImage: "doc.text")
                .font(.headline)

            if let transcription = recording.transcriptionText {
                Text(transcription)
                    .font(.body)
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = transcription
                } label: {
                    Label("Kopier tekst", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            } else if recording.cloudStatus == .transcribing {
                HStack {
                    ProgressView()
                    Text("Transkriberes...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()

            } else {
                Text("Ingen transskription endnu")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Status", systemImage: "info.circle")
                .font(.headline)

            HStack {
                Image(systemName: recording.cloudStatus.icon)
                    .foregroundColor(statusColor)
                Text(recording.cloudStatus.displayName)
                    .foregroundColor(statusColor)
                Spacer()
            }

            // Show error message if failed
            if recording.cloudStatus == .failed, let errorMessage = recording.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fejlbesked:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch recording.cloudStatus.color {
        case "gray": return .gray
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            height = y + lineHeight
        }
    }
}

// Simple audio player service
@MainActor
class AudioPlayerService: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            print("❌ Failed to play audio: \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func skipForward() {
        guard let player = player else { return }
        player.currentTime = min(player.currentTime + 15, player.duration)
    }

    func skipBackward() {
        guard let player = player else { return }
        player.currentTime = max(player.currentTime - 15, 0)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            Task { @MainActor in
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    NavigationStack {
        RecordingDetailView(recording: {
            var rec = Recording(
                fileName: "meeting.m4a",
                localURL: URL(fileURLWithPath: "/tmp/meeting.m4a"),
                duration: 3665,
                fileSize: 5242880
            )
            rec.title = "Møde med team"
            rec.tags = ["møde", "arbejde", "vigtig"]
            rec.notes = "Diskuterede projektplanlægning og deadlines for Q1"
            rec.cloudStatus = .completed
            rec.transcriptionText = "Dette er en test transskription af mødet..."
            return rec
        }())
    }
}
