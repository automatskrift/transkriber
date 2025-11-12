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
    @Published var isLoadingModel = false  // Loading model after download
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModelName: String?
    @Published var downloadCompletedUnits: Int64 = 0  // Download progress: completed units
    @Published var downloadTotalUnits: Int64 = 0      // Download progress: total units
    @Published var currentTranscribingText: String = ""  // Real-time transcription preview

    private var whisperKit: WhisperKit?
    private var currentModel: WhisperModelType?
    private var lastReportedProgress: Double = 0.0
    private var isLocked = false  // Prevent concurrent transcriptions

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

            // Check if model is already downloaded
            let modelPath = getModelPath(for: whisperKitModelName)
            let isModelDownloaded = FileManager.default.fileExists(atPath: modelPath)

            if isModelDownloaded {
                // Model exists, just loading
                print("📦 Model already downloaded, loading into memory...")
                isLoadingModel = true
                downloadingModelName = modelType.displayName
            } else {
                // Model needs download
                print("⬇️ Model not found, downloading...")
                isDownloadingModel = true
                downloadingModelName = modelType.displayName
                downloadProgress = 0.0
            }

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
            isLoadingModel = false
            downloadProgress = 1.0
            print("✅ WhisperKit model loaded successfully: \(whisperKitModelName)")
        } catch {
            isDownloadingModel = false
            isLoadingModel = false
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
        // Check if already transcribing (safety check - should be prevented by queue)
        guard !isLocked else {
            print("⚠️ WhisperService is locked - another transcription is in progress")
            print("   This should not happen if TranscriptionViewModel queue is working correctly!")
            throw WhisperError.transcriptionFailed("Another transcription is already in progress")
        }

        // Lock to prevent concurrent access
        isLocked = true
        defer {
            isLocked = false
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found: \(audioURL.path)")
            throw WhisperError.fileNotFound
        }

        // Validate audio file
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("📊 Audio file size: \(fileSize) bytes")

            if fileSize == 0 {
                print("❌ Audio file is empty")
                throw WhisperError.transcriptionFailed("Audio file is empty")
            }

            if fileSize > 100_000_000 {  // 100MB
                print("⚠️ Warning: Large audio file (\(fileSize / 1_000_000)MB). This may take a while or fail.")
            }
        } catch {
            print("❌ Failed to validate audio file: \(error)")
            throw WhisperError.transcriptionFailed("Failed to validate audio file: \(error.localizedDescription)")
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
        currentTranscribingText = ""
        defer {
            isTranscribing = false
            currentProgress = 0.0
            currentTranscribingText = ""
        }

        print("🎙️ Starting transcription with WhisperKit...")
        print("📁 File: \(audioURL.lastPathComponent)")
        print("🔧 Model: \(modelType.displayName)")

        do {
            // Get settings
            let settings = AppSettings.shared

            // Determine language
            // IMPORTANT: For best results with WhisperKit:
            // - Always provide explicit language (don't use nil) unless user explicitly wants auto-detect
            // - Set detectLanguage to false when using explicit language
            // - Use usePrefillPrompt to force the language tokens
            let language: String? = settings.whisperAutoDetectLanguage ? nil : settings.selectedLanguage
            let shouldDetectLanguage = settings.whisperAutoDetectLanguage

            print("🌍 Language: \(language ?? "auto-detect")")
            print("🔍 Detect language: \(shouldDetectLanguage)")

            // Get initial prompt from settings (for advanced users)
            let initialPrompt = settings.whisperInitialPrompt

            // Determine task (transcribe or translate)
            let task: DecodingTask = settings.whisperTranslateToEnglish ? .translate : .transcribe
            print("📝 Task: \(task == .translate ? "translate to English" : "transcribe")")
            if !initialPrompt.isEmpty {
                print("💬 Initial prompt: '\(initialPrompt)'")
            }

            // Create decode options with all settings (for WhisperKit 0.9.4)
            let decodeOptions = DecodingOptions(
                verbose: true,
                task: task,
                language: language,
                temperature: Float(settings.whisperTemperature),
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 5,
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: true,
                usePrefillCache: true,
                detectLanguage: shouldDetectLanguage,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                wordTimestamps: settings.whisperWordLevelTimestamps,
                clipTimestamps: [],
                suppressBlank: true,
                supressTokens: [],
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.0,
                noSpeechThreshold: 0.6,
                concurrentWorkerCount: settings.whisperThreadCount
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

                        // Update current transcribing text (show the last few words being processed)
                        let currentText = transcriptionProgress.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !currentText.isEmpty {
                            // Get last 10 words to show as preview
                            let words = currentText.split(separator: " ")
                            let previewWords = words.suffix(10)
                            self.currentTranscribingText = previewWords.joined(separator: " ")
                        }

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
            print("📝 Transcription text length: \(fullText.count) characters")
            print("📝 Transcription text preview: '\(fullText.prefix(100))'")

            let segments = firstResult.segments.map { segment in
                TranscriptionSegment(
                    start: Double(segment.start),
                    end: Double(segment.end),
                    text: segment.text
                )
            }

            print("✅ Transcription complete: \(segments.count) segments, \(fullText.count) characters")

            currentProgress = 1.0
            progress(1.0)
            return TranscriptionResult(text: fullText, segments: segments)

        } catch let error as WhisperError {
            // Already a WhisperError, just rethrow
            print("❌ WhisperKit transcription failed: \(error)")
            throw error
        } catch {
            // Wrap other errors with more context
            print("❌ WhisperKit transcription failed: \(error)")
            print("   Error type: \(type(of: error))")

            // Provide more specific error messages for common issues
            let errorMessage = error.localizedDescription
            if errorMessage.contains("ML Program") {
                throw WhisperError.transcriptionFailed("ML model error. This can happen with corrupted audio files, very long recordings, or if the model needs to be re-downloaded. Try with a different audio file or re-download the model in Settings.")
            } else if errorMessage.contains("memory") || errorMessage.contains("Memory") {
                throw WhisperError.transcriptionFailed("Out of memory. Try using a smaller model (e.g. Tiny or Base) or split your audio into shorter segments.")
            } else {
                throw WhisperError.transcriptionFailed(errorMessage)
            }
        }
    }

    func cancelTranscription() {
        isTranscribing = false
        currentProgress = 0.0
    }

    private func getModelPath(for modelName: String) -> String {
        // WhisperKit stores models in ~/Library/Caches/huggingface/models/
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelsPath = cacheDir.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(modelName)")
        return modelsPath.path
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
            return NSLocalizedString("Whisper model er ikke downloadet. Download modellen i indstillinger.", comment: "")
        case .fileNotFound:
            return NSLocalizedString("Lydfil ikke fundet", comment: "")
        case .transcriptionFailed(let error):
            return String(format: NSLocalizedString("Transskription fejlede: %@", comment: ""), error)
        case .authorizationDenied:
            return NSLocalizedString("Mikrofonadgang nægtet", comment: "")
        case .recognizerNotAvailable:
            return NSLocalizedString("Talegenkendelse ikke tilgængelig", comment: "")
        }
    }
}
