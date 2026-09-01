// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct TurboBoostView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var turbo = TurboBoostService.shared
    @ObservedObject private var powerMode = ProcessorPowerModeService.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. CPU Power Profile & Overclock Selector
                cpuProfileSelectorSection

                // 2. Custom Limits & Turbo Boost Overdrive (if custom/overclock)
                if powerMode.currentMode == .custom || powerMode.currentMode == .overclock {
                    customLimitsSection
                }

                // 3. Game & 3D Render Focus Booster Card
                gameFocusBoosterSection

                // 4. Auto-Booster Application Trigger List
                autoTriggerSection
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - CPU Power Profile Selector

    @ViewBuilder
    private var cpuProfileSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.LiquidGlass.magentaGlow)
                Text("PERFIS DO PROCESSADOR & OVERCLOCK")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                if let watts = monitor.snapshot.power?.systemWatts {
                    Text("Consumo CPU: \(String(format: "%.1f", watts)) W")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.LiquidGlass.amberGlow)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CPUPowerMode.allCases) { mode in
                    cpuModeCard(mode: mode)
                }
            }
        }
    }

    private func cpuModeCard(mode: CPUPowerMode) -> some View {
        let isSelected = powerMode.currentMode == mode
        let glowColor: Color = mode == .overclock ? Theme.LiquidGlass.magentaGlow : (mode == .performance ? Theme.LiquidGlass.amberGlow : (mode == .lowPower ? Theme.LiquidGlass.emeraldGlow : Theme.LiquidGlass.cyanGlow))

        return Button {
            powerMode.setMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(glowColor)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(glowColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: glowColor, radius: 4)
                    }
                }

                Text(mode.title)
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))

                Text(mode.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 36, alignment: .topLeading)
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 12, glow: isSelected ? glowColor : nil, isHovered: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Limits Section

    @ViewBuilder
    private var customLimitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                Text("AJUSTES DE POTÊNCIA E TURBO BOOST")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Intel Turbo Boost Permanente")
                            .font(.system(size: 12, weight: .bold))
                        Text("Mantém os núcleos na frequência máxima sem escalonamento intermediário.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $powerMode.turboBoostEnabled)
                        .toggleStyle(.switch)
                }

                Divider()

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Limite PL1 (Long Duration): \(powerMode.customPL1Watts) W")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Slider(value: Binding(
                            get: { Double(powerMode.customPL1Watts) },
                            set: { powerMode.customPL1Watts = Int($0) }
                        ), in: 15...80, step: 5)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Limite PL2 (Short Burst): \(powerMode.customPL2Watts) W")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Slider(value: Binding(
                            get: { Double(powerMode.customPL2Watts) },
                            set: { powerMode.customPL2Watts = Int($0) }
                        ), in: 25...105, step: 5)
                    }
                }
            }
            .padding(14)
            .panelCard(cornerRadius: 12)
        }
    }

    // MARK: - Game Focus Booster

    @ViewBuilder
    private var gameFocusBoosterSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(turbo.isTurboActive ? Theme.LiquidGlass.magentaGlow.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: turbo.isTurboActive ? "bolt.fill" : "gamecontroller.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(turbo.isTurboActive ? Theme.LiquidGlass.magentaGlow : Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(turbo.isTurboActive ? "Modo Turbo Booster ATIVO" : "Game & 3D Render Focus Booster")
                        .font(.system(size: 14, weight: .bold))
                    if turbo.isTurboActive {
                        Text("NICE -15")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }

                Text("Suspende sincronizadores em segundo plano (Adobe CC, Dropbox, OneDrive), limpa buffers de RAM e eleva prioridade do app ativo.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if turbo.isTurboActive {
                    turbo.deactivateTurbo {}
                } else {
                    turbo.activateTurbo {}
                }
            } label: {
                Text(turbo.isTurboActive ? "Desativar" : "Ativar Turbo")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(turbo.isTurboActive ? .red : Theme.LiquidGlass.magentaGlow)
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 14, glow: turbo.isTurboActive ? Theme.LiquidGlass.magentaGlow : nil)
    }

    // MARK: - Auto Booster Triggers

    @ViewBuilder
    private var autoTriggerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkle")
                    .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
                Text("Ativação Automática de Overdrive para Jogos & Apps 3D")
                    .font(.system(size: 12.5, weight: .bold))
                Spacer()
                Toggle("", isOn: $powerMode.autoGameBoostEnabled)
                    .toggleStyle(.switch)
            }

            Text("Quando ativado, o Vorssaint eleva o processador para Overclock Overdrive automaticamente assim que você abre jogos ou programas como Blender, Final Cut, Xcode, DaVinci Resolve e Steam.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .panelCard(cornerRadius: 12)
    }
}
