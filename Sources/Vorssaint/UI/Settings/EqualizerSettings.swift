// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings page for the Equalizer APO audio engine.
struct EqualizerSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var equalizer = AudioEqualizerService.shared
    @State private var showPresetSheet = false

    var body: some View {
        Form {
            Section {
                // Liquid Glass Hero Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.s.equalizerTitle)
                                .font(.system(size: 14, weight: .bold))
                            Text(l10n.s.equalizerEnableCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(l10n.s.equalizerEnable, isOn: $equalizer.isEnabled)
                        .toggleStyle(.switch)
                        .padding(.top, 4)

                    if equalizer.isEnabled {
                        HStack(spacing: 10) {
                            Button {
                                (NSApp.delegate as? AppDelegate)?.openEqualizerStudioWindow()
                            } label: {
                                Label(l10n.s.equalizerOpenStudio, systemImage: "slider.vertical.3")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button {
                                showPresetSheet = true
                            } label: {
                                Label(l10n.s.equalizerManagePresets, systemImage: "square.and.arrow.down")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 12, glow: equalizer.isEnabled ? Theme.LiquidGlass.cyanGlow : nil)
            }

            if equalizer.isEnabled {
                Section(header: Text(l10n.s.equalizerCurrentProfileHeader)) {
                    HStack {
                        Text(l10n.s.equalizerActiveProfileLabel)
                        Spacer()
                        Menu {
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
                        } label: {
                            Text(equalizer.activeProfile.name)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .menuStyle(.borderedButton)
                    }

                    HStack {
                        Text(l10n.s.equalizerModeLabel)
                        Spacer()
                        Text(equalizer.activeProfile.mode.displayName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(l10n.s.equalizerPreampLabel)
                        Spacer()
                        Text(String(format: "%+.1f dB", equalizer.activeProfile.preamp))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(equalizer.activeProfile.preamp > 0.01 ? Theme.LiquidGlass.amberGlow : (equalizer.activeProfile.preamp < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.primary))
                    }
                }

                Section(header: Text(l10n.s.equalizerAutoEqHeader)) {
                    Text(l10n.s.equalizerAutoEqDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showPresetSheet = true
                    } label: {
                        Label(l10n.s.equalizerImportAutoEqButton, systemImage: "headphones")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPresetSheet) {
            EqualizerPresetSheet(equalizer: equalizer)
        }
    }
}
