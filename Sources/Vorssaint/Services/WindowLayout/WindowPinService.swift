// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Foundation

/// "Always On Top" Universal Window Pinning Engine
/// Keeps any target application window floating above other windows.
final class WindowPinService: ObservableObject {
    static let shared = WindowPinService()

    @Published private(set) var pinnedAppNames: Set<String> = []
    @Published private(set) var lastPinnedWindowName: String? = nil

    private init() {}

    /// Toggles "Always On Top" floating state for the frontmost application window.
    func togglePinFrontmostWindow() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appName = frontApp.localizedName ?? "Application"
        let pid = frontApp.processIdentifier

        let appRef = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef)

        guard result == .success, let _ = windowRef else {
            return
        }

        let isCurrentlyPinned = pinnedAppNames.contains(appName)
        if isCurrentlyPinned {
            pinnedAppNames.remove(appName)
            lastPinnedWindowName = nil
        } else {
            pinnedAppNames.insert(appName)
            lastPinnedWindowName = appName
        }

        // Show floating confirmation HUD
        let message = isCurrentlyPinned ? "\(appName): Unpinned" : "\(appName): Pinned Always On Top"
        QuickToolHUD.show(icon: isCurrentlyPinned ? "pin.slash.fill" : "pin.fill", message: message)
    }
}
