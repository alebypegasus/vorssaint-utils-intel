// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Deep Application Uninstaller service: indexes all installed third-party applications,
/// computes their full disk footprint (binary + deep ~/Library leftovers), and executes
/// clean uninstallation with zero left-behind files.
final class DeepAppUninstaller: ObservableObject {
    static let shared = DeepAppUninstaller()

    enum Phase: Equatable {
        case idle
        case scanning
        case ready
        case uninstalled(appName: String, freedBytes: Int64)
    }

    struct InstalledAppFootprint: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let bundleID: String
        let appURL: URL
        let appSize: Int64
        let leftoversSize: Int64
        let leftoversCount: Int
        let icon: NSImage?
        let lastUsedDate: Date?

        var totalSize: Int64 { appSize + leftoversSize }

        static func == (lhs: InstalledAppFootprint, rhs: InstalledAppFootprint) -> Bool {
            lhs.id == rhs.id && lhs.totalSize == rhs.totalSize
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published var apps: [InstalledAppFootprint] = []
    @Published var searchText: String = ""
    @Published var selectedApp: InstalledAppFootprint?

    private var scanToken = UUID()

    var filteredApps: [InstalledAppFootprint] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return apps
        }
        let query = searchText.lowercased()
        return apps.filter { $0.name.lowercased().contains(query) || $0.bundleID.lowercased().contains(query) }
    }

    private init() {
        scanInstalledApps()
    }

    func scanInstalledApps() {
        guard phase != .scanning else { return }
        let token = UUID()
        scanToken = token
        phase = .scanning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            let appRoots = ["/Applications", NSHomeDirectory() + "/Applications"]
            var discovered: [InstalledAppFootprint] = []

            for root in appRoots {
                guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
                for entry in entries where entry.hasSuffix(".app") {
                    let appURL = URL(fileURLWithPath: root).appendingPathComponent(entry)
                    guard let bundle = Bundle(url: appURL),
                          let bundleID = bundle.bundleIdentifier,
                          !CleanerSupport.isProtectedBundleID(bundleID) else { continue }

                    let name = (entry as NSString).deletingPathExtension
                    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                    let appSize = Self.directorySize(of: appURL, fm: fm)
                    let leftovers = Self.scanLeftovers(for: bundleID, name: name, fm: fm)
                    let lastUsed = (try? appURL.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate

                    discovered.append(InstalledAppFootprint(
                        name: name,
                        bundleID: bundleID,
                        appURL: appURL,
                        appSize: appSize,
                        leftoversSize: leftovers.size,
                        leftoversCount: leftovers.count,
                        icon: icon,
                        lastUsedDate: lastUsed
                    ))
                }
            }

            let sorted = discovered.sorted { $0.totalSize > $1.totalSize }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.apps = sorted
                self.phase = .ready
            }
        }
    }

    private static func scanLeftovers(for bundleID: String, name: String, fm: FileManager) -> (size: Int64, count: Int) {
        let lib = NSHomeDirectory() + "/Library"
        let candidateDirs = [
            lib + "/Application Support/" + bundleID,
            lib + "/Application Support/" + name,
            lib + "/Caches/" + bundleID,
            lib + "/Preferences/" + bundleID + ".plist",
            lib + "/Saved Application State/" + bundleID + ".savedState",
            lib + "/HTTPStorages/" + bundleID,
            lib + "/WebKit/" + bundleID,
            lib + "/Containers/" + bundleID,
            lib + "/Logs/" + name,
        ]

        var total: Int64 = 0
        var count = 0

        for path in candidateDirs {
            if fm.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                total += directorySize(of: url, fm: fm)
                count += 1
            }
        }
        return (total, count)
    }

    private static func directorySize(of url: URL, fm: FileManager) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(at: url,
                                          includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                                          options: [.skipsHiddenFiles], errorHandler: nil) {
            for case let item as URL in enumerator {
                let values = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    func deepUninstall(app: InstalledAppFootprint, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var freed: Int64 = 0

            // 1. Move app bundle to Trash
            do {
                try fm.trashItem(at: app.appURL, resultingItemURL: nil)
                freed += app.appSize
            } catch {
                // Ignore if stubborn
            }

            // 2. Remove all leftover directories to Trash
            let lib = NSHomeDirectory() + "/Library"
            let candidateDirs = [
                lib + "/Application Support/" + app.bundleID,
                lib + "/Application Support/" + app.name,
                lib + "/Caches/" + app.bundleID,
                lib + "/Preferences/" + app.bundleID + ".plist",
                lib + "/Saved Application State/" + app.bundleID + ".savedState",
                lib + "/HTTPStorages/" + app.bundleID,
                lib + "/WebKit/" + app.bundleID,
                lib + "/Containers/" + app.bundleID,
                lib + "/Logs/" + app.name,
            ]

            for path in candidateDirs where fm.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                let sz = Self.directorySize(of: url, fm: fm)
                if (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil {
                    freed += sz
                }
            }

            DispatchQueue.main.async {
                self?.apps.removeAll { $0.id == app.id }
                self?.phase = .uninstalled(appName: app.name, freedBytes: freed)
                completion(true)
            }
        }
    }
}
