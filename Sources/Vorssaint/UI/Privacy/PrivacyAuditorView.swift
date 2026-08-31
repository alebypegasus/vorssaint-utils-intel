// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct PrivacyAuditorView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var auditor = PrivacyAuditor.shared

    var body: some View {
        VStack(spacing: 0) {
            // Quick Links to TCC System Panes
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PrivacyAuditor.PrivacyService.allCases) { svc in
                        Button {
                            auditor.openSettings(for: svc)
                        } label: {
                            Label(svc.label, systemImage: svc.icon)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if auditor.isScanning {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(auditor.entries) { entry in
                    HStack(spacing: 12) {
                        if let icon = entry.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: entry.service.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.appName)
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(entry.service.label) • \(entry.bundleID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Revoke") {
                            auditor.resetPermission(entry: entry) { _ in }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
