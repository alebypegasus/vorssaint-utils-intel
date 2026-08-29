// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Filter band inspector and table for fine-tuning parametric EQ bands.
struct EqualizerFilterTableView: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @Binding var selectedBandID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            // Table Header Bar
            HStack {
                Text("Parametric Filter Bands (\(equalizer.activeProfile.bands.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    equalizer.addBand()
                } label: {
                    Label("Add Band", systemImage: "plus.circle.fill")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    equalizer.resetToFlat()
                } label: {
                    Text("Flat")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 4)

            // Bands List ScrollView
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    let bands = equalizer.activeProfile.bands
                    ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                        filterBandRow(index: index, band: band)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 180)
        }
    }

    private func filterBandRow(index: Int, band: EqualizerBand) -> some View {
        let isSelected = selectedBandID == band.id

        return HStack(spacing: 10) {
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(band.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 24, alignment: .leading)

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
                HStack(spacing: 4) {
                    Image(systemName: band.type.systemImage)
                        .font(.system(size: 10))
                    Text(band.type.shortCode)
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(width: 48)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider().frame(height: 14)

            // Frequency (Hz)
            HStack(spacing: 4) {
                Text("Freq:")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text("\(Int(band.frequency)) Hz")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 62, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { log10(band.frequency) },
                        set: { val in
                            equalizer.updateBand(id: band.id) { $0.frequency = pow(10.0, val) }
                        }
                    ),
                    in: log10(20.0)...log10(20000.0)
                )
                .frame(width: 80)
            }

            Divider().frame(height: 14)

            // Gain (dB)
            if band.type.hasGain {
                HStack(spacing: 4) {
                    Text("Gain:")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%+.1f dB", band.gain))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(band.gain > 0.01 ? Color.orange : (band.gain < -0.01 ? Color.cyan : Color.primary))
                        .frame(width: 56, alignment: .trailing)

                    Slider(
                        value: Binding(
                            get: { band.gain },
                            set: { val in
                                equalizer.updateBand(id: band.id) { $0.gain = val }
                            }
                        ),
                        in: -24.0...24.0
                    )
                    .frame(width: 75)
                }
            } else {
                HStack {
                    Text("N/A")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 145)
            }

            Divider().frame(height: 14)

            // Q Factor (Bandwidth)
            HStack(spacing: 4) {
                Text("Q:")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", band.q))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 38, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { log10(band.q) },
                        set: { val in
                            equalizer.updateBand(id: band.id) { $0.q = pow(10.0, val) }
                        }
                    ),
                    in: log10(0.1)...log10(20.0)
                )
                .frame(width: 60)
            }

            Divider().frame(height: 14)

            // Channel Target Menu
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
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Delete Band Button
            Button {
                withAnimation(.liquidBouncy) {
                    equalizer.removeBand(id: band.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Delete this filter band")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.14) : Color.primary.opacity(0.04))
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.4))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    Theme.LiquidGlass.borderGradient(for: .dark, glow: isSelected ? Theme.LiquidGlass.cyanGlow : nil),
                    lineWidth: isSelected ? 1.0 : 0.65
                )
        )
        .shadow(color: isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.25) : Color.clear, radius: 6, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.liquidSpring) {
                selectedBandID = band.id
            }
        }
    }
}
