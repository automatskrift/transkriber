//
//  ErrorHandler.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var showingError = false

    private init() {}

    func handle(_ error: Error, context: String = "") {
        Logger.shared.error("\(context): \(error.localizedDescription)")

        let appError: AppError
        if let err = error as? AppError {
            appError = err
        } else {
            appError = AppError.unknown(error)
        }

        currentError = appError
        showingError = true

        // Show alert
        showAlert(for: appError, context: context)
    }

    private func showAlert(for error: AppError, context: String) {
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.alertStyle = error.alertStyle
        alert.addButton(withTitle: "OK")

        if error.isRecoverable {
            alert.addButton(withTitle: "Prøv Igen")
        }

        let response = alert.runModal()

        if response == .alertSecondButtonReturn && error.isRecoverable {
            error.recoveryAction?()
        }
    }

    func clearError() {
        currentError = nil
        showingError = false
    }
}

struct AppError: LocalizedError {
    let title: String
    let message: String
    let alertStyle: NSAlert.Style
    let isRecoverable: Bool
    let recoveryAction: (() -> Void)?

    init(title: String, message: String, alertStyle: NSAlert.Style = .warning, isRecoverable: Bool = false, recoveryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.alertStyle = alertStyle
        self.isRecoverable = isRecoverable
        self.recoveryAction = recoveryAction
    }

    var errorDescription: String? {
        return message
    }

    // Predefined errors
    static func noFolderSelected() -> AppError {
        AppError(
            title: "Ingen Folder Valgt",
            message: "Vælg en folder for at starte overvågning.",
            alertStyle: .informational
        )
    }

    static func noModelDownloaded() -> AppError {
        AppError(
            title: "Model Ikke Downloadet",
            message: "Download en Whisper model i Indstillinger før du kan transkribere.",
            alertStyle: .warning,
            isRecoverable: true,
            recoveryAction: {
                // TODO: Navigate to settings
                NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
            }
        )
    }

    static func transcriptionFailed(file: String, error: Error) -> AppError {
        AppError(
            title: "Transskription Fejlede",
            message: "Kunne ikke transkribere '\(file)':\n\(error.localizedDescription)",
            alertStyle: .critical
        )
    }

    static func folderAccessDenied(folder: String) -> AppError {
        AppError(
            title: "Adgang Nægtet",
            message: "Kunne ikke få adgang til folderen '\(folder)'. Kontroller at appen har tilladelse til at læse folderen.",
            alertStyle: .critical
        )
    }

    static func downloadFailed(model: String, error: Error) -> AppError {
        AppError(
            title: "Download Fejlede",
            message: "Kunne ikke downloade '\(model)' model:\n\(error.localizedDescription)",
            alertStyle: .critical,
            isRecoverable: true
        )
    }

    static func diskSpaceLow() -> AppError {
        AppError(
            title: "Lav Diskplads",
            message: "Der er ikke nok diskplads til at fuldføre operationen.",
            alertStyle: .critical
        )
    }

    static func unknown(_ error: Error) -> AppError {
        AppError(
            title: "Ukendt Fejl",
            message: error.localizedDescription,
            alertStyle: .warning
        )
    }
}
