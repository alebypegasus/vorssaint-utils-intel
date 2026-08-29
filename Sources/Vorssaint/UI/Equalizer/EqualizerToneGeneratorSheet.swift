// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Liquid Glass modal sheet for the acoustic test tone generator.
struct EqualizerToneGeneratorSheet: View {
    @ObservedObject var toneGenerator = AudioToneGenerator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    Text("Acoustic Tone & Noise Generator")
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                Button {
                    toneGenerator.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Signal Type Picker
            Picker("", selection: $toneGenerator.signalType) {
                ForEach(ToneSignalType.allCases) { type in
                    Label(type.rawValue, systemImage: type.systemImage).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Frequency Display & Slider (Sine / Sweep)
            if toneGenerator.signalType == .sine || toneGenerator.signalType == .sweep {
                VStack(spacing: 8) {
                    HStack {
                        Text("Frequency:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(toneGenerator.frequency)) Hz")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    }

                    if toneGenerator.signalType == .sine {
                        Slider(
                            value: Binding(
                                get: { log10(toneGenerator.frequency) },
                                set: { toneGenerator.frequency = pow(10.0, $0) }
                            ),
                            in: log10(20.0)...log10(20000.0)
                        )

                        // Quick Frequency Chips
                        HStack(spacing: 8) {
                            ForEach([60, 125, 250, 500, 1000, 2000, 4000, 8000, 12000], id: \.self) { freq in
                                Button("\(freq < 1000 ? "\(freq)" : "\(freq/1000)k")") {
                                    toneGenerator.frequency = Double(freq)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    } else {
                        // Sweep Progress Bar
                        ProgressView(value: toneGenerator.sweepProgress, total: 1.0)
                            .tint(Theme.LiquidGlass.cyanGlow)
                        Text("Auto-sweeping 20 Hz → 20 kHz (10s cycle)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 10)
            } else {
                // Noise description card
                VStack(alignment: .leading, spacing: 6) {
                    Text(toneGenerator.signalType == .pinkNoise ? "Pink Noise: Equal energy per octave. Ideal for tuning parametric EQ and calibrating headphone balance." : "White Noise: Flat power spectral density across all frequencies.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 10)
            }

            // Output Volume Slider
            VStack(spacing: 6) {
                HStack {
                    Text("Generator Volume:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", toneGenerator.outputVolume * 100))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }

                Slider(value: $toneGenerator.outputVolume, in: 0.01...1.0)
            }

            // Play / Stop Master Button
            Button {
                withAnimation(.liquidBouncy) {
                    toneGenerator.togglePlayback()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: toneGenerator.isPlaying ? "stop.fill" : "play.fill")
                    Text(toneGenerator.isPlaying ? "Stop Tone Generator" : "Start Test Tone")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(toneGenerator.isPlaying ? Color.red : Theme.LiquidGlass.cyanGlow)
            .controlSize(.large)
        }
        .padding(18)
        .frame(width: 440)
        .panelGlassSurface(cornerRadius: 14)
    }
}
