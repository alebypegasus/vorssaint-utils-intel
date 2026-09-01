// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

final class SystemQuickTogglesService: ObservableObject {
    static let shared = SystemQuickTogglesService()

    @Published var showHiddenFiles: Bool {
        didSet {
            UserDefaults.standard.set(showHiddenFiles, forKey: DefaultsKey.finderShowHiddenFiles)
            applyFinderHiddenFiles(showHiddenFiles)
        }
    }
    @Published private(set) var isRestartingAudio = false

    private init() {
        self.showHiddenFiles = UserDefaults.standard.bool(forKey: DefaultsKey.finderShowHiddenFiles)
    }

    func toggleHiddenFiles() {
        showHiddenFiles.toggle()
    }

    private func applyFinderHiddenFiles(_ show: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            let val = show ? "YES" : "NO"
            _ = Shell.run("/usr/bin/defaults", ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", val])
            _ = Shell.run("/usr/bin/killall", ["Finder"])
        }
    }

    func restartAudioEngine(completion: @escaping (Bool) -> Void) {
        guard !isRestartingAudio else { completion(false); return }
        isRestartingAudio = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let res = Shell.run("/usr/bin/sudo", ["killall", "coreaudiod"])
            Thread.sleep(forTimeInterval: 0.8)

            DispatchQueue.main.async {
                self?.isRestartingAudio = false
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                completion(res.status == 0)
            }
        }
    }

    func restartDock() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Shell.run("/usr/bin/killall", ["Dock"])
        }
    }

    func sleepDisplays() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Shell.run("/usr/bin/pmset", ["displaysleepnow"])
        }
    }

    func lockScreen() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
            _ = AppleScriptRunner.run(script)
        }
    }
}
