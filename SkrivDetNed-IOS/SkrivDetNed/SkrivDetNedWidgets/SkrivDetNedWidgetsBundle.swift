//
//  SkrivDetNedWidgetsBundle.swift
//  SkrivDetNedWidgets
//
//  Created by Tomas Thøfner on 08/11/2025.
//

import WidgetKit
import SwiftUI

@main
struct SkrivDetNedWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            RecordingLiveActivityWidget()
        }
    }
}
