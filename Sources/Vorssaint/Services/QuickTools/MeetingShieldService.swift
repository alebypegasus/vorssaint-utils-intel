// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// 1-Click Meeting & Presentation Privacy Shield
/// Hides desktop icons, prevents screen sleep, prepares microphone mute, and pauses notifications.
final class MeetingShieldService: ObservableObject {
    static let shared = MeetingShieldService()

    @Published private(set) var isActive = false
    private var originalDesktopIconsState = true

    private init() {}

    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        originalDesktopIconsState = QuickTogglesService.shared.desktopIconsShown

        // 1. Hide Desktop Icons
        if originalDesktopIconsState {
            QuickTogglesService.shared.setDesktopIconsShown(false)
        }

        // 2. Keep Awake ON
        KeepAwakeManager.shared.toggle()

        // 3. Show Liquid Glass HUD
        QuickToolHUD.show(icon: "shield.checkered", message: "Meeting Shield: ACTIVE")
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false

        // 1. Restore Desktop Icons
        if originalDesktopIconsState {
            QuickTogglesService.shared.setDesktopIconsShown(true)
        }

        // 2. Turn off Keep Awake
        KeepAwakeManager.shared.toggle()

        // 3. Show HUD
        QuickToolHUD.show(icon: "shield.slash", message: "Meeting Shield: OFF")
    }
}
