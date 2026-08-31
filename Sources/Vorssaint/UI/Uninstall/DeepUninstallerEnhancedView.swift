// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct DeepUninstallerEnhancedView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var uninstaller = DeepAppUninstaller.shared
    @State private var showingConfirm = false
    @State private var appToUninstall: DeepAppUninstaller.InstalledAppFootprint?

    private var extStrings: TenFeaturesExtendedStrings {
        TenFeaturesExtendedStrings.localized(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header search & action bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search installed applications…", text: $uninstaller.searchText)
                    .textFieldStyle(.plain)

                if !uninstaller.searchText.isEmpty {
                    Button {
                        uninstaller.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    uninstaller.scanInstalledApps()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(uninstaller.phase == .scanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if uninstaller.phase == .scanning {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Scanning applications and ~/Library leftovers…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if uninstaller.filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No applications found.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(uninstaller.filteredApps) { app in
                    HStack(spacing: 14) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name)
                                .font(.system(size: 14, weight: .semibold))
                            HStack(spacing: 8) {
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if app.leftoversCount > 0 {
                                    Text("• \(app.leftoversCount) leftover folders")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                                .font(.system(size: 13, weight: .medium))
                            Text("App: \(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file)) | Lib: \(ByteCountFormatter.string(fromByteCount: app.leftoversSize, countStyle: .file))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            appToUninstall = app
                            showingConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .confirmationDialog(
            "Completely Uninstall \(appToUninstall?.name ?? "App")?",
            isPresented: $showingConfirm,
            presenting: appToUninstall
        ) { app in
            Button("Deep Uninstall (Move App & Leftovers to Trash)", role: .destructive) {
                uninstaller.deepUninstall(app: app) { _ in }
            }
            Button("Cancel", role: .cancel) {}
        } message: { app in
            Text("This will safely remove \(app.name) along with \(ByteCountFormatter.string(fromByteCount: app.leftoversSize, countStyle: .file)) in caches, preferences, containers, and support files to the Trash.")
        }
    }
}
