// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Automatically identifies macOS system appearance (Dark vs Light mode)
/// and dynamically applies the corresponding Light or Dark application icon.
final class AdaptiveAppIconService: ObservableObject {
    static let shared = AdaptiveAppIconService()

    private var lightIcon: NSImage?
    private var darkIcon: NSImage?
    private var isStarted = false

    private init() {
        loadIcons()
    }

    private func loadIcons() {
        // Look in Main Bundle Resources
        if let lightURL = Bundle.main.url(forResource: "AppIcon-Light", withExtension: "icns") ??
                          Bundle.main.url(forResource: "AppIcon-Light", withExtension: "png") {
            lightIcon = NSImage(contentsOf: lightURL)
        }
        if let darkURL = Bundle.main.url(forResource: "AppIcon-Dark", withExtension: "icns") ??
                         Bundle.main.url(forResource: "AppIcon-Dark", withExtension: "png") {
            darkIcon = NSImage(contentsOf: darkURL)
        }

        // Fallback for Development and local testing
        if lightIcon == nil {
            let path = "Resources/Brand/AppIcon-Light.icns"
            let pngPath = "Resources/Brand/AppIcon-Light.png"
            lightIcon = NSImage(contentsOfFile: path) ?? NSImage(contentsOfFile: pngPath)
        }
        if darkIcon == nil {
            let path = "Resources/Brand/AppIcon-Dark.icns"
            let pngPath = "Resources/Brand/AppIcon-Dark.png"
            darkIcon = NSImage(contentsOfFile: path) ?? NSImage(contentsOfFile: pngPath)
        }
    }

    /// Starts observing system and app appearance changes to switch icons in real time.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        loadIcons()

        // macOS system theme changed notification (Dark <-> Light)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // App activation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        updateIcon()
    }

    @objc private func appearanceDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateIcon()
        }
    }

    /// Evaluates current appearance and updates NSApp.applicationIconImage.
    func updateIcon() {
        if lightIcon == nil || darkIcon == nil {
            loadIcons()
        }

        let appPref = AppAppearanceController.shared.appearance
        let isDark: Bool

        switch appPref {
        case .dark:
            isDark = true
        case .light:
            isDark = false
        case .system:
            if let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
                isDark = (match == .darkAqua)
            } else {
                let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
                isDark = (style == "Dark")
            }
        }

        if isDark, let dark = darkIcon {
            NSApp.applicationIconImage = dark
        } else if !isDark, let light = lightIcon {
            NSApp.applicationIconImage = light
        }
    }
}
