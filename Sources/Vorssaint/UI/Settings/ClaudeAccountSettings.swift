// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Chooses an existing login. Claude Code remains responsible for signing in.
struct ClaudeAccountSettings: View {
    @AppStorage(DefaultsKey.notchAgentsClaudeProfile) private var selected = ""
    @AppStorage(DefaultsKey.claudeLiveEnabled) private var claudeLiveEnabled = false
    @AppStorage(DefaultsKey.claudeLiveAnswerInNotch) private var claudeLiveAnswerInNotch = true
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var claudeLive = ClaudeLiveService.shared
    @State private var entries: [Entry] = []
    @State private var readID = UUID()
    @State private var invalidFolder = false
    @State private var hooksRevision = 0
    private var text: ClaudeAccountStrings { FeatureStrings.claudeAccount(l10n.language) }
    private var extras: NotchExtrasStrings { NotchExtrasStrings.localized(l10n.language) }

    private struct Entry: Identifiable {
        let profile: ClaudeAccountProfile
        var identity: ClaudeAccountProfile.Identity?
        var available = true
        var id: String { profile.id }

        func label(defaultName: String) -> String {
            let name = profile.name(defaultName: defaultName)
            return identity?.email.map { name + " · " + $0 } ?? name
        }
    }

    /// Keep the current option in the menu while the disk read is pending.
    private var options: [Entry] {
        var options = entries
        if !options.contains(where: { $0.id.isEmpty }) { options.insert(Entry(profile: ClaudeAccountProfile()), at: 0) }
        if !options.contains(where: { $0.id == selected }) { options.append(Entry(profile: ClaudeAccountProfile(directory: selected))) }
        return options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsMenuRow(symbol: "person.crop.circle", title: text.title, selection: $selected) {
                ForEach(options) { entry in
                    Text(entry.label(defaultName: text.defaultAccount)).tag(entry.id)
                }
            }
            if let entry = entries.first(where: { $0.id == selected }) {
                if !entry.available {
                    Text(text.invalidFolder).font(.caption).foregroundStyle(.orange)
                } else if entry.identity == nil {
                    Text(text.unknownAccount).font(.caption).foregroundStyle(.secondary)
                }
                if !selected.isEmpty {
                    Text(selected).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).help(selected)
                }
            }
            Button(text.chooseFolder) { chooseFolder() }
            Text(text.explanation).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(text.signInHelp, destination: URL(string: "https://code.claude.com/docs/en/authentication#log-in-with-multiple-accounts")!)
                .font(.caption)
            Divider()
            claudeLiveControls
        }
        .onAppear { refresh() }
        .onChange(of: selected) { _, _ in refresh() }
        .onChange(of: claudeLiveEnabled) { _, _ in ClaudeLiveService.shared.syncWithPreferences() }
        .onChange(of: usage.claudeAccountIdentity) { _, _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onDisappear { readID = UUID() }
        .alert(text.title, isPresented: $invalidFolder) {
            Button("OK", role: .cancel) {}
        } message: { Text(text.invalidFolder) }
    }

    private var claudeLiveControls: some View {
        let activeProfile = ClaudeAccountProfile(directory: selected)
        let connected = hooksRevision >= 0 && ClaudeLiveInstaller.isConnected(activeProfile)
        return VStack(alignment: .leading, spacing: 8) {
            SettingsRow(symbol: "bolt.horizontal.circle", title: extras.claudeLiveTitle,
                        caption: extras.claudeLiveCaption) {
                Toggle(extras.claudeLiveTitle, isOn: $claudeLiveEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if claudeLiveEnabled {
                SettingsRow(symbol: "hand.raised", title: extras.claudeLiveAnswerInNotch) {
                    Toggle(extras.claudeLiveAnswerInNotch, isOn: $claudeLiveAnswerInNotch)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.leading, settingsRowTextInset)
            }
            HStack(spacing: 10) {
                Button(connected ? extras.claudeLiveDisconnect : extras.claudeLiveConnect) {
                    let next = !connected
                    if ClaudeLiveInstaller.connect(activeProfile, next) {
                        hooksRevision += 1
                        if next && !claudeLiveEnabled {
                            claudeLiveEnabled = true
                            ClaudeLiveService.shared.syncWithPreferences()
                        }
                    }
                }
                if connected {
                    Label(extras.claudeLiveConnected, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if claudeLive.listening {
                    Label(extras.claudeLiveListening, systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, settingsRowTextInset)
        }
    }

    private func refresh() {
        let id = UUID()
        readID = id
        let selected = selected
        DispatchQueue.global(qos: .utility).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let profiles = [ClaudeAccountProfile(), ClaudeAccountProfile(directory: selected)]
                + ClaudeAccountProfile.discover(home: home)
            var seen = Set<String>()
            let found = profiles.filter { seen.insert($0.id).inserted }.map { profile in
                Entry(profile: profile, identity: profile.read(home: home).identity, available: profile.isAvailable(home: home))
            }
            DispatchQueue.main.async {
                guard readID == id else { return }
                entries = found
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        let home = FileManager.default.homeDirectoryForCurrentUser
        panel.directoryURL = home
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let profile = ClaudeAccountProfile(directory: folder.path)
        // The ordinary ~/.claude folder uses ~/.claude.json. An explicit
        // profile in that folder instead has its own nested .claude.json.
        if folder.standardizedFileURL == home.appending(path: ".claude", directoryHint: .isDirectory).standardizedFileURL,
           !FileManager.default.fileExists(atPath: profile.profileURL(home: home).path) {
            selected = ""
        } else if profile.isAvailable(home: home) {
            selected = profile.directory
        } else {
            invalidFolder = true
        }
    }
}
