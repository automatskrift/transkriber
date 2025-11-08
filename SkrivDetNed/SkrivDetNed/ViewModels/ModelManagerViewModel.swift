//
//  ModelManagerViewModel.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ModelManagerViewModel: ObservableObject {
    @Published var models: [WhisperModel] = []
    @Published var totalStorageUsed: Int64 = 0

    private let downloadService = ModelDownloadService.shared
    private let fileHelper = FileSystemHelper.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        refreshModels()

        // Observe download progress changes with throttling
        downloadService.$downloadProgress
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.refreshModels()
            }
            .store(in: &cancellables)

        // Observe download status changes
        downloadService.$isDownloading
            .sink { [weak self] _ in
                self?.refreshModels()
            }
            .store(in: &cancellables)
    }

    func refreshModels() {
        models = WhisperModelType.allCases.map { type in
            let isDownloaded = fileHelper.modelExists(type)
            let progress = downloadService.downloadProgress[type]

            return WhisperModel(
                type: type,
                isDownloaded: isDownloaded,
                downloadProgress: progress
            )
        }

        totalStorageUsed = fileHelper.getTotalModelsSize()
    }

    func downloadModel(_ modelType: WhisperModelType) {
        Task {
            do {
                try await downloadService.downloadModel(modelType)
                refreshModels()
            } catch {
                print("Failed to download model: \(error)")
                // TODO: Show error alert
            }
        }
    }

    func cancelDownload(_ modelType: WhisperModelType) {
        downloadService.cancelDownload(modelType)
        refreshModels()
    }

    func deleteModel(_ modelType: WhisperModelType) {
        do {
            try downloadService.deleteModel(modelType)
            refreshModels()
        } catch {
            print("Failed to delete model: \(error)")
            // TODO: Show error alert
        }
    }

    func isDownloading(_ modelType: WhisperModelType) -> Bool {
        return downloadService.isDownloading[modelType, default: false]
    }

    func downloadProgress(for modelType: WhisperModelType) -> Double? {
        return downloadService.downloadProgress[modelType]
    }

    var formattedTotalStorage: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
}
