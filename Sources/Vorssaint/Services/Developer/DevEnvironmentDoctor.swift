// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Developer Environment Doctor: specialized workstation diagnoser & optimizer
/// providing Docker prune, stale node_modules finder, Xcode simulator cleanup, and package caches purge.
final class DevEnvironmentDoctor: ObservableObject {
    static let shared = DevEnvironmentDoctor()

    struct StaleNodeModule: Identifiable, Equatable {
        let id = UUID()
        let projectPath: String
        let modulePath: String
        let sizeBytes: Int64
        let lastModified: Date
    }

    @Published private(set) var isScanning = false
    @Published private(set) var staleModules: [StaleNodeModule] = []
    @Published private(set) var dockerInstalled = false
    @Published private(set) var dockerRunning = false
    @Published private(set) var dockerReclaimableBytes: Int64 = 0
    @Published private(set) var statusLog: [String] = []

    var totalNodeModulesReclaimable: Int64 {
        staleModules.reduce(0) { $0 + $1.sizeBytes }
    }

    private init() {
        diagnose()
    }

    func diagnose() {
        guard !isScanning else { return }
        isScanning = true
        statusLog = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // 1. Docker check
            let fm = FileManager.default
            let dockerBin = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/Applications/Docker.app"].first { fm.fileExists(atPath: $0) }
            let isDockInst = dockerBin != nil

            // 2. Scan stale node_modules in common dev roots
            let devRoots = [
                NSHomeDirectory() + "/Developer",
                NSHomeDirectory() + "/Projects",
                NSHomeDirectory() + "/Documents/Trabalhos",
                NSHomeDirectory() + "/Workspace",
                NSHomeDirectory() + "/code"
            ]

            var foundModules: [StaleNodeModule] = []
            let cutoff = Date().addingTimeInterval(-60 * 86400) // 60 days

            for root in devRoots where fm.fileExists(atPath: root) {
                if let enumerator = fm.enumerator(at: URL(fileURLWithPath: root),
                                                  includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                                                  options: [.skipsPackageDescendants]) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.lastPathComponent == "node_modules" {
                            enumerator.skipDescendants()
                            let parent = fileURL.deletingLastPathComponent()
                            let modDate = (try? parent.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                            if modDate < cutoff {
                                let sz = Self.directorySize(of: fileURL, fm: fm)
                                foundModules.append(StaleNodeModule(
                                    projectPath: parent.path,
                                    modulePath: fileURL.path,
                                    sizeBytes: sz,
                                    lastModified: modDate
                                ))
                            }
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.dockerInstalled = isDockInst
                self.staleModules = foundModules.sorted { $0.sizeBytes > $1.sizeBytes }
                self.isScanning = false
            }
        }
    }

    private static func directorySize(of url: URL, fm: FileManager) -> Int64 {
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileAllocatedSizeKey], options: [.skipsHiddenFiles]) {
            for case let file as URL in enumerator {
                let sz = (try? file.resourceValues(forKeys: [.fileAllocatedSizeKey]))?.fileAllocatedSize ?? 0
                total += Int64(sz)
            }
        }
        return total
    }

    func cleanUnavailableSimulators(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "delete", "unavailable"]
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self?.statusLog.append("Cleaned unavailable Xcode simulators.")
                completion(process.terminationStatus == 0)
            }
        }
    }

    func deleteNodeModule(_ item: StaleNodeModule) {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: item.modulePath)
        try? fm.trashItem(at: url, resultingItemURL: nil)
        staleModules.removeAll { $0.id == item.id }
    }

    func cleanPackageCaches(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            let home = NSHomeDirectory()
            let caches = [
                home + "/.cocoapods/cache",
                home + "/.cargo/registry/cache",
                home + "/Library/Caches/pip",
                home + "/go/pkg/mod/cache"
            ]
            for path in caches where fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
            DispatchQueue.main.async {
                self?.statusLog.append("Package manager caches cleared.")
                completion(true)
            }
        }
    }
}
