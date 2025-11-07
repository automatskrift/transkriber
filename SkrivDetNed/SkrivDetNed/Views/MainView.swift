//
//  MainView.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .monitor

    enum Tab {
        case monitor
        case manual
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FolderMonitorView()
                .tabItem {
                    Label("Overvågning", systemImage: "folder.badge.gearshape")
                }
                .tag(Tab.monitor)

            ManualTranscriptionView()
                .tabItem {
                    Label("Manuel", systemImage: "doc.text")
                }
                .tag(Tab.manual)

            SettingsView()
                .tabItem {
                    Label("Indstillinger", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .frame(minWidth: 700, minHeight: 600)
    }
}

#Preview {
    MainView()
}
