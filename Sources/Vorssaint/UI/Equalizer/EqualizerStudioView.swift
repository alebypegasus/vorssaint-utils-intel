// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Professional Equalizer Studio window view inspired by Equalizer APO with adaptive responsive layout.
struct EqualizerStudioView: View {
    @ObservedObject private var equalizer = AudioEqualizerService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @State private var selectedBandID: UUID?
    @State private var showPresetSheet = false
    @State private var showToneGenerator = false

    var body: some View {
        VStack(spacing: 12) {
            // Adaptive Master Studio Header Bar
            headerBar

            // Interactive Bode Plot Graph with FFT Spectrum (Dynamically expands)
            EqualizerBodePlotView(
                equalizer: equalizer,
                selectedBandID: $selectedBandID
            )
            .frame(minHeight: 180, idealHeight: 260, maxHeight: 400)

            // Mode-specific controls
            if equalizer.activeProfile.mode == .parametric {
                EqualizerFilterTableView(
                    equalizer: equalizer,
                    selectedBandID: $selectedBandID
                )
            } else {
                EqualizerGraphicSlidersView(
                    equalizer: equalizer
                )
            }

            Divider()
                .opacity(0.4)

            // Footer info bar
            footerBar
        }
        .padding(16)
        .frame(minWidth: 640, idealWidth: 860, maxWidth: .infinity,
               minHeight: 520, idealHeight: 660, maxHeight: .infinity)
        .panelGlassSurface(cornerRadius: 16)
        .sheet(isPresented: $showPresetSheet) {
            EqualizerPresetSheet(equalizer: equalizer)
        }
        .sheet(isPresented: $showToneGenerator) {
            EqualizerToneGeneratorSheet()
        }
    }

    // MARK: - Adaptive Header Bar

    private var headerBar: some View {
        VStack(spacing: 8) {
            // Tier 1: Core Master Engine Controls
            HStack(spacing: 10) {
                // Power Button with Neon Liquid Glow
                Button {
                    withAnimation(.liquidBouncy) {
                        equalizer.isEnabled.toggle()
                    }
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(equalizer.isEnabled ? Color.white : Color.secondary.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.35) : Color.white.opacity(0.06))
                                if equalizer.isEnabled {
                                    Circle()
                                        .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.6))
                                }
                            }
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    equalizer.isEnabled
                                        ? Theme.LiquidGlass.cyanGlow.opacity(0.85)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.5) : Color.clear, radius: 6)
                }
                .buttonStyle(.plain)
                .help(equalizer.isEnabled ? "Disable Equalizer" : "Enable Equalizer")

                // A/B Bypass Button
                Button {
                    withAnimation(.liquidBouncy) {
                        equalizer.isBypassed.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: equalizer.isBypassed ? "pause.circle.fill" : "bolt.fill")
                            .font(.system(size: 10))
                        Text(equalizer.isBypassed ? "BYPASS" : "ACTIVE")
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(equalizer.isBypassed ? Color.orange.opacity(0.2) : Theme.LiquidGlass.cyanGlow.opacity(0.18))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Theme.LiquidGlass.borderGradient(for: .dark, glow: equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow),
                                lineWidth: 0.85
                            )
                    )
                    .foregroundStyle(equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow)
                    .shadow(color: (equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow).opacity(0.3), radius: 4)
                }
                .buttonStyle(.plain)
                .help("Instant A/B comparison (Bypass filter processing)")

                // Mode Selector
                Picker("", selection: Binding(
                    get: { equalizer.activeProfile.mode },
                    set: { newMode in
                        withAnimation(.liquidSpring) {
                            equalizer.activeProfile.mode = newMode
                            equalizer.syncDSP()
                        }
                    }
                )) {
                    ForEach(EqualizerMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Spacer(minLength: 4)

                // Stereo VU Peak Meter
                EqualizerStereoVUMeter()

                // Preamp Gain Slider
                HStack(spacing: 5) {
                    Text("Preamp:")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(String(format: "%+.1f dB", equalizer.activeProfile.preamp))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(equalizer.activeProfile.preamp > 0.01 ? Theme.LiquidGlass.amberGlow : (equalizer.activeProfile.preamp < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                        .frame(width: 50, alignment: .trailing)

                    Slider(
                        value: Binding(
                            get: { equalizer.activeProfile.preamp },
                            set: { val in
                                equalizer.updatePreamp(val)
                            }
                        ),
                        in: -20.0...20.0
                    )
                    .frame(width: 70)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.6)
                        )
                )
            }

            // Tier 2: Profile, Target Scope & Swiss Army Knife Utilities
            HStack(spacing: 8) {
                // Target Scope Picker
                Menu {
                    Button {
                        equalizer.activeTargetScope = .globalMaster
                    } label: {
                        Label("Global Output (All System Audio)", systemImage: "speaker.wave.3.fill")
                    }

                    if !mixer.apps.isEmpty {
                        Divider()
                        ForEach(mixer.apps) { app in
                            Button {
                                equalizer.activeTargetScope = .app(bundleID: app.persistenceID ?? app.id, name: app.name)
                            } label: {
                                Label(app.name, systemImage: "app.fill")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: scopeIcon)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                        Text(equalizer.activeTargetScope.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)

                // Preset Selector Menu
                Menu {
                    Section(header: Text("Profiles")) {
                        ForEach(equalizer.allProfiles()) { profile in
                            Button {
                                equalizer.selectProfile(id: profile.id)
                            } label: {
                                if equalizer.activeProfile.id == profile.id {
                                    Label(profile.name, systemImage: "checkmark")
                                } else {
                                    Text(profile.name)
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        showPresetSheet = true
                    } label: {
                        Label("Manage & Import Profiles…", systemImage: "slider.vertical.3")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.LiquidGlass.violetGlow)
                        Text(equalizer.activeProfile.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)

                Spacer(minLength: 4)

                // Acoustic Test Tone Generator Button
                Button {
                    showToneGenerator = true
                } label: {
                    Label("Tone Generator", systemImage: "waveform.path.ecg")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if equalizer.activeProfile.mode == .parametric {
                    Button {
                        withAnimation(.liquidBouncy) {
                            equalizer.addBand()
                        }
                    } label: {
                        Label("Add Band", systemImage: "plus")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        withAnimation(.liquidSpring) {
                            equalizer.resetToFlat()
                        }
                    } label: {
                        Text("Flat")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var scopeIcon: String {
        switch equalizer.activeTargetScope {
        case .globalMaster: return "speaker.wave.3.fill"
        case .app: return "app.fill"
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    .font(.system(size: 11))
                Text("Equalizer APO Engine • 64-bit Direct Form II Biquads • Zero Latency")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showPresetSheet = true
            } label: {
                Label("Import / Export", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
