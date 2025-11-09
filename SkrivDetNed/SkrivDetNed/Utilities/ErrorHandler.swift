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
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))

        if error.isRecoverable {
            alert.addButton(withTitle: NSLocalizedString("Prøv Igen", comment: ""))
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
            title: NSLocalizedString("Ingen Folder Valgt", comment: ""),
            message: NSLocalizedString("Vælg en folder for at starte overvågning.", comment: ""),
            alertStyle: .informational
        )
    }

    static func noModelDownloaded() -> AppError {
        AppError(
            title: NSLocalizedString("Model Ikke Downloadet", comment: ""),
            message: NSLocalizedString("Download en Whisper model i Indstillinger før du kan transkribere.", comment: ""),
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
            title: NSLocalizedString("Transskription Fejlede", comment: ""),
            message: String(format: NSLocalizedString("Kunne ikke transkribere '%@':\n%@", comment: ""), file, error.localizedDescription),
            alertStyle: .critical
        )
    }

    static func folderAccessDenied(folder: String) -> AppError {
        AppError(
            title: NSLocalizedString("Adgang Nægtet", comment: ""),
            message: String(format: NSLocalizedString("Kunne ikke få adgang til folderen '%@'. Kontroller at appen har tilladelse til at læse folderen.", comment: ""), folder),
            alertStyle: .critical
        )
    }

    static func downloadFailed(model: String, error: Error) -> AppError {
        AppError(
            title: NSLocalizedString("Download Fejlede", comment: ""),
            message: String(format: NSLocalizedString("Kunne ikke downloade '%@' model:\n%@", comment: ""), model, error.localizedDescription),
            alertStyle: .critical,
            isRecoverable: true
        )
    }

    static func diskSpaceLow() -> AppError {
        AppError(
            title: NSLocalizedString("Lav Diskplads", comment: ""),
            message: NSLocalizedString("Der er ikke nok diskplads til at fuldføre operationen.", comment: ""),
            alertStyle: .critical
        )
    }

    static func unknown(_ error: Error) -> AppError {
        AppError(
            title: NSLocalizedString("Ukendt Fejl", comment: ""),
            message: error.localizedDescription,
            alertStyle: .warning
        )
    }
}
