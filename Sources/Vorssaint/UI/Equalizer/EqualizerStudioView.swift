// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Professional Equalizer Studio window supporting dynamic Light and Dark mode.
struct EqualizerStudioView: View {
    @ObservedObject private var equalizer = AudioEqualizerService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedBandID: UUID?
    @State private var showPresetSheet = false
    @State private var showToneGenerator = false

    var body: some View {
        VStack(spacing: 10) {
            // Pro DAW Unified Responsive Header Bar
            headerBar

            // Interactive Bode Plot Graph with FFT Spectrum
            EqualizerBodePlotView(
                equalizer: equalizer,
                selectedBandID: $selectedBandID
            )
            .frame(minHeight: 220, idealHeight: 300, maxHeight: .infinity)

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
        .frame(minWidth: 860, idealWidth: 920, maxWidth: .infinity,
               minHeight: 560, idealHeight: 640, maxHeight: .infinity)
        .background(
            ZStack {
                if colorScheme == .light {
                    Color(red: 0.96, green: 0.97, blue: 0.98)
                        .ignoresSafeArea()
                    HUDBackdrop(cornerRadius: 16, contrast: .standard)
                        .opacity(0.85)
                } else {
                    Color(red: 0.06, green: 0.07, blue: 0.10)
                        .ignoresSafeArea()
                    HUDBackdrop(cornerRadius: 16, contrast: .high)
                        .opacity(0.85)
                }

                // Ambient studio lighting
                RadialGradient(
                    colors: [
                        Theme.LiquidGlass.cyanGlow.opacity(colorScheme == .light ? 0.05 : 0.08),
                        Theme.LiquidGlass.violetGlow.opacity(colorScheme == .light ? 0.03 : 0.04),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        )
        .sheet(isPresented: $showPresetSheet) {
            EqualizerPresetSheet(equalizer: equalizer)
        }
        .sheet(isPresented: $showToneGenerator) {
            EqualizerToneGeneratorSheet()
        }
    }

    // MARK: - Header Bar (Responsive, Never Overlapping, Zero Text Wrapping)

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Group 1: Power, Bypass & Mode Switcher
            HStack(spacing: 6) {
                powerButton
                bypassButton
                customModeSwitcher
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 4)

            // Group 2: Scope & Preset Dropdowns
            HStack(spacing: 6) {
                targetScopeMenu
                presetMenu
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 4)

            // Group 3: Audio FX, Tone Gen, VU Meter, Preamp
            HStack(spacing: 6) {
                audioFXGroup
                toneGenButton
                EqualizerStereoVUMeter()
                preampControl
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .light ? Color.white.opacity(0.75) : Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.75)
                )
        )
    }

    // MARK: - Subcomponents of Header

    private var powerButton: some View {
        Button {
            withAnimation(.liquidBouncy) {
                equalizer.isEnabled.toggle()
            }
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(equalizer.isEnabled ? Color.white : Color.primary.opacity(0.35))
                .frame(width: 28, height: 28)
                .background(
                    ZStack {
                        Circle()
                            .fill(equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.85) : Color.primary.opacity(0.06))
                        if equalizer.isEnabled {
                            Circle()
                                .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.6))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            equalizer.isEnabled
                                ? Theme.LiquidGlass.cyanGlow.opacity(0.9)
                                : Color.primary.opacity(0.12),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.5) : Color.clear, radius: 6)
        }
        .buttonStyle(.plain)
        .help(equalizer.isEnabled ? "Disable Equalizer" : "Enable Equalizer")
        .fixedSize()
    }

    private var bypassButton: some View {
        Button {
            withAnimation(.liquidBouncy) {
                equalizer.isBypassed.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: equalizer.isBypassed ? "pause.circle.fill" : "bolt.fill")
                    .font(.system(size: 9))
                Text(equalizer.isBypassed ? "BYPASS" : "ACTIVE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(equalizer.isBypassed ? Color.orange.opacity(0.2) : Theme.LiquidGlass.cyanGlow.opacity(0.16))
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
        .fixedSize()
    }

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
                    Text(modeShortLabel(mode))
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4.5)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(Theme.LiquidGlass.cyanGlow.opacity(colorScheme == .light ? 0.25 : 0.22))
                                    Capsule()
                                        .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.4))
                                } else {
                                    Capsule()
                                        .fill(Color.clear)
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
                        .foregroundStyle(isSelected ? (colorScheme == .light ? Color.primary : Color.white) : Color.secondary)
                        .shadow(color: isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.3) : Color.clear, radius: 4)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .padding(2.5)
        .background(
            Capsule()
                .fill(colorScheme == .light ? Color.black.opacity(0.06) : Color.black.opacity(0.45))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6)
                )
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private func modeShortLabel(_ mode: EqualizerMode) -> String {
        switch mode {
        case .parametric: return "Parametric"
        case .graphic10: return "10-Band"
        case .graphic15: return "15-Band"
        case .graphic31: return "31-Band"
        }
    }

    private var targetScopeMenu: some View {
        Menu {
            Button {
                equalizer.activeTargetScope = .globalMaster
            } label: {
                Label("Global Output (All Audio)", systemImage: "speaker.wave.3.fill")
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
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                Text(equalizer.activeTargetScope.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4.5)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var presetMenu: some View {
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
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.LiquidGlass.violetGlow)
                Text(equalizer.activeProfile.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4.5)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var audioFXGroup: some View {
        HStack(spacing: 4) {
            // Bass Exciter Toggle
            Button {
                withAnimation(.liquidSpring) {
                    equalizer.isBassExciterEnabled.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 9))
                    Text("Bass FX")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(equalizer.isBassExciterEnabled ? Theme.LiquidGlass.amberGlow.opacity(0.25) : Color.primary.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(equalizer.isBassExciterEnabled ? Theme.LiquidGlass.amberGlow.opacity(0.8) : Color.clear, lineWidth: 0.8)
                )
                .foregroundStyle(equalizer.isBassExciterEnabled ? Theme.LiquidGlass.amberGlow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Psychoacoustic Bass Exciter (Enhances sub-harmonics for richer low-end)")
            .fixedSize()

            // 3D Spatial Virtualizer Toggle
            Button {
                withAnimation(.liquidSpring) {
                    equalizer.isSpatialVirtualizerEnabled.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 9))
                    Text("3D Space")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(equalizer.isSpatialVirtualizerEnabled ? Theme.LiquidGlass.violetGlow.opacity(0.25) : Color.primary.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(equalizer.isSpatialVirtualizerEnabled ? Theme.LiquidGlass.violetGlow.opacity(0.8) : Color.clear, lineWidth: 0.8)
                )
                .foregroundStyle(equalizer.isSpatialVirtualizerEnabled ? Theme.LiquidGlass.violetGlow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("3D Spatial Audio Virtualizer (Expands holographic stereo soundstage)")
            .fixedSize()
        }
    }

    private var toneGenButton: some View {
        Button {
            showToneGenerator = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                Text("Tone")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4.5)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .help("Acoustic Tone & Noise Generator for speaker/headphone calibration")
        .fixedSize()
    }

    private var preampControl: some View {
        HStack(spacing: 4) {
            Text("Preamp")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.secondary)

            Text(String(format: "%+.1f dB", equalizer.activeProfile.preamp))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(equalizer.activeProfile.preamp > 0.01 ? Theme.LiquidGlass.amberGlow : (equalizer.activeProfile.preamp < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                .frame(width: 46, alignment: .trailing)

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
            .tint(Theme.LiquidGlass.cyanGlow)
            .frame(width: 58)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .light ? Color.white.opacity(0.7) : Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.65)
                )
        )
        .fixedSize()
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
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button {
                showPresetSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9.5))
                    Text("Import / Export Profiles")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
                .foregroundStyle(Color.primary.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}
