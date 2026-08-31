// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct TurboBoostView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var turbo = TurboBoostService.shared

    var body: some View {
        VStack(spacing: 24) {
            // Turbo Status Indicator
            ZStack {
                Circle()
                    .fill(turbo.isTurboActive ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: turbo.isTurboActive ? "bolt.fill" : "gamecontroller")
                    .font(.system(size: 48))
                    .foregroundStyle(turbo.isTurboActive ? .red : .blue)
            }
            .padding(.top, 20)

            VStack(spacing: 6) {
                Text(turbo.isTurboActive ? "Turbo Mode Active" : "Turbo Mode Standby")
                    .font(.title2.bold())
                Text("Suspends background sync agents (Dropbox, OneDrive, Adobe CC), clears RAM buffers, and prioritizes gaming/rendering workloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            if turbo.isTurboActive && !turbo.suspendedProcessNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suspended Background Services:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(turbo.suspendedProcessNames, id: \.self) { name in
                        HStack(spacing: 6) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text(name)
                                .font(.caption)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            }

            Spacer()

            Button {
                if turbo.isTurboActive {
                    turbo.deactivateTurbo {}
                } else {
                    turbo.activateTurbo {}
                }
            } label: {
                Label(turbo.isTurboActive ? "Deactivate Turbo Mode" : "Activate Turbo Game Booster",
                      systemImage: turbo.isTurboActive ? "stop.fill" : "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .tint(turbo.isTurboActive ? .red : .accentColor)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
    }
}
