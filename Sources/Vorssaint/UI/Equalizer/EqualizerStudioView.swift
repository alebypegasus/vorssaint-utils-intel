// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Professional Equalizer Studio window inspired by Equalizer APO and top-tier DAW equalizer plugins.
struct EqualizerStudioView: View {
    @ObservedObject private var equalizer = AudioEqualizerService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @State private var selectedBandID: UUID?
    @State private var showPresetSheet = false
    @State private var showToneGenerator = false

    var body: some View {
        VStack(spacing: 10) {
            // Pro DAW Unified Header Bar
            headerBar

            // Interactive Bode Plot Graph with FFT Spectrum
            EqualizerBodePlotView(
                equalizer: equalizer,
                selectedBandID: $selectedBandID
            )
            .frame(minHeight: 200, idealHeight: 290, maxHeight: .infinity)

            // Mode-specific Bottom Console
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

            // Footer info & utility bar
            footerBar
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 32)
        .frame(minWidth: 760, idealWidth: 880, maxWidth: .infinity,
               minHeight: 560, idealHeight: 640, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.10)
                    .ignoresSafeArea()
                HUDBackdrop(cornerRadius: 16)
                    .opacity(0.85)
                // Subtle radial studio ambience
                RadialGradient(
                    colors: [
                        Theme.LiquidGlass.cyanGlow.opacity(0.06),
                        Theme.LiquidGlass.violetGlow.opacity(0.03),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPresetSheet) {
            EqualizerPresetSheet(equalizer: equalizer)
        }
        .sheet(isPresented: $showToneGenerator) {
            EqualizerToneGeneratorSheet()
        }
    }

    // MARK: - Header Bar (Clean, Unified, Never Overlapping)

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Power Button
            Button {
                withAnimation(.liquidBouncy) {
                    equalizer.isEnabled.toggle()
                }
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(equalizer.isEnabled ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 30, height: 30)
                    .background(
                        ZStack {
                            Circle()
                                .fill(equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.35) : Color.white.opacity(0.05))
                            if equalizer.isEnabled {
                                Circle()
                                    .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.7))
                            }
                        }
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                equalizer.isEnabled
                                    ? Theme.LiquidGlass.cyanGlow.opacity(0.9)
                                    : Color.white.opacity(0.12),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.5) : Color.clear, radius: 6)
            }
            .buttonStyle(.plain)
            .help(equalizer.isEnabled ? "Disable Equalizer" : "Enable Equalizer")

            // A/B Bypass Pill
            Button {
                withAnimation(.liquidBouncy) {
                    equalizer.isBypassed.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: equalizer.isBypassed ? "pause.circle.fill" : "bolt.fill")
                        .font(.system(size: 9.5))
                    Text(equalizer.isBypassed ? "BYPASS" : "ACTIVE")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(equalizer.isBypassed ? Color.orange.opacity(0.22) : Theme.LiquidGlass.cyanGlow.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            equalizer.isBypassed ? Color.orange.opacity(0.7) : Theme.LiquidGlass.cyanGlow.opacity(0.6),
                            lineWidth: 0.85
                        )
                )
                .foregroundStyle(equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow)
                .shadow(color: (equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow).opacity(0.3), radius: 4)
            }
            .buttonStyle(.plain)
            .help("Instant A/B comparison (Bypass all filter processing)")

            // Custom Liquid Mode Switcher (Pills that never clip text)
            customModeSwitcher

            Spacer(minLength: 4)

            // Target Scope & Preset Menus
            targetScopeAndPresetBar

            Spacer(minLength: 4)

            // Test Tone Generator Tool
            Button {
                showToneGenerator = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    Text("Tone Gen")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7)
                )
            }
            .buttonStyle(.plain)
            .help("Acoustic Tone & Noise Generator for speaker/headphone calibration")

            // Stereo VU Peak Meter
            EqualizerStereoVUMeter()

            // Preamp Gain Slider
            HStack(spacing: 5) {
                Text("Preamp")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))

                Text(String(format: "%+.1f dB", equalizer.activeProfile.preamp))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(equalizer.activeProfile.preamp > 0.01 ? Theme.LiquidGlass.amberGlow : (equalizer.activeProfile.preamp < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.white))
                    .frame(width: 48, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { equalizer.activeProfile.preamp },
                        set: { val in
                            let snapped = abs(val) < 0.2 ? 0.0 : round(val * 10) / 10
                            equalizer.updatePreamp(snapped)
                        }
                    ),
                    in: -20.0...20.0
                )
                .frame(width: 65)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.65)
                    )
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.75)
                )
        )
    }

    // MARK: - Custom Liquid Mode Switcher

    private var customModeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(EqualizerMode.allCases) { mode in
                let isSelected = equalizer.activeProfile.mode == mode
                Button {
                    withAnimation(.liquidSpring) {
                        equalizer.activeProfile.mode = mode
                        equalizer.syncDSP()
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(Theme.LiquidGlass.cyanGlow.opacity(0.22))
                                    Capsule()
                                        .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.4))
                                } else {
                                    Capsule()
                                        .fill(Color.white.opacity(0.03))
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.8) : Color.clear,
                                    lineWidth: 0.85
                                )
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                        .shadow(color: isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.35) : Color.clear, radius: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                )
        )
    }

    // MARK: - Target Scope & Preset Dropdowns

    private var targetScopeAndPresetBar: some View {
        HStack(spacing: 6) {
            // Target Scope
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
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    Text(equalizer.activeTargetScope.displayName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Active Preset Menu
            Menu {
                Section(header: Text("Presets")) {
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
                    Label("Manage Profiles & AutoEq…", systemImage: "slider.vertical.3")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.LiquidGlass.violetGlow)
                    Text(equalizer.activeProfile.name)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
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
                    .font(.system(size: 10))
                Text("Equalizer APO Engine • 64-bit Direct Form II Biquads • Zero Latency")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Button {
                showPresetSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9.5))
                    Text("Import / Export Profiles")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .foregroundStyle(Color.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}
