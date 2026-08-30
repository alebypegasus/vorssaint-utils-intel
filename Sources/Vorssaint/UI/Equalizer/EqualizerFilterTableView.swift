// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Pro studio band strip & focused inspector console for parametric equalizer bands (supports Light & Dark mode).
struct EqualizerFilterTableView: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @Binding var selectedBandID: UUID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Top Band Carousel Strip
            bandCarouselStrip

            // Focused Band Inspector Console Deck
            if let selectedID = selectedBandID,
               let band = equalizer.activeProfile.bands.first(where: { $0.id == selectedID }) {
                focusedBandInspector(band: band)
            } else if let firstBand = equalizer.activeProfile.bands.first {
                focusedBandInspector(band: firstBand)
            } else {
                emptyBandsPrompt
            }
        }
        .onAppear {
            if selectedBandID == nil, let first = equalizer.activeProfile.bands.first {
                selectedBandID = first.id
            }
        }
    }

    // MARK: - Band Carousel Strip

    private var bandCarouselStrip: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    let bands = equalizer.activeProfile.bands
                    ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                        bandChip(index: index, band: band)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }

            // Quick Add Band & Flat
            HStack(spacing: 4) {
                Button {
                    withAnimation(.liquidBouncy) {
                        equalizer.addBand()
                        if let last = equalizer.activeProfile.bands.last {
                            selectedBandID = last.id
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.LiquidGlass.cyanGlow.opacity(colorScheme == .light ? 0.22 : 0.18))
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.LiquidGlass.cyanGlow.opacity(0.6), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .help("Add a new parametric filter band")
                .fixedSize()

                Button {
                    withAnimation(.liquidSpring) {
                        equalizer.resetToFlat()
                    }
                } label: {
                    Text("Flat")
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Reset all bands to 0 dB flat")
                .fixedSize()
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .light ? Color.white.opacity(0.7) : Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.65)
                )
        )
    }

    private func bandChip(index: Int, band: EqualizerBand) -> some View {
        let isSelected = selectedBandID == band.id
        let color = colorForFilterType(band.type)
        let isLight = colorScheme == .light

        return Button {
            withAnimation(.liquidSpring) {
                selectedBandID = band.id
            }
        } label: {
            HStack(spacing: 4) {
                // Type Icon
                Image(systemName: band.type.systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)

                // Band Index & Frequency
                Text("#\(index + 1) \(formatFrequencyShort(band.frequency))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(band.isEnabled ? (isLight ? Color.primary : Color.white) : Color.secondary.opacity(0.6))
                    .lineLimit(1)

                // Gain badge if applicable
                if band.type.hasGain && abs(band.gain) > 0.05 {
                    Text(String(format: "%+.0f", band.gain))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(band.gain > 0 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.cyanGlow)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                ZStack {
                    Capsule()
                        .fill(isSelected ? color.opacity(isLight ? 0.25 : 0.2) : Color.primary.opacity(0.05))
                    if isSelected {
                        Capsule()
                            .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.4))
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? color.opacity(0.85) : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 1.2 : 0.6
                    )
            )
            .shadow(color: isSelected ? color.opacity(0.35) : Color.clear, radius: 4)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    // MARK: - Focused Band Inspector Console Deck

    private func focusedBandInspector(band: EqualizerBand) -> some View {
        let index = equalizer.activeProfile.bands.firstIndex(where: { $0.id == band.id }) ?? 0
        let color = colorForFilterType(band.type)
        let isLight = colorScheme == .light

        return VStack(spacing: 8) {
            // Deck Header: Band Index, On/Off, Filter Types, Channel, Delete
            HStack(spacing: 8) {
                // On/Off Toggle
                Button {
                    withAnimation(.liquidBouncy) {
                        equalizer.updateBand(id: band.id) { $0.isEnabled.toggle() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: band.isEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                        Text("#\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(band.isEnabled ? color : Color.secondary)
                }
                .buttonStyle(.plain)
                .fixedSize()

                Divider().frame(height: 14)

                // Filter Type Selector Pills
                HStack(spacing: 3) {
                    ForEach(EqualizerFilterType.allCases) { type in
                        Button {
                            withAnimation(.liquidSpring) {
                                equalizer.updateBand(id: band.id) { $0.type = type }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 8.5))
                                Text(type.shortCode)
                                    .font(.system(size: 9.5, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(band.type == type ? color.opacity(isLight ? 0.22 : 0.25) : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(band.type == type ? color.opacity(0.8) : Color.clear, lineWidth: 0.8)
                            )
                            .foregroundStyle(band.type == type ? (isLight ? Color.primary : Color.white) : Color.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                }

                Spacer(minLength: 4)

                // Target Channel Selector Menu
                Menu {
                    ForEach(EqualizerChannelTarget.allCases) { ch in
                        Button {
                            equalizer.updateBand(id: band.id) { $0.channel = ch }
                        } label: {
                            Text(ch.displayName)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 9.5))
                        Text(band.channel.displayName)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.primary.opacity(0.85))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Delete Band
                Button {
                    withAnimation(.liquidBouncy) {
                        equalizer.removeBand(id: band.id)
                        selectedBandID = equalizer.activeProfile.bands.first?.id
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Delete this band")
                .fixedSize()
            }

            // Deck Controls: Frequency, Gain, Q-Factor
            HStack(spacing: 14) {
                // 1. Frequency Control
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("FREQUENCY")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text("\(Int(band.frequency)) Hz")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    }

                    Slider(
                        value: Binding(
                            get: { log10(band.frequency) },
                            set: { val in
                                equalizer.updateBand(id: band.id) { $0.frequency = pow(10.0, val) }
                            }
                        ),
                        in: log10(20.0)...log10(20000.0)
                    )
                    .tint(Theme.LiquidGlass.cyanGlow)
                }
                .frame(minWidth: 140, maxWidth: .infinity)

                // 2. Gain Control (if supported)
                if band.type.hasGain {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("GAIN")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            Text(String(format: "%+.1f dB", band.gain))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(band.gain > 0.01 ? Theme.LiquidGlass.amberGlow : (band.gain < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                        }

                        Slider(
                            value: Binding(
                                get: { band.gain },
                                set: { val in
                                    // Center detent snap near 0
                                    let snapped = abs(val) < 0.2 ? 0.0 : round(val * 10) / 10
                                    equalizer.updateBand(id: band.id) { $0.gain = snapped }
                                }
                            ),
                            in: -24.0...24.0
                        )
                        .tint(band.gain >= 0 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.cyanGlow)
                    }
                    .frame(minWidth: 140, maxWidth: .infinity)
                }

                // 3. Q-Factor Control
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("BANDWIDTH (Q)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        Text(String(format: "%.2f", band.q))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.LiquidGlass.violetGlow)
                    }

                    Slider(
                        value: Binding(
                            get: { log10(band.q) },
                            set: { val in
                                equalizer.updateBand(id: band.id) { $0.q = pow(10.0, val) }
                            }
                        ),
                        in: log10(0.1)...log10(20.0)
                    )
                    .tint(Theme.LiquidGlass.violetGlow)
                }
                .frame(minWidth: 120, maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isLight ? Color.white.opacity(0.8) : Color.black.opacity(0.45))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.3))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme, glow: color.opacity(0.5)), lineWidth: 0.85)
        )
        .shadow(color: Color.black.opacity(isLight ? 0.1 : 0.4), radius: 8, y: 3)
    }

    private var emptyBandsPrompt: some View {
        HStack {
            Text("No filter bands configured.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Add First Band") {
                equalizer.addBand()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
    }

    private func formatFrequencyShort(_ freq: Double) -> String {
        if freq >= 1000 {
            return String(format: "%.1fk", freq / 1000.0).replacingOccurrences(of: ".0k", with: "k")
        } else {
            return "\(Int(freq))"
        }
    }

    private func colorForFilterType(_ type: EqualizerFilterType) -> Color {
        switch type {
        case .peaking: return Theme.LiquidGlass.cyanGlow
        case .lowShelf: return Theme.LiquidGlass.amberGlow
        case .highShelf: return Theme.LiquidGlass.violetGlow
        case .highPass: return Theme.LiquidGlass.emeraldGlow
        case .lowPass: return Theme.LiquidGlass.magentaGlow
        case .bandPass: return Color.blue
        case .notch: return Color.red
        case .allPass: return Color.purple
        }
    }
}
