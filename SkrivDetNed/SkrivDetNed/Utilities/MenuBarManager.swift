//
//  MenuBarManager.swift
//  SkrivDetNed
//
//  Created by Tomas Thøfner on 07/11/2025.
//

import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    @Published var isMonitoring: Bool = false {
        didSet {
            updateMenuItems()
        }
    }

    private init() {
        setupMenuBar()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "SkrivDetNed")
            button.toolTip = "SkrivDetNed - Transkribering"
        }

        menu = NSMenu()
        updateMenuItems()
        statusItem?.menu = menu
    }

    private func updateMenuItems() {
        guard let menu = menu else { return }

        menu.removeAllItems()

        // Status item
        let statusTitle = isMonitoring ? "● " + NSLocalizedString("Overvåger...", comment: "") : NSLocalizedString("○ Inaktiv", comment: "")
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle monitoring
        let toggleTitle = isMonitoring ? NSLocalizedString("Stop Overvågning", comment: "") : NSLocalizedString("Start Overvågning", comment: "")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring), keyEquivalent: "m")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Show window
        let showItem = NSMenuItem(title: NSLocalizedString("Vis Vindue", comment: ""), action: #selector(showWindow), keyEquivalent: "w")
        showItem.target = self
        menu.addItem(showItem)

        // Settings
        let settingsItem = NSMenuItem(title: NSLocalizedString("Indstillinger", comment: "") + "...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: NSLocalizedString("Afslut SkrivDetNed", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func toggleMonitoring() {
        let viewModel = FolderMonitorViewModel.shared
        viewModel.toggleMonitoring()
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Find and show the main window
        if let window = NSApp.windows.first(where: { $0.title.contains("SkrivDetNed") || $0.contentViewController != nil }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // If no window exists, create one
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettings() {
        showWindow()

        // TODO: Switch to settings tab
        // This would require posting a notification or using a shared state
        NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
    }

    func updateIcon(isTranscribing: Bool) {
        if let button = statusItem?.button {
            if isTranscribing {
                button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: NSLocalizedString("Transkriberer...", comment: ""))
            } else {
                button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "SkrivDetNed")
            }
        }
    }
}
