// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Professional Equalizer Studio window view inspired by Equalizer APO.
struct EqualizerStudioView: View {
    @ObservedObject private var equalizer = AudioEqualizerService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @State private var selectedBandID: UUID?
    @State private var showPresetSheet = false

    var body: some View {
        VStack(spacing: 14) {
            // Master Studio Header Bar
            headerBar

            // Interactive Bode Plot Graph with FFT Spectrum
            EqualizerBodePlotView(
                equalizer: equalizer,
                selectedBandID: $selectedBandID
            )

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

            // Footer info bar
            footerBar
        }
        .padding(18)
        .frame(minWidth: 800, idealWidth: 860, maxWidth: 1100,
               minHeight: 580, idealHeight: 640, maxHeight: 820)
        .panelGlassSurface(cornerRadius: 16)
        .sheet(isPresented: $showPresetSheet) {
            EqualizerPresetSheet(equalizer: equalizer)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Power Button with Neon Liquid Glow
            Button {
                withAnimation(.liquidBouncy) {
                    equalizer.isEnabled.toggle()
                }
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(equalizer.isEnabled ? Color.white : Color.secondary.opacity(0.5))
                    .frame(width: 34, height: 34)
                    .background(
                        ZStack {
                            Circle()
                                .fill(equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.3) : Color.white.opacity(0.06))
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
                    .shadow(color: equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow.opacity(0.5) : Color.clear, radius: 8)
            }
            .buttonStyle(.plain)
            .help(equalizer.isEnabled ? "Disable Equalizer" : "Enable Equalizer")

            // A/B Bypass Button
            Button {
                withAnimation(.liquidBouncy) {
                    equalizer.isBypassed.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: equalizer.isBypassed ? "pause.circle.fill" : "bolt.fill")
                        .font(.system(size: 10.5))
                    Text(equalizer.isBypassed ? "BYPASS" : "ACTIVE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(equalizer.isBypassed ? Color.orange.opacity(0.2) : Theme.LiquidGlass.cyanGlow.opacity(0.18))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            equalizer.isBypassed ? Color.orange.opacity(0.6) : Theme.LiquidGlass.cyanGlow.opacity(0.5),
                            lineWidth: 0.85
                        )
                )
                .foregroundStyle(equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow)
                .shadow(color: (equalizer.isBypassed ? Color.orange : Theme.LiquidGlass.cyanGlow).opacity(0.3), radius: 6)
            }
            .buttonStyle(.plain)
            .help("Instant A/B comparison (Bypass filter processing)")

            Divider().frame(height: 20)

            // Target Scope Picker (Global vs Per-App)
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
                HStack(spacing: 5) {
                    Image(systemName: scopeIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                    Text(equalizer.activeTargetScope.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(maxWidth: 190, alignment: .leading)
            }
            .menuStyle(.borderedButton)

            // Preset Menu
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
                    Label("Manage & Import Profiles…", systemImage: "slider.vertical.3")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.LiquidGlass.violetGlow)
                    Text(equalizer.activeProfile.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: 160, alignment: .leading)
            }
            .menuStyle(.borderedButton)

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
            .frame(maxWidth: 220)

            Spacer()

            // Preamp Gain Slider
            HStack(spacing: 6) {
                Text("Preamp:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(String(format: "%+.1f dB", equalizer.activeProfile.preamp))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(equalizer.activeProfile.preamp > 0.01 ? Theme.LiquidGlass.amberGlow : (equalizer.activeProfile.preamp < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                    .frame(width: 54, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { equalizer.activeProfile.preamp },
                        set: { val in
                            equalizer.updatePreamp(val)
                        }
                    ),
                    in: -20.0...20.0
                )
                .frame(width: 80)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.65)
                    )
            )
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
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showPresetSheet = true
            } label: {
                Label("Import / Export", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

/// Visual effect blur background for studio window.
private struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
