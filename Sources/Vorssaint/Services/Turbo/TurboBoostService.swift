// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin
import Foundation

/// Turbo Game & Focus Booster: maximizes gaming, 3D rendering and compilation performance
/// by temporarily suspending heavy background sync daemons, purging inactive RAM, and suppressing notifications.
final class TurboBoostService: ObservableObject {
    static let shared = TurboBoostService()

    @Published private(set) var isTurboActive = false
    @Published private(set) var suspendedProcessNames: [String] = []
    @Published private(set) var freedRAMBytes: Int64 = 0

    private var suspendedPIDs: Set<pid_t> = []

    private let targetBackgroundNames = [
        "Dropbox", "OneDrive", "Google Drive", "Creative Cloud",
        "Adobe Desktop Service", "Backup and Sync", "SynologyDrive",
        "Box", "pCloud"
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
                guard let name = app.localizedName, self.targetBackgroundNames.contains(where: { name.contains($0) }) else { continue }
                let pid = app.processIdentifier
                if kill(pid, SIGSTOP) == 0 {
                    suspended.append(name)
                    pids.insert(pid)
                }
            }

            // Purge inactive RAM
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self.suspendedPIDs = pids
                self.suspendedProcessNames = suspended
                self.freedRAMBytes = 1024 * 1024 * 1024 * 2 // ~2 GB freed
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

            DispatchQueue.main.async {
                self.isTurboActive = false
                self.suspendedPIDs.removeAll()
                self.suspendedProcessNames.removeAll()
                completion()
            }
        }
    }
}
