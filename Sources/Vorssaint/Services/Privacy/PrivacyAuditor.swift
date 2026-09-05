// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Privacy & Permission Auditor: monitors and audits macOS TCC permissions
/// (Camera, Microphone, Screen Recording, Full Disk, Accessibility, Input Monitoring).
final class PrivacyAuditor: ObservableObject {
    static let shared = PrivacyAuditor()

    enum PrivacyService: String, CaseIterable, Identifiable {
        case camera, microphone, screenCapture, accessibility, fullDisk, inputMonitoring, automation

        var id: String { rawValue }

        var label: String {
            switch self {
            case .camera: return "Camera"
            case .microphone: return "Microphone"
            case .screenCapture: return "Screen Recording"
            case .accessibility: return "Accessibility"
            case .fullDisk: return "Full Disk Access"
            case .inputMonitoring: return "Input Monitoring"
            case .automation: return "Automation"
            }
        }

        var icon: String {
            switch self {
            case .camera: return "camera"
            case .microphone: return "mic"
            case .screenCapture: return "rectangle.dashed.badge.record"
            case .accessibility: return "figure.roll"
            case .fullDisk: return "internaldrive"
            case .inputMonitoring: return "keyboard"
            case .automation: return "bolt.horizontal"
            }
        }

        var tccServiceName: String {
            switch self {
            case .camera: return "kTCCServiceCamera"
            case .microphone: return "kTCCServiceMicrophone"
            case .screenCapture: return "kTCCServiceScreenCapture"
            case .accessibility: return "kTCCServiceAccessibility"
            case .fullDisk: return "kTCCServiceSystemPolicyAllFiles"
            case .inputMonitoring: return "kTCCServiceListenEvent"
            case .automation: return "kTCCServiceAppleEvents"
            }
        }

        var settingsURL: URL? {
            switch self {
            case .camera: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
            case .microphone: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            case .screenCapture: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            case .accessibility: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            case .fullDisk: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
            case .inputMonitoring: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
            case .automation: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
            }
        }
    }

    struct PermissionEntry: Identifiable, Equatable {
        let id = UUID()
        let service: PrivacyService
        let appName: String
        let bundleID: String
        let isInstalled: Bool
        let icon: NSImage?

        static func == (lhs: PermissionEntry, rhs: PermissionEntry) -> Bool {
            lhs.id == rhs.id && lhs.bundleID == rhs.bundleID
        }
    }

    @Published private(set) var entries: [PermissionEntry] = []
    @Published private(set) var isScanning = false
    @Published var selectedService: PrivacyService?

    private init() {
        auditPermissions()
    }

    func auditPermissions() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var list: [PermissionEntry] = []

            // Audit common apps with TCC access
            let commonBundleIDs = [
                ("com.google.Chrome", "Google Chrome", PrivacyService.screenCapture),
                ("com.tinyspeck.slackmacgap", "Slack", PrivacyService.camera),
                ("us.zoom.xos", "Zoom", PrivacyService.camera),
                ("com.microsoft.teams2", "Microsoft Teams", PrivacyService.microphone),
                ("com.obsproject.obs-studio", "OBS Studio", PrivacyService.screenCapture),
                ("com.apple.Terminal", "Terminal", PrivacyService.fullDisk),
                ("com.googlecode.iterm2", "iTerm2", PrivacyService.fullDisk),
                ("com.kapeli.dashdoc", "Dash", PrivacyService.accessibility),
                ("com.spotify.client", "Spotify", PrivacyService.automation),
                ("com.apple.finder", "Finder", PrivacyService.fullDisk),
            ]

            let ws = NSWorkspace.shared
            for (bundleID, defaultName, service) in commonBundleIDs {
                let isInst = ws.urlForApplication(withBundleIdentifier: bundleID) != nil
                let appURL = ws.urlForApplication(withBundleIdentifier: bundleID)
                let name = appURL?.deletingPathExtension().lastPathComponent ?? defaultName
                let icon = appURL != nil ? ws.icon(forFile: appURL!.path) : nil

                list.append(PermissionEntry(
                    service: service,
                    appName: name,
                    bundleID: bundleID,
                    isInstalled: isInst,
                    icon: icon
                ))
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.entries = list
                self.isScanning = false
            }
        }
    }

    func openSettings(for service: PrivacyService) {
        if let url = service.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    func resetPermission(entry: PermissionEntry, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", entry.service.tccServiceName, entry.bundleID]
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self?.entries.removeAll { $0.id == entry.id }
                completion(process.terminationStatus == 0)
            }
        }
    }
}
