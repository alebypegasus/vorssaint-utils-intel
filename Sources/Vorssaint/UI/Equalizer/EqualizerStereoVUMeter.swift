// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Pro studio stereo VU & peak level meter with Liquid Glass styling.
struct EqualizerStereoVUMeter: View {
    @ObservedObject var spectrum = SpectrumAnalyzerDSP.shared

    var body: some View {
        HStack(spacing: 5) {
            // L Channel
            HStack(spacing: 2) {
                Text("L")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                vuChannelBar(level: spectrum.peakLevelL)
            }

            // R Channel
            HStack(spacing: 2) {
                Text("R")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                vuChannelBar(level: spectrum.peakLevelR)
            }

            // Clip LED Indicator
            Circle()
                .fill(spectrum.isClipping ? Color.red : Color.red.opacity(0.18))
                .frame(width: 7, height: 7)
                .overlay(
                    Circle()
                        .strokeBorder(spectrum.isClipping ? Color.red : Color.white.opacity(0.1), lineWidth: 0.8)
                )
                .shadow(color: spectrum.isClipping ? Color.red.opacity(0.9) : Color.clear, radius: 5)
                .help(spectrum.isClipping ? "Audio is clipping (> 0 dBFS)" : "Signal level OK")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.7)
                )
        )
    }

    private func vuChannelBar(level: Float) -> some View {
        ZStack(alignment: .bottom) {
            // Trough
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(width: 5, height: 24)

            // Dynamic Fill
            let fillHeight = CGFloat(max(0.0, min(1.0, level))) * 24
            Capsule()
                .fill(
                    LinearGradient(
                        colors: level > 0.85
                            ? [Color.red, Color.orange, Theme.LiquidGlass.cyanGlow]
                            : [Theme.LiquidGlass.cyanGlow, Color.blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5, height: max(2, fillHeight))
                .shadow(color: (level > 0.85 ? Color.orange : Theme.LiquidGlass.cyanGlow).opacity(0.6), radius: 3)
        }
    }
}
