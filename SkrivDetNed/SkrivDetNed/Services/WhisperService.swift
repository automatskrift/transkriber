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
    private var lastReportedProgress: Double = 0.0

    private init() {}

    func loadModel(_ modelType: WhisperModelType) async throws {
        print("🔄 Loading WhisperKit model: \(modelType.displayName)")

        do {
            // Map our model types to WhisperKit model names
            // Use simple names as shown in WhisperKit README
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

            print("🔧 Initializing WhisperKit with model: \(whisperKitModelName)")
            print("   (WhisperKit will auto-download if needed)")

            // Initialize WhisperKit - let it handle download internally
            // Note: WhisperKit doesn't expose progress for download in init, only in .download() method
            whisperKit = try await WhisperKit(
                model: whisperKitModelName,
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: true,
                download: true  // Let WhisperKit handle download
            )

            print("✅ WhisperKit initialized successfully")

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
        currentProgress = 0.0
        defer {
            isTranscribing = false
            currentProgress = 0.0
        }

        print("🎙️ Starting transcription with WhisperKit...")

        do {
            // Get settings
            let settings = AppSettings.shared

            // Determine language
            let language: String? = settings.whisperAutoDetectLanguage ? nil : settings.selectedLanguage
            print("🌍 Language: \(language ?? "auto-detect")")

            // Determine task (transcribe or translate)
            let task: DecodingTask = settings.whisperTranslateToEnglish ? .translate : .transcribe
            print("📝 Task: \(task == .translate ? "translate to English" : "transcribe")")

            // Create decode options with all settings
            let decodeOptions = DecodingOptions(
                verbose: true,
                task: task,
                language: language,
                temperature: Float(settings.whisperTemperature),
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 5,
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: !settings.whisperInitialPrompt.isEmpty,
                usePrefillCache: true,
                detectLanguage: settings.whisperAutoDetectLanguage,
                skipSpecialTokens: true,
                withoutTimestamps: !settings.whisperIncludeTimestamps,
                wordTimestamps: settings.whisperWordLevelTimestamps,
                maxInitialTimestamp: nil,
                maxWindowSeek: nil,
                clipTimestamps: [],
                windowClipTime: 30.0,
                promptTokens: nil,
                prefixTokens: nil,
                suppressBlank: true,
                supressTokens: [],
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.0,
                firstTokenLogProbThreshold: nil,
                noSpeechThreshold: 0.6,
                concurrentWorkerCount: settings.whisperThreadCount,
                chunkingStrategy: nil
            )

            print("⚙️ Settings: temp=\(settings.whisperTemperature), timestamps=\(settings.whisperIncludeTimestamps), wordTimestamps=\(settings.whisperWordLevelTimestamps), workers=\(settings.whisperThreadCount)")

            // Transcribe with WhisperKit and progress callback
            lastReportedProgress = 0.0
            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: decodeOptions,
                callback: { [weak self] transcriptionProgress in
                    Task { @MainActor in
                        guard let self = self else { return }

                        // TranscriptionProgress contains: timings, text, tokens, windowId
                        // Use windowId to estimate progress (each window is a chunk of audio)
                        let currentWindow = Double(transcriptionProgress.windowId)
                        // Rough estimation: assume ~10-20 windows for typical audio
                        // Cap at 95% until we're actually done
                        let estimatedProgress = min(currentWindow / 15.0, 0.95)

                        // Only update if progress changed by at least 5% to avoid excessive UI updates
                        if abs(estimatedProgress - self.lastReportedProgress) >= 0.05 {
                            self.lastReportedProgress = estimatedProgress
                            self.currentProgress = estimatedProgress
                            progress(estimatedProgress)
                            print("📊 Transcription progress: \(Int(estimatedProgress * 100))% (window \(transcriptionProgress.windowId))")
                        }
                    }
                    return nil
                }
            )

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

            currentProgress = 1.0
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
