// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Discovers, inspects, and manages all macOS startup items, including
/// Login Items, User/System LaunchAgents, LaunchDaemons, and background services.
final class StartupManager: ObservableObject {
    static let shared = StartupManager()

    enum ItemType: String, CaseIterable, Identifiable {
        case all, loginItems, userAgents, systemAgents, systemDaemons

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "All Items"
            case .loginItems: return "Login Items"
            case .userAgents: return "User Agents"
            case .systemAgents: return "System Agents"
            case .systemDaemons: return "System Daemons"
            }
        }

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .loginItems: return "person.badge.key"
            case .userAgents: return "person.circle"
            case .systemAgents: return "gearshape.2"
            case .systemDaemons: return "terminal"
            }
        }
    }

    struct StartupItem: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let label: String
        let type: ItemType
        let plistURL: URL
        let executablePath: String?
        let isOrphan: Bool
        var isEnabled: Bool
        let icon: NSImage?

        static func == (lhs: StartupItem, rhs: StartupItem) -> Bool {
            lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled
        }
    }

    @Published private(set) var items: [StartupItem] = []
    @Published private(set) var isScanning = false
    @Published var selectedType: ItemType = .all
    @Published var searchText: String = ""

    var filteredItems: [StartupItem] {
        items.filter { item in
            let matchesType = (selectedType == .all || item.type == selectedType)
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText) || item.label.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }
    }

    private init() {
        scanAll()
    }

    func scanAll() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var discovered: [StartupItem] = []

            // 1. User LaunchAgents (~/Library/LaunchAgents)
            let userAgentDir = NSHomeDirectory() + "/Library/LaunchAgents"
            discovered.append(contentsOf: Self.scanDirectory(userAgentDir, type: .userAgents, fm: fm))

            // 2. System LaunchAgents (/Library/LaunchAgents)
            let sysAgentDir = "/Library/LaunchAgents"
            discovered.append(contentsOf: Self.scanDirectory(sysAgentDir, type: .systemAgents, fm: fm))

            // 3. System LaunchDaemons (/Library/LaunchDaemons)
            let sysDaemonDir = "/Library/LaunchDaemons"
            discovered.append(contentsOf: Self.scanDirectory(sysDaemonDir, type: .systemDaemons, fm: fm))

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.items = discovered.sorted { $0.name.lowercased() < $1.name.lowercased() }
                self.isScanning = false
            }
        }
    }

    private static func scanDirectory(_ path: String, type: ItemType, fm: FileManager) -> [StartupItem] {
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        var result: [StartupItem] = []

        for entry in entries where entry.hasSuffix(".plist") || entry.hasSuffix(".plist.disabled") {
            let plistURL = URL(fileURLWithPath: path).appendingPathComponent(entry)
            guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else { continue }

            let label = plist["Label"] as? String ?? (entry as NSString).deletingPathExtension
            var execPath = plist["Program"] as? String
            if execPath == nil, let args = plist["ProgramArguments"] as? [String], let first = args.first {
                execPath = first
            }

            let isDisabled = entry.hasSuffix(".disabled") || (plist["Disabled"] as? Bool == true)
            var isOrphan = false
            if let exec = execPath {
                isOrphan = !fm.fileExists(atPath: exec) && !exec.hasPrefix("/usr/bin/") && !exec.hasPrefix("/bin/")
            }

            var icon: NSImage?
            if let exec = execPath, fm.fileExists(atPath: exec) {
                icon = NSWorkspace.shared.icon(forFile: exec)
            }

            let displayName = (label.split(separator: ".").last.map(String.init)) ?? label

            result.append(StartupItem(
                name: displayName.capitalized,
                label: label,
                type: type,
                plistURL: plistURL,
                executablePath: execPath,
                isOrphan: isOrphan,
                isEnabled: !isDisabled,
                icon: icon
            ))
        }
        return result
    }

    func toggleEnabled(item: StartupItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newState = !item.isEnabled
        items[idx].isEnabled = newState

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            let path = item.plistURL.path
            if newState {
                // Enable: remove .disabled suffix if present
                if path.hasSuffix(".disabled") {
                    let targetPath = String(path.dropLast(9))
                    try? fm.moveItem(atPath: path, toPath: targetPath)
                }
            } else {
                // Disable: add .disabled suffix
                if !path.hasSuffix(".disabled") {
                    let targetPath = path + ".disabled"
                    try? fm.moveItem(atPath: path, toPath: targetPath)
                }
            }
            DispatchQueue.main.async {
                self?.scanAll()
            }
        }
    }

    func removeItem(item: StartupItem) {
        let fm = FileManager.default
        try? fm.trashItem(at: item.plistURL, resultingItemURL: nil)
        items.removeAll { $0.id == item.id }
    }
}
