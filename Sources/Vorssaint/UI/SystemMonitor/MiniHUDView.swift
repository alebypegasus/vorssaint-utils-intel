// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct MiniHUDView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var hud = MiniHUDService.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Mini System HUD", systemImage: "macwindow.on.rectangle")
                    .font(.headline)
                Spacer()
                Toggle("Floating HUD Window", isOn: $hud.isHUDVisible)
                    .toggleStyle(.switch)
            }
            .padding(.bottom, 4)

            // Sparkline Cards
            VStack(spacing: 12) {
                HUDSparklineCard(
                    title: "CPU Load",
                    currentText: String(format: "%.1f%%", hud.current.cpuUsage),
                    history: hud.cpuHistory,
                    color: .blue,
                    icon: "cpu"
                )

                HUDSparklineCard(
                    title: "RAM Pressure",
                    currentText: String(format: "%.1f%%", hud.current.ramPressure),
                    history: hud.ramHistory,
                    color: .purple,
                    icon: "memorychip"
                )

                HUDSparklineCard(
                    title: "Network Download",
                    currentText: ByteCountFormatter.string(fromByteCount: Int64(hud.current.networkInBps), countStyle: .file) + "/s",
                    history: hud.networkInHistory,
                    color: .green,
                    icon: "arrow.down.circle"
                )
            }
        }
        .padding(20)
    }

    private struct HUDSparklineCard: View {
        let title: String
        let currentText: String
        let history: [Double]
        let color: Color
        let icon: String

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(currentText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }

                // Sparkline canvas
                GeometryReader { proxy in
                    Path { path in
                        guard history.count > 1 else { return }
                        let maxVal = max(1.0, history.max() ?? 100.0)
                        let step = proxy.size.width / CGFloat(history.count - 1)

                        for (idx, val) in history.enumerated() {
                            let x = CGFloat(idx) * step
                            let normalized = CGFloat(val / maxVal)
                            let y = proxy.size.height - (normalized * proxy.size.height)
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 2)
                }
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.08)))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
        }
    }
}
