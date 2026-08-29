// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Compact stereo VU & peak level meter with Liquid Glass styling.
struct EqualizerStereoVUMeter: View {
    @ObservedObject var spectrum = SpectrumAnalyzerDSP.shared

    var body: some View {
        HStack(spacing: 4) {
            // Left channel
            VStack(spacing: 1.5) {
                vuChannelBar(level: spectrum.peakLevelL)
                Text("L")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Right channel
            VStack(spacing: 1.5) {
                vuChannelBar(level: spectrum.peakLevelR)
                Text("R")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Clip LED
            VStack(spacing: 1.5) {
                Circle()
                    .fill(spectrum.isClipping ? Color.red : Color.red.opacity(0.15))
                    .frame(width: 6.5, height: 6.5)
                    .shadow(color: spectrum.isClipping ? Color.red.opacity(0.9) : Color.clear, radius: 4)
                Text("CLIP")
                    .font(.system(size: 6.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(spectrum.isClipping ? Color.red : Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.6)
                )
        )
    }

    private func vuChannelBar(level: Float) -> some View {
        ZStack(alignment: .bottom) {
            // Trough
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(width: 4.5, height: 22)

            // Dynamic Fill
            let fillHeight = CGFloat(max(0.0, min(1.0, level))) * 22
            Capsule()
                .fill(
                    LinearGradient(
                        colors: level > 0.85 ? [Color.red, Color.orange, Theme.LiquidGlass.cyanGlow] : [Theme.LiquidGlass.cyanGlow, Color.blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4.5, height: max(2, fillHeight))
                .shadow(color: (level > 0.85 ? Color.orange : Theme.LiquidGlass.cyanGlow).opacity(0.5), radius: 2)
        }
    }
}
