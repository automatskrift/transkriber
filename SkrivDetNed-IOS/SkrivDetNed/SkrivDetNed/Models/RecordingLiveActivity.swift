//
//  RecordingLiveActivity.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import Foundation
import ActivityKit

struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var fileName: String
        var pausedAt: Date?
        var totalPausedDuration: TimeInterval
    }

    // Fixed properties - these don't change during the activity
    var startTime: Date
}
