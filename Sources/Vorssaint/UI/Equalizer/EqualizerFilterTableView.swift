// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Adaptive filter band inspector and table for fine-tuning parametric EQ bands.
struct EqualizerFilterTableView: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @Binding var selectedBandID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            // Table Header Bar
            HStack {
                Text("Parametric Filter Bands (\(equalizer.activeProfile.bands.count))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let selectedID = selectedBandID, let index = equalizer.activeProfile.bands.firstIndex(where: { $0.id == selectedID }) {
                    Text("Selected: Band #\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                }
            }
            .padding(.horizontal, 4)

            // Bands List ScrollView
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 5) {
                    let bands = equalizer.activeProfile.bands
                    ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                        filterBandRow(index: index, band: band)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 80, maxHeight: 150)

            // Dynamic Active Band Inspector Bar
            if let activeBand = equalizer.activeProfile.bands.first(where: { $0.id == selectedBandID }) {
                activeBandInspector(band: activeBand)
            }
        }
    }

    // MARK: - Filter Band Row (Compact & Adaptive)

    private func filterBandRow(index: Int, band: EqualizerBand) -> some View {
        let isSelected = selectedBandID == band.id

        return HStack(spacing: 8) {
            // Enable toggle
            Toggle("", isOn: Binding(
                get: { band.isEnabled },
                set: { val in
                    equalizer.updateBand(id: band.id) { $0.isEnabled = val }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            // Band badge
            Text("#\(index + 1)")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(band.isEnabled ? Theme.LiquidGlass.cyanGlow : Color.secondary)
                .frame(width: 22, alignment: .leading)

            // Filter Type Menu
            Menu {
                ForEach(EqualizerFilterType.allCases) { type in
                    Button {
                        equalizer.updateBand(id: band.id) { $0.type = type }
                    } label: {
                        Label(type.displayName, systemImage: type.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: band.type.systemImage)
                        .font(.system(size: 9.5))
                    Text(band.type.shortCode)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .frame(width: 44)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider().frame(height: 12)

            // Frequency Display
            HStack(spacing: 3) {
                Text("Freq:")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(Int(band.frequency)) Hz")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .frame(minWidth: 55, alignment: .trailing)
            }

            Divider().frame(height: 12)

            // Gain Display
            HStack(spacing: 3) {
                Text("Gain:")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if band.type.hasGain {
                    Text(String(format: "%+.1f dB", band.gain))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(band.gain > 0.01 ? Theme.LiquidGlass.amberGlow : (band.gain < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                        .frame(minWidth: 52, alignment: .trailing)
                } else {
                    Text("—")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 52, alignment: .center)
                }
            }

            Divider().frame(height: 12)

            // Q Display
            HStack(spacing: 3) {
                Text("Q:")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", band.q))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .frame(minWidth: 34, alignment: .trailing)
            }

            Divider().frame(height: 12)

            // Channel Menu
            Menu {
                ForEach(EqualizerChannelTarget.allCases) { ch in
                    Button {
                        equalizer.updateBand(id: band.id) { $0.channel = ch }
                    } label: {
                        Text(ch.displayName)
                    }
                }
            } label: {
                Text(band.channel.shortLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer(minLength: 4)

            // Delete Band Button
            Button {
                withAnimation(.liquidBouncy) {
                    if selectedBandID == band.id {
                        selectedBandID = nil
                    }
                    equalizer.removeBand(id: band.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Delete this filter band")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.5)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.14) : Color.primary.opacity(0.04))
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.4))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    Theme.LiquidGlass.borderGradient(for: .dark, glow: isSelected ? Theme.LiquidGlass.cyanGlow : nil),
                    lineWidth: isSelected ? 1.0 : 0.65
                )
        )
        .shadow(color: isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.22) : Color.clear, radius: 5, x: 0, y: 1.5)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.liquidSpring) {
                selectedBandID = band.id
            }
        }
    }

    // MARK: - Active Band Quick Inspector (Large Adaptive Touch Controls)

    private func activeBandInspector(band: EqualizerBand) -> some View {
        HStack(spacing: 12) {
            // Frequency Inspector Slider
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Freq:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
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
            }
            .frame(minWidth: 100, maxWidth: .infinity)

            // Gain Inspector Slider (if supported by filter type)
            if band.type.hasGain {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Gain:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%+.1f dB", band.gain))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(band.gain > 0.01 ? Theme.LiquidGlass.amberGlow : (band.gain < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                    }
                    Slider(
                        value: Binding(
                            get: { band.gain },
                            set: { val in
                                equalizer.updateBand(id: band.id) { $0.gain = val }
                            }
                        ),
                        in: -24.0...24.0
                    )
                }
                .frame(minWidth: 100, maxWidth: .infinity)
            }

            // Q (Bandwidth) Slider
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Q (Bandwidth):")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", band.q))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
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
            }
            .frame(minWidth: 90, maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark, glow: Theme.LiquidGlass.cyanGlow.opacity(0.4)), lineWidth: 0.75)
                )
        )
    }
}
