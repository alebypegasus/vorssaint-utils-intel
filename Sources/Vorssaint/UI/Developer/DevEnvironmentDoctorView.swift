// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct DevEnvironmentDoctorView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var doc = DevEnvironmentDoctor.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header actions
            HStack(spacing: 12) {
                Label("Workstation Health", systemImage: "stethoscope")
                    .font(.headline)
                Spacer()
                Button {
                    doc.diagnose()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(doc.isScanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Quick Action Tiles
                    HStack(spacing: 12) {
                        DevDoctorCard(
                            title: "Xcode Simulators",
                            subtitle: "Delete unavailable runtimes",
                            icon: "iphone.badge.play",
                            actionTitle: "Clean Simulators"
                        ) {
                            doc.cleanUnavailableSimulators { _ in }
                        }

                        DevDoctorCard(
                            title: "Package Caches",
                            subtitle: "CocoaPods, Cargo, Pip, Go",
                            icon: "shippingbox",
                            actionTitle: "Purge Caches"
                        ) {
                            doc.cleanPackageCaches { _ in }
                        }
                    }

                    // Stale node_modules section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Inactive node_modules Folders (>60 days)")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: doc.totalNodeModulesReclaimable, countStyle: .file))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        if doc.staleModules.isEmpty {
                            Text(doc.isScanning ? "Scanning projects…" : "No stale node_modules found. Workspace is clean.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(doc.staleModules) { item in
                                    HStack(spacing: 10) {
                                        Image(systemName: "folder")
                                            .foregroundStyle(.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text((item.projectPath as NSString).lastPathComponent)
                                                .font(.system(size: 12, weight: .medium))
                                            Text(item.projectPath)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Button(role: .destructive) {
                                            doc.deleteNodeModule(item)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
                }
                .padding(16)
            }
        }
    }

    private struct DevDoctorCard: View {
        let title: String
        let subtitle: String
        let icon: String
        let actionTitle: String
        let action: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .frame(height: 100)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
        }
    }
}
