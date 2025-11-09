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

    private var whisperKit: WhisperKit?
    private var currentModel: WhisperModelType?

    private init() {}

    func loadModel(_ modelType: WhisperModelType) async throws {
        guard FileSystemHelper.shared.modelExists(modelType) else {
            throw WhisperError.modelNotDownloaded
        }

        print("🔄 Loading WhisperKit model: \(modelType.displayName)")

        do {
            whisperKit = try await WhisperKit(
                model: modelType.modelPath,
                verbose: true,
                logLevel: .debug
            )
            currentModel = modelType
            print("✅ WhisperKit model loaded successfully")
        } catch {
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
            let result = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: DecodingOptions(
                    verbose: true,
                    task: .transcribe,
                    language: AppSettings.shared.selectedLanguage,
                    temperature: Float(AppSettings.shared.whisperTemperature),
                    temperatureFallbackCount: 5,
                    sampleLength: 224,
                    skipSpecialTokens: true,
                    withoutTimestamps: false,  // We need timestamps for marks!
                    clipTimestamps: [],
                    promptTokens: nil
                )
            ) { progressUpdate in
                Task { @MainActor in
                    self.currentProgress = progressUpdate.progress
                    progress(progressUpdate.progress)
                }
            }

            // Extract text and segments
            let fullText = result?.text ?? ""
            var segments: [TranscriptionSegment] = []

            if let resultSegments = result?.segments {
                segments = resultSegments.map { segment in
                    TranscriptionSegment(
                        start: segment.start,
                        end: segment.end,
                        text: segment.text
                    )
                }
                print("✅ Transcription complete: \(segments.count) segments")
            }

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
