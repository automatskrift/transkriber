//
//  ConsoleOutputCapture.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import Combine

/// Captures console output to detect WhisperKit download progress
class ConsoleOutputCapture: ObservableObject {
    static let shared = ConsoleOutputCapture()

    @Published var isDownloadDetected = false
    @Published var downloadProgress: Double = 0.0

    private var outputPipe: Pipe?
    private var originalStdOut: Int32 = 0
    private var originalStdErr: Int32 = 0

    private init() {}

    /// Start capturing console output
    func startCapturing() {
        // Create a pipe to capture output
        let pipe = Pipe()
        outputPipe = pipe

        // Save original stdout and stderr
        originalStdOut = dup(STDOUT_FILENO)
        originalStdErr = dup(STDERR_FILENO)

        // Redirect stdout and stderr to our pipe
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        // Start reading from the pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                // Still print to original console
                if self?.originalStdOut != 0 {
                    write(self!.originalStdOut, string, string.count)
                }

                // Check for NSProgress in the output
                self?.parseConsoleOutput(string)
            }
        }
    }

    /// Stop capturing console output
    func stopCapturing() {
        // Restore original stdout and stderr
        if originalStdOut != 0 {
            dup2(originalStdOut, STDOUT_FILENO)
            close(originalStdOut)
            originalStdOut = 0
        }

        if originalStdErr != 0 {
            dup2(originalStdErr, STDERR_FILENO)
            close(originalStdErr)
            originalStdErr = 0
        }

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
    }

    /// Parse console output for download indicators
    private func parseConsoleOutput(_ output: String) {
        DispatchQueue.main.async { [weak self] in
            // Check for NSProgress which indicates actual download
            if output.contains("<NSProgress:") && output.contains("Fraction completed:") {
                // Extract progress from NSProgress output
                // Example: "Fraction completed: 0.9500"
                if let range = output.range(of: "Fraction completed: ") {
                    let startIndex = output.index(range.upperBound, offsetBy: 0)
                    let endIndex = output.index(startIndex, offsetBy: 6, limitedBy: output.endIndex) ?? output.endIndex
                    let progressString = String(output[startIndex..<endIndex])

                    if let progress = Double(progressString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        print("DOWNLOAD DETECTED: Progress = \(progress)")
                        self?.isDownloadDetected = true
                        self?.downloadProgress = progress
                    }
                }
            }

            // Also check for WhisperKit's "Downloading model" message
            if output.contains("Downloading model") || output.contains("downloading model") {
                print("DOWNLOAD DETECTED: WhisperKit is downloading")
                self?.isDownloadDetected = true
            }

            // Check for download completion
            if output.contains("Downloaded") && output.contains("model") {
                print("DOWNLOAD COMPLETED")
                self?.isDownloadDetected = false
                self?.downloadProgress = 1.0
            }
        }
    }
}