// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Graphic Equalizer view with ISO frequency vertical sliders (10, 15, or 31 bands).
struct EqualizerGraphicSlidersView: View {
    @ObservedObject var equalizer: AudioEqualizerService

    var body: some View {
        VStack(spacing: 8) {
            // Header bar
            HStack {
                Text(equalizer.activeProfile.mode.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    equalizer.resetToFlat()
                } label: {
                    Label("Reset All to 0 dB", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 4)

            // Sliders HStack / ScrollView
            let freqs = GraphicEqualizerFrequencies.frequencies(for: equalizer.activeProfile.mode)
            ScrollView(.horizontal, showsIndicators: freqs.count > 15) {
                HStack(spacing: freqs.count > 15 ? 8 : 14) {
                    ForEach(freqs, id: \.self) { freq in
                        graphicBandColumn(freq: freq)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(height: 185)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.35))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }

    private func graphicBandColumn(freq: Double) -> some View {
        let key = GraphicEqualizerFrequencies.formatFrequency(freq)
        let gain = equalizer.activeProfile.graphicGains[key] ?? 0.0

        return VStack(spacing: 4) {
            // Gain readout
            Text(String(format: "%+.0f", gain))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(gain > 0.01 ? Theme.LiquidGlass.amberGlow : (gain < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.secondary))
                .frame(height: 14)

            // Vertical Slider
            CustomVerticalSlider(
                value: Binding(
                    get: { gain },
                    set: { val in
                        equalizer.updateGraphicGain(freqKey: key, gain: val)
                    }
                ),
                range: -24.0...24.0
            )
            .frame(width: 20, height: 114)

            // Frequency label
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(height: 12)
        }
    }
}

/// A compact vertical slider for graphic equalizer faders with Liquid Glass look and feel.
private struct CustomVerticalSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbY = height - (CGFloat(fraction) * height)

            ZStack(alignment: .top) {
                // Track background
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 4.5, height: height)
                    .position(x: width / 2, y: height / 2)

                // Zero line indicator
                let zeroFraction = (0.0 - range.lowerBound) / (range.upperBound - range.lowerBound)
                let zeroY = height - (CGFloat(zeroFraction) * height)
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 12, height: 1.5)
                    .position(x: width / 2, y: zeroY)

                // Fill from zero to current level with glowing gradient
                let fillHeight = abs(thumbY - zeroY)
                let fillCenterY = min(thumbY, zeroY) + fillHeight / 2
                Capsule()
                    .fill(
                        value >= 0
                            ? LinearGradient(colors: [Theme.LiquidGlass.amberGlow, Color.orange], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Theme.LiquidGlass.cyanGlow, Color.blue], startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: 4.5, height: fillHeight)
                    .position(x: width / 2, y: fillCenterY)
                    .shadow(color: (value >= 0 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.cyanGlow).opacity(abs(value) > 1.0 ? 0.6 : 0.0), radius: 4)

                // Fader Thumb / Knob with specular shine
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 0.8)
                    )
                    .overlay(
                        Rectangle()
                            .fill(value >= 0 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.cyanGlow)
                            .frame(height: 1.5)
                    )
                    .frame(width: 15, height: 11)
                    .shadow(color: Color.black.opacity(0.45), radius: 3, x: 0, y: 1.5)
                    .position(x: width / 2, y: max(6, min(height - 6, thumbY)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationY = max(0, min(height, gesture.location.y))
                        let newFraction = 1.0 - (locationY / height)
                        let rawValue = range.lowerBound + Double(newFraction) * (range.upperBound - range.lowerBound)
                        // Snap to 0 if very close
                        if abs(rawValue) < 0.5 {
                            value = 0.0
                        } else {
                            value = round(rawValue * 2) / 2 // snap to 0.5 dB
                        }
                    }
            )
        }
    }
}
