//
//  WhisperService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import WhisperKit
import Combine

struct TranscriptionSegment {
    let start: Double
    let end: Double
    let text: String
}

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
}

@MainActor
class WhisperService: ObservableObject {
    static let shared = WhisperService()

    @Published var isTranscribing = false
    @Published var currentProgress: Double = 0.0
    @Published var isDownloadingModel = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModelName: String?

    private var whisperKit: WhisperKit?
    private var currentModel: WhisperModelType?

    private init() {}

    func loadModel(_ modelType: WhisperModelType) async throws {
        print("🔄 Loading WhisperKit model: \(modelType.displayName)")

        do {
            // Initialize WhisperKit - it will download the model automatically if needed
            // Map our model types to WhisperKit model names
            let whisperKitModelName: String
            switch modelType {
            case .tiny:
                whisperKitModelName = "tiny"
            case .base:
                whisperKitModelName = "base"
            case .small:
                whisperKitModelName = "small"
            case .medium:
                whisperKitModelName = "medium"
            case .large:
                whisperKitModelName = "large-v3"
            }

            isDownloadingModel = true
            downloadingModelName = modelType.displayName
            downloadProgress = 0.0

            whisperKit = try await WhisperKit(
                model: whisperKitModelName,
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: true,
                download: true
            )

            currentModel = modelType
            isDownloadingModel = false
            downloadProgress = 1.0
            print("✅ WhisperKit model loaded successfully: \(whisperKitModelName)")
        } catch {
            isDownloadingModel = false
            downloadingModelName = nil
            print("❌ Failed to load WhisperKit: \(error)")
            throw WhisperError.modelNotDownloaded
        }
    }

    func transcribe(
        audioURL: URL,
        modelType: WhisperModelType,
        progress: @escaping (Double) -> Void
    ) async throws -> TranscriptionResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperError.fileNotFound
        }

        // Load model if not already loaded or different model requested
        if whisperKit == nil || currentModel != modelType {
            try await loadModel(modelType)
        }

        guard let whisperKit = whisperKit else {
            throw WhisperError.modelNotDownloaded
        }

        isTranscribing = true
        defer { isTranscribing = false }

        print("🎙️ Starting transcription with WhisperKit...")

        do {
            // Transcribe with WhisperKit
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)

            // Extract text and segments from first result
            guard let firstResult = results.first else {
                throw WhisperError.transcriptionFailed("No transcription result")
            }

            let fullText = firstResult.text
            let segments = firstResult.segments.map { segment in
                TranscriptionSegment(
                    start: Double(segment.start),
                    end: Double(segment.end),
                    text: segment.text
                )
            }

            print("✅ Transcription complete: \(segments.count) segments")

            progress(1.0)
            return TranscriptionResult(text: fullText, segments: segments)

        } catch {
            print("❌ WhisperKit transcription failed: \(error)")
            throw WhisperError.transcriptionFailed(error.localizedDescription)
        }
    }

    func cancelTranscription() {
        isTranscribing = false
        currentProgress = 0.0
    }
}

enum WhisperError: LocalizedError {
    case modelNotDownloaded
    case fileNotFound
    case transcriptionFailed(String)
    case authorizationDenied
    case recognizerNotAvailable

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Whisper model er ikke downloadet. Download modellen i indstillinger."
        case .fileNotFound:
            return "Lydfil ikke fundet"
        case .transcriptionFailed(let error):
            return "Transskription fejlede: \(error)"
        case .authorizationDenied:
            return "Mikrofonadgang nægtet"
        case .recognizerNotAvailable:
            return "Talegenkendelse ikke tilgængelig"
        }
    }
}
