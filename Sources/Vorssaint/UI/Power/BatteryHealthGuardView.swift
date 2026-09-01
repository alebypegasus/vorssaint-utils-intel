// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct BatteryHealthGuardView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var battery = BatteryHealthGuard.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !battery.stats.hasBattery {
                    VStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Mac Conectado Diretamente à Tomada")
                            .font(.headline)
                        Text("Este dispositivo é um Mac Desktop ou Hackintosh sem bateria interna.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // 1. Health Ring & Degradation Forecast
                    batteryHealthOverviewHeader

                    // 2. Telemetry Grid (Cycles, Power Draw, Temperature, Voltage)
                    batteryTelemetryGrid

                    // 3. Smart Controls (80% Limiter & Ultra Economy)
                    smartBatteryControls

                    // 4. Energy Hogs List (Top Power Draining Apps)
                    energyHogsSection
                }
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Health Overview Header

    @ViewBuilder
    private var batteryHealthOverviewHeader: some View {
        let stats = battery.stats
        let health = stats.healthPercent
        let healthColor: Color = health > 80 ? Theme.LiquidGlass.emeraldGlow : (health > 60 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.magentaGlow)

        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 10)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(health / 100.0))
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(health))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("Saúde SoH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Saúde e Degradação Celular")
                        .font(.system(size: 15, weight: .bold))
                    Text(health >= 80 ? "NORMAL" : "VERIFICAR")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(health >= 80 ? Theme.LiquidGlass.emeraldGlow : Color.orange)
                        .clipShape(Capsule())
                }

                Text("Estimativa de vida útil: aproximadamente \(stats.projectedMonthsTo80) meses adicionais até atingir 80% de capacidade residual.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label("\(stats.currentPercentage)% Atual", systemImage: stats.isCharging ? "bolt.fill" : "battery.100")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(healthColor)
                    if stats.temperatureCelsius > 0 {
                        Label(String(format: "%.1f°C Temperatura", stats.temperatureCelsius), systemImage: "thermometer.medium")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 14, glow: healthColor)
    }

    // MARK: - Telemetry Grid

    @ViewBuilder
    private var batteryTelemetryGrid: some View {
        let s = battery.stats
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            telemetryCard(title: "Contador de Ciclos", value: "\(s.cycleCount)", subtitle: "de 1.000 de projeto", icon: "arrow.triangle.2.circlepath", color: Theme.LiquidGlass.cyanGlow)
            telemetryCard(title: "Capacidade Real", value: "\(s.maxCapacity) mAh", subtitle: "Design: \(s.designCapacity) mAh", icon: "battery.100", color: Theme.LiquidGlass.emeraldGlow)
            telemetryCard(title: "Potência em Watts", value: String(format: "%.1f W", s.wattageWatts), subtitle: "\(s.voltageMilliVolts) mV • \(s.amperageMilliAmps) mA", icon: "bolt.fill", color: Theme.LiquidGlass.amberGlow)
        }
    }

    private func telemetryCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
            Text(subtitle)
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .panelCard(cornerRadius: 10)
    }

    // MARK: - Smart Controls

    @ViewBuilder
    private var smartBatteryControls: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
                        Text("Limitador & Lembrete de Carga em 80%")
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    Text("Preserva a vida celular alertando quando atingir 80% para evitar desgaste químico em cargas contínuas a 100%.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $battery.chargeLimiter80Enabled)
                    .toggleStyle(.switch)
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 10)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                        Text("Modo Ultra Economia de Energia")
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    Text("Reduz o consumo da CPU (PL1 15W), ativa Low Power Mode e suspende sincronizações para máxima autonomia.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $battery.ultraEconomyEnabled)
                    .toggleStyle(.switch)
            }
            .padding(12)
            .liquidGlassCard(cornerRadius: 10)
        }
    }

    // MARK: - Energy Hogs

    @ViewBuilder
    private var energyHogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame")
                    .foregroundStyle(Theme.LiquidGlass.magentaGlow)
                Text("PROCESSOS COM MAIOR CONSUMO DE BATERIA (ENERGY HOGS)")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    battery.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            if battery.energyHogs.isEmpty {
                Text("Nenhum processo com impacto excessivo de energia detectado no momento.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(battery.energyHogs) { hog in
                    HStack(spacing: 10) {
                        if let icon = hog.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hog.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text("PID: \(hog.pid) • \(Int(hog.memoryMB)) MB RAM")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Impacto: \(Int(hog.impactScore))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(hog.impactScore > 50 ? Theme.LiquidGlass.magentaGlow : Theme.LiquidGlass.amberGlow)

                        Button("Encerrar") {
                            battery.killEnergyHog(pid: hog.pid)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .panelCard(cornerRadius: 8)
                }
            }
        }
        .padding(14)
        .panelCard(cornerRadius: 12)
    }
}
