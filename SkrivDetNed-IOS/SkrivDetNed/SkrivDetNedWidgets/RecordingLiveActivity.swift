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
        var duration: TimeInterval
        var isPaused: Bool
        var fileName: String
    }

    // Fixed properties
    var startTime: Date
}
