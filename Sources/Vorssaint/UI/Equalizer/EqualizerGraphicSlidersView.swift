// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Pro studio graphic equalizer fader rack with illuminated tracks and ISO frequencies (10, 15, or 31 bands - supports Light & Dark mode).
struct EqualizerGraphicSlidersView: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.LiquidGlass.violetGlow)
                    Text(equalizer.activeProfile.mode.displayName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.85))
                }

                Spacer()

                Button {
                    withAnimation(.liquidSpring) {
                        equalizer.resetToFlat()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9.5))
                        Text("Reset Flat (0 dB)")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.primary.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)

            // Fader Rack ScrollView
            let freqs = GraphicEqualizerFrequencies.frequencies(for: equalizer.activeProfile.mode)
            ScrollView(.horizontal, showsIndicators: freqs.count > 15) {
                HStack(spacing: freqs.count > 15 ? 6 : 12) {
                    ForEach(freqs, id: \.self) { freq in
                        graphicBandColumn(freq: freq)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(height: 175)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colorScheme == .light ? Color.white.opacity(0.7) : Color.black.opacity(0.4))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.25))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.4), radius: 8, y: 3)
        }
    }

    private func graphicBandColumn(freq: Double) -> some View {
        let key = GraphicEqualizerFrequencies.formatFrequency(freq)
        let gain = equalizer.activeProfile.graphicGains[key] ?? 0.0

        return VStack(spacing: 4) {
            // Numeric Readout
            Text(String(format: "%+.0f", gain))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(gain > 0.01 ? Theme.LiquidGlass.amberGlow : (gain < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.secondary))
                .frame(height: 12)

            // Illuminated Vertical Fader
            CustomStudioVerticalSlider(
                value: Binding(
                    get: { gain },
                    set: { val in
                        equalizer.updateGraphicGain(freqKey: key, gain: val)
                    }
                ),
                range: -24.0...24.0
            )
            .frame(width: 18, height: 106)

            // Frequency Key
            Text(key)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(colorScheme == .light ? Color.primary.opacity(0.85) : Color.white.opacity(0.75))
                .frame(height: 12)
        }
    }
}

/// A sleek vertical studio fader with glowing track, 0 dB detent, and brushed knob.
private struct CustomStudioVerticalSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbY = height - (CGFloat(fraction) * height)

            ZStack(alignment: .top) {
                // Fader Slot Background
                Capsule()
                    .fill(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.08))
                    .frame(width: 4, height: height)
                    .position(x: width / 2, y: height / 2)

                // 0 dB Center Mark
                let zeroFraction = (0.0 - range.lowerBound) / (range.upperBound - range.lowerBound)
                let zeroY = height - (CGFloat(zeroFraction) * height)
                Rectangle()
                    .fill(colorScheme == .light ? Color.black.opacity(0.3) : Color.white.opacity(0.45))
                    .frame(width: 12, height: 1.2)
                    .position(x: width / 2, y: zeroY)

                // Illuminated Level Fill
                let fillHeight = abs(thumbY - zeroY)
                let fillCenterY = min(thumbY, zeroY) + fillHeight / 2
                Capsule()
                    .fill(
                        value >= 0
                            ? LinearGradient(colors: [Theme.LiquidGlass.amberGlow, Color.orange], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Theme.LiquidGlass.cyanGlow, Color.blue], startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: 4, height: fillHeight)
                    .position(x: width / 2, y: fillCenterY)
                    .shadow(color: (value >= 0 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.cyanGlow).opacity(abs(value) > 1.0 ? 0.7 : 0.0), radius: 3)

                // Studio Fader Knob
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .light ? [Color.white, Color(white: 0.88)] : [Color(white: 0.95), Color(white: 0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.25 : 0.6), radius: 3, y: 1.5)

                    // Center Line on Knob
                    Rectangle()
                        .fill(value >= 0 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.cyanGlow)
                        .frame(width: 10, height: 1.5)
                }
                .frame(width: 15, height: 10)
                .position(x: width / 2, y: max(5, min(height - 5, thumbY)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationY = max(0, min(height, gesture.location.y))
                        let newFraction = 1.0 - (locationY / height)
                        let rawValue = range.lowerBound + Double(newFraction) * (range.upperBound - range.lowerBound)
                        // Snap to 0 if within 0.4 dB
                        if abs(rawValue) < 0.4 {
                            value = 0.0
                        } else {
                            value = round(rawValue * 2) / 2 // snap to 0.5 dB
                        }
                    }
            )
        }
    }
}
