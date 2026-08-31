// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct StartupManagerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var manager = StartupManager.shared

    private var extStrings: TenFeaturesExtendedStrings {
        TenFeaturesExtendedStrings.localized(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category picker & Search
            HStack(spacing: 12) {
                Picker("", selection: $manager.selectedType) {
                    ForEach(StartupManager.ItemType.allCases) { type in
                        Label(type.label, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()

                Button {
                    manager.scanAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(manager.isScanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if manager.isScanning {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("No startup items found for this filter.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(manager.filteredItems) { item in
                    HStack(spacing: 12) {
                        if let icon = item.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: item.type.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .semibold))
                                if item.isOrphan {
                                    Text("ORPHAN")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15))
                                        .foregroundStyle(.red)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([item.plistURL])
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Reveal plist in Finder")

                        Button(role: .destructive) {
                            manager.removeItem(item: item)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove startup plist")

                        Toggle("", isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in manager.toggleEnabled(item: item) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
