//
//  Logger.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import Foundation

enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
}

class Logger {
    static let shared = Logger()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private var logFileURL: URL?
    private let logQueue = DispatchQueue(label: "dk.omdethele.SkrivDetNed.logger", qos: .utility)

    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        do {
            let appSupportURL = try FileSystemHelper.shared.createApplicationSupportDirectory()
            let logsDir = appSupportURL.appendingPathComponent("Logs")

            if !FileManager.default.fileExists(atPath: logsDir.path) {
                try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            }

            let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                .replacingOccurrences(of: "/", with: "-")
            logFileURL = logsDir.appendingPathComponent("skrivdetned-\(dateString).log")

        } catch {
            print("Failed to setup log file: \(error)")
        }
    }

    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(function) - \(message)"

        // Print to console
        #if DEBUG
        print(logMessage)
        #endif

        // Write to file
        logQueue.async { [weak self] in
            self?.writeToFile(logMessage)
        }
    }

    private func writeToFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }

        let messageWithNewline = message + "\n"

        if let data = messageWithNewline.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logFileURL, options: .atomic)
            }
        }
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    func getLogFileURL() -> URL? {
        return logFileURL
    }

    func clearOldLogs(olderThanDays days: Int = 7) {
        guard let appSupportURL = try? FileSystemHelper.shared.createApplicationSupportDirectory() else { return }
        let logsDir = appSupportURL.appendingPathComponent("Logs")

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        for fileURL in fileURLs {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            if creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
