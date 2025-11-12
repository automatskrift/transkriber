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
    @Published var loadingModelName: String?  // Name of model being loaded
    // Removed needsModelDownload - we'll handle this differently
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

        // Pre-flight checks before attempting to load model
        let sysReq = SystemRequirements.shared

        // Check disk space
        let diskCheck = sysReq.hasSufficientDiskSpace(for: modelType)
        if !diskCheck.sufficient {
            print("❌ Insufficient disk space: required \(diskCheck.required), available \(diskCheck.available)")
            throw WhisperError.insufficientDiskSpace(required: diskCheck.required, available: diskCheck.available)
        }

        // Check memory
        let memCheck = sysReq.hasSufficientMemory(for: modelType)
        if !memCheck.sufficient {
            print("❌ Insufficient memory for \(modelType.displayName): required \(memCheck.required), available \(memCheck.available)")
            throw WhisperError.insufficientMemory(
                model: modelType.displayName,
                required: memCheck.required,
                available: memCheck.available
            )
        }

        // Show warning if memory is tight
        if let warning = memCheck.warning {
            print("⚠️ Memory warning: \(warning)")
            // Could show this warning to user in UI
        }

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
            let audioEncoderPath = modelPath.appendingPathComponent("AudioEncoder.mlmodelc")
            let textDecoderPath = modelPath.appendingPathComponent("TextDecoder.mlmodelc")
            let melSpectrogramPath = modelPath.appendingPathComponent("MelSpectrogram.mlmodelc")

            // Check for all essential model files
            let hasAudioEncoder = FileManager.default.fileExists(atPath: audioEncoderPath.path)
            let hasTextDecoder = FileManager.default.fileExists(atPath: textDecoderPath.path)
            let hasMelSpectrogram = FileManager.default.fileExists(atPath: melSpectrogramPath.path)

            let isModelDownloaded = hasAudioEncoder && hasTextDecoder && hasMelSpectrogram

            if isModelDownloaded {
                print("✅ Model already available: \(modelType.displayName)")
                // Model exists on disk, we're just loading it
                isLoadingModel = true
                loadingModelName = modelType.displayName
                isDownloadingModel = false
                downloadingModelName = nil
            } else {
                print("⬇️ Downloading model: \(modelType.displayName)")

                // Model needs to be downloaded
                isDownloadingModel = true
                isLoadingModel = false
                downloadingModelName = modelType.displayName
                downloadProgress = 0.0
            }


            // Keep download flag active if we're downloading
            let wasDownloading = isDownloadingModel

            // Add timeout for loading indicator (30 seconds max)
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
                await MainActor.run {
                    if self.isLoadingModel {
                        print("⚠️ Loading timeout - dismissing loading indicator")
                        self.isLoadingModel = false
                        self.loadingModelName = nil
                    }
                }
            }

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

            currentModel = modelType

            // Always reset loading flags immediately after initialization
            isLoadingModel = false
            loadingModelName = nil

            // Only reset download flags after a short delay if we were downloading
            // This gives the UI time to show the alert
            if wasDownloading {
                // Keep the download alert visible for at least 2 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        self.isDownloadingModel = false
                        self.downloadingModelName = nil
                        self.downloadProgress = 0.0
                    }
                }
            } else {
                // If we were just loading, reset immediately
                isDownloadingModel = false
                downloadingModelName = nil
            }

            downloadProgress = 0.0
            print("✅ WhisperKit model loaded successfully: \(whisperKitModelName)")
        } catch {
            print("❌ Failed to load WhisperKit: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            // Always reset all flags on error
            isDownloadingModel = false
            isLoadingModel = false
            downloadingModelName = nil
            loadingModelName = nil
            downloadProgress = 0.0

            // Provide more specific error messages based on the error
            let errorString = error.localizedDescription.lowercased()

            if errorString.contains("network") || errorString.contains("connection") || errorString.contains("offline") {
                throw WhisperError.networkUnavailable
            } else if errorString.contains("disk") || errorString.contains("space") || errorString.contains("storage") {
                let diskCheck = SystemRequirements.shared.hasSufficientDiskSpace(for: modelType)
                throw WhisperError.insufficientDiskSpace(required: diskCheck.required, available: diskCheck.available)
            } else if errorString.contains("memory") || errorString.contains("ram") {
                let memCheck = SystemRequirements.shared.hasSufficientMemory(for: modelType)
                throw WhisperError.insufficientMemory(
                    model: modelType.displayName,
                    required: memCheck.required,
                    available: memCheck.available
                )
            } else if errorString.contains("download") {
                throw WhisperError.downloadFailed(error.localizedDescription)
            } else if errorString.contains("model") || errorString.contains("mlmodel") || errorString.contains("coreml") {
                throw WhisperError.modelLoadingFailed(error.localizedDescription)
            } else {
                // If we can't identify the specific error, provide a more helpful message
                let errorMsg = String(format: NSLocalizedString("Model could not be loaded: %@. Try restarting the app or selecting a different model.", comment: "Generic model loading error"), error.localizedDescription)
                throw WhisperError.modelLoadingFailed(errorMsg)
            }
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
            // This shouldn't happen if loadModel succeeded, but handle it gracefully
            throw WhisperError.modelLoadingFailed(NSLocalizedString("Model was not initialized correctly. Try restarting the app.", comment: "Model initialization error"))
        }

        isTranscribing = true
        currentProgress = 0.0
        currentTranscribingText = ""
        defer {
            isTranscribing = false
            currentProgress = 0.0
            currentTranscribingText = ""
        }

        print("🎙️ Transcribing: \(audioURL.lastPathComponent) with \(modelType.displayName)")

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


            // Get initial prompt from settings (for advanced users)
            _ = settings.whisperInitialPrompt

            // Determine task (transcribe or translate)
            let task: DecodingTask = settings.whisperTranslateToEnglish ? .translate : .transcribe

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
                throw WhisperError.transcriptionFailed(NSLocalizedString("ML model error. This can happen with corrupted audio files, very long recordings, or if the model needs to be re-downloaded. Try with a different audio file or re-download the model in Settings.", comment: "ML model error message"))
            } else if errorMessage.contains("memory") || errorMessage.contains("Memory") {
                throw WhisperError.transcriptionFailed(NSLocalizedString("Out of memory. Try using a smaller model (e.g. Tiny or Base) or split your audio into shorter segments.", comment: "Memory error message"))
            } else {
                throw WhisperError.transcriptionFailed(errorMessage)
            }
        }
    }

    func cancelTranscription() {
        isTranscribing = false
        currentProgress = 0.0
    }

    private func getModelPath(for modelName: String) -> URL {
        // WhisperKit stores models in the app container's Documents directory
        // When running in the app, FileManager will automatically use the container path
        // Path: ~/Library/Containers/dk.omdethele.SkrivDetNed/Data/Documents/huggingface/models/argmaxinc/whisperkit-coreml/

        // First try the container's Documents directory (when sandboxed)
        if let containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let huggingfacePath = containerURL.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(modelName)")

            // Check if this path exists - if we're sandboxed, it should be the container path
            if FileManager.default.fileExists(atPath: huggingfacePath.path) ||
               huggingfacePath.path.contains("Containers/dk.omdethele.SkrivDetNed") {
                print("📂 Using container Documents path: \(huggingfacePath.path)")
                return huggingfacePath
            }
        }

        // Fallback to explicit container path if needed
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let explicitContainerPath = homeDir
            .appendingPathComponent("Library/Containers/dk.omdethele.SkrivDetNed/Data/Documents")
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(modelName)")

        print("📂 Using explicit container path: \(explicitContainerPath.path)")
        return explicitContainerPath
    }
}

enum WhisperError: LocalizedError {
    case modelNotDownloaded
    case fileNotFound
    case transcriptionFailed(String)
    case authorizationDenied
    case recognizerNotAvailable
    case downloadFailed(String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case insufficientMemory(model: String, required: UInt64, available: UInt64)
    case modelLoadingFailed(String)
    case networkUnavailable

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
        case .downloadFailed(let error):
            return String(format: NSLocalizedString("Model download failed: %@", comment: "Model download error"), error)
        case .insufficientDiskSpace(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let reqStr = formatter.string(fromByteCount: required)
            let availStr = formatter.string(fromByteCount: available)
            return String(format: NSLocalizedString("Not enough disk space. Requires %@, but only %@ available.", comment: "Disk space error"), reqStr, availStr)
        case .insufficientMemory(let model, let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .memory
            let reqStr = formatter.string(fromByteCount: Int64(min(required, UInt64(Int64.max))))
            let availStr = formatter.string(fromByteCount: Int64(min(available, UInt64(Int64.max))))
            return String(format: NSLocalizedString("%@ model requires %@ RAM, but system only has %@. Try a smaller model.", comment: "Memory error"), model, reqStr, availStr)
        case .modelLoadingFailed(let error):
            return String(format: NSLocalizedString("Model could not be loaded: %@", comment: "Model loading error"), error)
        case .networkUnavailable:
            return NSLocalizedString("No internet connection. Check your network connection and try again.", comment: "Network unavailable error")
        }
    }
}
