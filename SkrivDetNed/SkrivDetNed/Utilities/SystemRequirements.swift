//
//  SystemRequirements.swift
//  SkrivDetNed
//
//  Created for better error handling and system checks
//

import Foundation

@MainActor
class SystemRequirements {
    static let shared = SystemRequirements()

    private init() {}

    // MARK: - Disk Space

    /// Check available disk space
    func getAvailableDiskSpace() -> Int64? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemFreeSize] as? Int64
        } catch {
            print("❌ Failed to get disk space: \(error)")
            return nil
        }
    }

    /// Check if there's enough disk space for a model
    func hasSufficientDiskSpace(for modelType: WhisperModelType) -> (sufficient: Bool, available: Int64, required: Int64) {
        let available = getAvailableDiskSpace() ?? 0
        // Add 500MB buffer to the model size for temporary files and workspace
        let required = modelType.fileSize + 500_000_000

        return (available > required, available, required)
    }

    // MARK: - Memory

    /// Get total physical memory
    func getTotalMemory() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }

    /// Get available memory (approximation)
    func getAvailableMemory() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            // This gives us the current app's memory usage
            let usedMemory = info.resident_size
            let totalMemory = getTotalMemory()

            // Very rough approximation of available memory
            // In reality, macOS manages memory dynamically
            let availableMemory = totalMemory > usedMemory ? totalMemory - usedMemory : 0
            return availableMemory
        }

        return nil
    }

    /// Get estimated memory requirement for a model
    func getEstimatedMemoryRequirement(for modelType: WhisperModelType) -> UInt64 {
        // Estimated memory requirements based on model size
        // WhisperKit models typically need 2-3x their disk size in RAM
        switch modelType {
        case .tiny:
            return 200_000_000    // ~200MB
        case .base:
            return 400_000_000    // ~400MB
        case .small:
            return 1_000_000_000  // ~1GB
        case .medium:
            return 3_000_000_000  // ~3GB
        case .large:
            return 6_000_000_000  // ~6GB
        }
    }

    /// Check if system has enough memory for model
    func hasSufficientMemory(for modelType: WhisperModelType) -> (sufficient: Bool, available: UInt64, required: UInt64, warning: String?) {
        let totalMemory = getTotalMemory()
        let required = getEstimatedMemoryRequirement(for: modelType)

        // Check against total physical memory
        let sufficient = totalMemory > required

        var warning: String? = nil

        // Provide warnings for large models on systems with limited RAM
        if modelType == .large {
            if totalMemory <= 8_000_000_000 { // 8GB or less
                warning = NSLocalizedString("Large model requires at least 6GB RAM and may be slow on this system. Consider using Medium or Small model.", comment: "Large model memory warning for 8GB systems")
            } else if totalMemory <= 16_000_000_000 { // 16GB or less
                warning = NSLocalizedString("Large model may affect system performance. Close other applications for better performance.", comment: "Large model memory warning for 16GB systems")
            }
        } else if modelType == .medium && totalMemory <= 8_000_000_000 {
            warning = NSLocalizedString("Medium model may be slow on systems with 8GB RAM or less.", comment: "Medium model memory warning")
        }

        return (sufficient, totalMemory, required, warning)
    }

    // MARK: - Network

    /// Check if network is available
    func isNetworkAvailable() -> Bool {
        // Simple check - try to reach a reliable host
        if let url = URL(string: "https://huggingface.co") {
            if let _ = try? Data(contentsOf: url, options: .mappedIfSafe) {
                return true
            }
        }
        return false
    }

    // MARK: - Formatted Strings

    /// Format bytes to human readable string
    func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func formatBytes(_ bytes: UInt64) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(min(bytes, UInt64(Int64.max))), countStyle: .file)
    }
}