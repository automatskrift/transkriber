//
//  RecordingDetailView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import AVFoundation
import AVKit
import Combine

struct RecordingDetailView: View {
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayerService()
    @State private var showingShareSheet = false
    @State private var isRefreshing = false
    @State private var showingMetadataJSON = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recording.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

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
                } else {
                    // Debug: Show why audio player is not available
                    VStack(alignment: .leading, spacing: 8) {
                        Label(NSLocalizedString("Audio ikke tilgængelig", comment: ""), systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text(String(format: NSLocalizedString("Lydfil: %@", comment: ""), recording.localURL.lastPathComponent))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(String(format: NSLocalizedString("Sti: %@", comment: ""), recording.localURL.path))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onAppear {
                        print("🔍 Audio file not found:")
                        print("   Expected path: \(recording.localURL.path)")
                        print("   File exists: \(FileManager.default.fileExists(atPath: recording.localURL.path))")

                        // Check if file exists in Documents root
                        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let alternativeURL = documentsDir.appendingPathComponent(recording.fileName)
                        print("   Alternative path: \(alternativeURL.path)")
                        print("   Alternative exists: \(FileManager.default.fileExists(atPath: alternativeURL.path))")
                    }
                }

                // Metadata section (always visible)
                metadataSection

                // Marks section (if available)
                if let marks = recording.marks, !marks.isEmpty {
                    marksSection(marks)
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
        .navigationTitle(NSLocalizedString("Detaljer", comment: ""))
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
        .sheet(isPresented: $showingMetadataJSON) {
            MetadataJSONView(recording: recording)
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

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(NSLocalizedString("Metadata", comment: ""), systemImage: "info.circle")
                .font(.headline)
                .onAppear {
                    print("📋 Recording Metadata:")
                    print("   Title: \(recording.title)")
                    print("   Tags: \(recording.tags)")
                    print("   Notes: \(recording.notes ?? "nil")")
                    print("   PromptPrefix: \(recording.promptPrefix ?? "nil")")
                }

            VStack(alignment: .leading, spacing: 12) {
                // Title
                HStack(alignment: .top) {
                    Text(NSLocalizedString("Titel:", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(recording.title)
                        .font(.subheadline)
                }

                // Tags
                HStack(alignment: .top) {
                    Text(NSLocalizedString("Tags:", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    if recording.tags.isEmpty {
                        Text(NSLocalizedString("Ingen", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(recording.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                // Notes
                HStack(alignment: .top) {
                    Text(NSLocalizedString("Noter:", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    if let notes = recording.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                    } else {
                        Text(NSLocalizedString("Ingen", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // LLM Prompt
                HStack(alignment: .top) {
                    Text(NSLocalizedString("LLM Prompt:", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    if let promptPrefix = recording.promptPrefix, !promptPrefix.isEmpty {
                        Text(promptPrefix)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    } else {
                        Text(NSLocalizedString("Ingen", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("Tags", comment: ""), systemImage: "tag")
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
            Label(NSLocalizedString("Noter", comment: ""), systemImage: "note.text")
                .font(.headline)

            Text(notes)
                .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func marksSection(_ marks: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(format: NSLocalizedString("Marks (%lld)", comment: ""), marks.count), systemImage: "flag.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(marks.enumerated()), id: \.offset) { index, timestamp in
                    HStack {
                        Text(String(format: NSLocalizedString("Mark %lld", comment: ""), index + 1))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(formatTimestamp(timestamp))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)

                    if index < marks.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func locationSection(_ locationName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("Lokation", comment: ""), systemImage: "location")
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
                        Label(NSLocalizedString("Åbn i Kort", comment: ""), systemImage: "map")
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
            Label(NSLocalizedString("Transskription", comment: ""), systemImage: "doc.text")
                .font(.headline)

            if let transcription = recording.transcriptionText {
                // Use ScrollView with Text for better performance with long text
                ScrollView {
                    Text(transcription)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 400) // Limit height for very long transcriptions
                .background(Color(.systemGray6))
                .cornerRadius(8)

                HStack {
                    // Word count
                    Text(String(format: NSLocalizedString("%lld ord", comment: ""), transcription.split(separator: " ").count))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = transcription
                    } label: {
                        Label(NSLocalizedString("Kopier tekst", comment: ""), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }

            } else if recording.cloudStatus == .transcribing {
                HStack {
                    ProgressView()
                    Text(NSLocalizedString("Transkriberes...", comment: ""))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()

            } else {
                Text(NSLocalizedString("Ingen transskription endnu", comment: ""))
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
            HStack {
                Label(NSLocalizedString("Status", comment: ""), systemImage: "info.circle")
                    .font(.headline)
                Spacer()
                Button(action: { showingMetadataJSON = true }) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Button(action: refreshStatus) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
            }

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
                    Text(NSLocalizedString("Fejlbesked:", comment: ""))
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

    private func refreshStatus() {
        isRefreshing = true

        Task {
            // Check iCloud for metadata updates
            if iCloudSyncService.shared.getRecordingsFolderURL() != nil {
                do {
                    // Trigger a metadata query update
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for animation

                    // The iCloud sync service will automatically detect changes
                    // and update the recordings list via NSMetadataQuery
                    print("🔄 Refreshing status for recording: \(recording.id)")

                    await MainActor.run {
                        isRefreshing = false
                    }
                } catch {
                    print("⚠️ Error refreshing status: \(error)")
                    await MainActor.run {
                        isRefreshing = false
                    }
                }
            } else {
                await MainActor.run {
                    isRefreshing = false
                }
            }
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
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            print("🎵 Attempting to play audio from: \(url.path)")
            print("🎵 File exists: \(FileManager.default.fileExists(atPath: url.path))")

            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()

            guard let player = player else {
                print("❌ Failed to create audio player")
                return
            }

            print("🎵 Audio duration: \(player.duration) seconds")

            let success = player.play()
            if success {
                print("✅ Audio playback started")
                isPlaying = true
                startTimer()
            } else {
                print("❌ Failed to start playback")
            }
        } catch {
            print("❌ Failed to play audio: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
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
            Task { @MainActor in
                guard let self = self, let player = self.player else { return }
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

// MARK: - Metadata JSON View
struct MetadataJSONView: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var metadataJSON: String = "Loading..."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("Metadata JSON", comment: ""))
                        .font(.headline)

                    Text(metadataJSON)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("Metadata", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Luk", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: copyToClipboard) {
                        Label(NSLocalizedString("Kopier", comment: ""), systemImage: "doc.on.doc")
                    }
                }
            }
            .onAppear {
                loadMetadataJSON()
            }
        }
    }

    private func loadMetadataJSON() {
        guard let recordingsFolder = iCloudSyncService.shared.getRecordingsFolderURL() else {
            metadataJSON = "Error: Could not find recordings folder"
            return
        }

        do {
            let metadata = try RecordingMetadata.load(for: recording.fileName, from: recordingsFolder)

            if let metadata = metadata {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                let data = try encoder.encode(metadata)
                metadataJSON = String(data: data, encoding: .utf8) ?? "Error: Could not decode JSON"
            } else {
                metadataJSON = "No metadata file found for this recording"
            }
        } catch {
            metadataJSON = "Error loading metadata: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = metadataJSON
    }
}
