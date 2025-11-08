//
//  MainTabView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Recording
            RecordingView()
                .tabItem {
                    Label("Optag", systemImage: "mic.circle.fill")
                }
                .tag(0)

            // Tab 2: Recordings List
            RecordingsListView()
                .tabItem {
                    Label("Optagelser", systemImage: "waveform")
                }
                .tag(1)

            // Tab 3: Search
            SearchView()
                .tabItem {
                    Label("Søg", systemImage: "magnifyingglass")
                }
                .tag(2)

            // Tab 4: Transcriptions
            TranscriptionsView()
                .tabItem {
                    Label("Transkrip.", systemImage: "doc.text")
                }
                .tag(3)

            // Tab 5: Settings
            SettingsView()
                .tabItem {
                    Label("Indstillinger", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
}
