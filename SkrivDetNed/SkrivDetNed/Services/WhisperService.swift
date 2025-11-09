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
            // Map our model types to WhisperKit model names
            // WhisperKit uses format: openai_whisper-{size}
            let whisperKitModelName: String
            switch modelType {
            case .tiny:
                whisperKitModelName = "openai_whisper-tiny"
            case .base:
                whisperKitModelName = "openai_whisper-base"
            case .small:
                whisperKitModelName = "openai_whisper-small"
            case .medium:
                whisperKitModelName = "openai_whisper-medium"
            case .large:
                whisperKitModelName = "openai_whisper-large-v3"
            }

            isDownloadingModel = true
            downloadingModelName = modelType.displayName
            downloadProgress = 0.0

            // First, download the model with progress callback
            print("📥 Downloading model with progress tracking: \(whisperKitModelName)")

            do {
                let modelFolder = try await WhisperKit.download(
                    variant: whisperKitModelName,
                    progressCallback: { [weak self] progress in
                        Task { @MainActor in
                            self?.downloadProgress = progress.fractionCompleted
                            let percentage = Int(progress.fractionCompleted * 100)
                            print("📊 Download progress: \(percentage)%")
                        }
                    }
                )
                print("✅ Model downloaded to: \(modelFolder.path)")
            } catch {
                print("⚠️ Download may have failed or model already exists: \(error)")
                // Continue anyway - model might already be downloaded
            }

            // Now initialize WhisperKit with the model
            print("🔧 Initializing WhisperKit with model: \(whisperKitModelName)")
            whisperKit = try await WhisperKit(
                model: whisperKitModelName,
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: true,
                download: false  // Already downloaded above
            )

            currentModel = modelType
            isDownloadingModel = false
            downloadProgress = 1.0
            print("✅ WhisperKit model loaded successfully: \(whisperKitModelName)")
        } catch {
            isDownloadingModel = false
            downloadingModelName = nil
            downloadProgress = 0.0
            print("❌ Failed to load WhisperKit: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
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
