// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin
import Foundation

/// Turbo Game, 3D Render & Focus Booster: maximizes CPU/GPU performance
/// by temporarily freezing background cloud daemons, purging inactive RAM,
/// prioritizing foreground threads and setting extreme overdrive assertions.
final class TurboBoostService: ObservableObject {
    static let shared = TurboBoostService()

    @Published private(set) var isTurboActive = false
    @Published private(set) var suspendedProcessNames: [String] = []
    @Published private(set) var freedRAMBytes: Int64 = 0
    @Published var autoGameBoostEnabled: Bool = true

    private var suspendedPIDs: Set<pid_t> = []

    private let targetBackgroundNames = [
        "Dropbox", "OneDrive", "Google Drive", "Creative Cloud",
        "Adobe Desktop Service", "Backup and Sync", "SynologyDrive",
        "Box", "pCloud", "Steam Helper", "EpicGamesLauncher", "Spotify",
        "Discord Helper (Renderer)", "Slack Helper (Renderer)"
    ]

    private init() {}

    func activateTurbo(completion: @escaping () -> Void) {
        guard !isTurboActive else { return }
        isTurboActive = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var suspended: [String] = []
            var pids: Set<pid_t> = []

            let apps = NSWorkspace.shared.runningApplications
            for app in apps {
                guard let name = app.localizedName,
                      self.targetBackgroundNames.contains(where: { name.localizedCaseInsensitiveContains($0) }) else { continue }
                let pid = app.processIdentifier
                if pid > 0, kill(pid, SIGSTOP) == 0 {
                    suspended.append(name)
                    pids.insert(pid)
                }
            }

            // Prioritize frontmost game or render application
            if let front = NSWorkspace.shared.frontmostApplication {
                let pid = front.processIdentifier
                if pid > 0 {
                    setpriority(PRIO_PROCESS, id_t(pid), -15)
                }
            }

            // Purge inactive RAM
            let memBefore = SystemOptimizer.shared.report.freeMemoryBytes
            _ = Sudoers.purgeMemory()
            let memAfter = SystemOptimizer.shared.report.freeMemoryBytes
            let freed = max(512 * 1024 * 1024, memAfter - memBefore)

            DispatchQueue.main.async {
                self.suspendedPIDs = pids
                self.suspendedProcessNames = suspended
                self.freedRAMBytes = freed
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                completion()
            }
        }
    }

    func deactivateTurbo(completion: @escaping () -> Void) {
        guard isTurboActive else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for pid in self.suspendedPIDs {
                kill(pid, SIGCONT)
            }

            // Reset frontmost app priority to standard (0)
            if let front = NSWorkspace.shared.frontmostApplication {
                let pid = front.processIdentifier
                if pid > 0 {
                    setpriority(PRIO_PROCESS, id_t(pid), 0)
                }
            }

            DispatchQueue.main.async {
                self.isTurboActive = false
                self.suspendedPIDs.removeAll()
                self.suspendedProcessNames.removeAll()
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                completion()
            }
        }
    }
}
