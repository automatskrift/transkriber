//
//  WhisperService.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import Speech

@MainActor
class WhisperService: ObservableObject {
    static let shared = WhisperService()

    @Published var isTranscribing = false
    @Published var currentProgress: Double = 0.0

    private var currentModel: WhisperModelType?

    private init() {}

    func loadModel(_ modelType: WhisperModelType) throws {
        guard FileSystemHelper.shared.modelExists(modelType) else {
            throw WhisperError.modelNotDownloaded
        }

        // TODO: Load actual whisper.cpp model
        // For now, we'll use Apple's Speech framework as a fallback
        self.currentModel = modelType
    }

    func transcribe(audioURL: URL, modelType: WhisperModelType, progress: @escaping (Double) -> Void) async throws -> String {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperError.fileNotFound
        }

        // Load model if not already loaded
        if currentModel != modelType {
            try loadModel(modelType)
        }

        isTranscribing = true
        defer { isTranscribing = false }

        // Check if we should use Apple's Speech Recognition
        // This is a temporary solution until whisper.cpp is integrated
        do {
            let transcription = try await transcribeWithSpeechRecognition(audioURL: audioURL, progress: progress)
            return transcription
        } catch {
            throw WhisperError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func transcribeWithSpeechRecognition(audioURL: URL, progress: @escaping (Double) -> Void) async throws -> String {
        // Request authorization
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            throw WhisperError.authorizationDenied
        }

        // Create recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: AppSettings.shared.selectedLanguage)) else {
            throw WhisperError.recognizerNotAvailable
        }

        guard recognizer.isAvailable else {
            throw WhisperError.recognizerNotAvailable
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { continuation in
            var hasReturned = false
            var lastTranscription = ""

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    if !hasReturned {
                        hasReturned = true
                        continuation.resume(throwing: error)
                    }
                    return
                }

                if let result = result {
                    lastTranscription = result.bestTranscription.formattedString

                    // Update progress based on completion
                    if result.isFinal {
                        progress(1.0)
                        if !hasReturned {
                            hasReturned = true
                            continuation.resume(returning: lastTranscription)
                        }
                    } else {
                        // Estimate progress (this is approximate)
                        progress(0.5)
                    }
                }
            }
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
            return "Model er ikke downloadet. Download modellen i indstillinger."
        case .fileNotFound:
            return "Lydfil ikke fundet"
        case .transcriptionFailed(let message):
            return "Transskription fejlede: \(message)"
        case .authorizationDenied:
            return "Adgang til talegenkendelse er nægtet. Giv tilladelse i Systemindstillinger."
        case .recognizerNotAvailable:
            return "Talegenkendelse er ikke tilgængelig"
        }
    }
}
