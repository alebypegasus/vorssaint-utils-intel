// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Redesigned Power & Battery Section with high-density metrics, battery health gauges,
/// real-time power sparkline, and smart 80% charge lifespan protection.
struct PowerSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    var collapsible = true

    @AppStorage(DefaultsKey.monitorGraphPower) private var showGraph = true
    @AppStorage("batteryHealthAlert80") private var batteryHealthAlert80 = false
    @AppStorage("lowPowerModeEnabled") private var lowPowerModeEnabled = false

    var body: some View {
        PanelSection(.power, title: l10n.s.powerSection, collapsible: collapsible) {
            VStack(alignment: .leading, spacing: 8) {
                if let power = monitor.snapshot.power, !power.isEmpty {
                    // 1. Battery Health & Status Overview (if Mac has a battery)
                    if power.hasBattery {
                        batteryOverviewHeader(power)
                        Divider().padding(.vertical, 2)
                    }

                    // 2. Power Consumption Metrics Grid
                    powerMetricsGrid(power)

                    // 3. Live Power Sparkline
                    if showGraph, monitor.snapshot.systemPowerHistory.count >= 2 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Power Draw History")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                if let watts = power.systemWatts {
                                    Text(MetricFormat.watts(watts))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(PanelMetricColor.orange(for: colorScheme))
                                }
                            }
                            Sparkline(
                                values: monitor.snapshot.systemPowerHistory,
                                color: PanelMetricColor.orange(for: colorScheme),
                                showsZeroBaseline: true
                            )
                            .frame(height: 26)
                        }
                        .padding(.top, 2)
                    }

                    // 4. Quick Battery Health Controls
                    if power.hasBattery {
                        Divider().padding(.vertical, 2)
                        batteryQuickActions(power)
                    }
                } else {
                    Text(l10n.s.powerUnavailable)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                }
            }
            .panelCard()
        }
    }

    // MARK: - Battery Overview Header

    private func batteryOverviewHeader(_ power: PowerReading) -> some View {
        let charge = power.chargePercent ?? 0
        let isCharging = power.isCharging
        let statusColor: Color = isCharging
            ? PanelMetricColor.green(for: colorScheme)
            : (charge > 20 ? .accentColor : .red)

        return HStack(spacing: 10) {
            // Circular Mini Gauge
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 3.5)
                    .frame(width: 38, height: 38)

                Circle()
                    .trim(from: 0, to: CGFloat(charge) / 100.0)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))

                Image(systemName: isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(charge)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(isCharging ? "Charging" : (power.externalConnected ? "Plugged In" : "On Battery"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isCharging ? PanelMetricColor.green(for: colorScheme) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(isCharging ? PanelMetricColor.green(for: colorScheme).opacity(0.15) : Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    if let health = power.healthPercent {
                        Text("Health: \(Int(health.rounded()))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(health > 80 ? PanelMetricColor.green(for: colorScheme) : .orange)
                    }
                    if let cycles = power.cycleCount {
                        Text("•  \(cycles) Cycles")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if let remaining = power.timeRemainingSeconds.flatMap(BatteryTimeSupport.formatted),
               !power.externalConnected {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(remaining)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(PanelMetricColor.green(for: colorScheme))
                    Text("remaining")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Power Metrics Grid

    private func powerMetricsGrid(_ power: PowerReading) -> some View {
        VStack(spacing: 6) {
            // System Power Row
            if let watts = power.systemWatts {
                powerRow(
                    icon: "bolt.fill",
                    color: PanelMetricColor.orange(for: colorScheme),
                    label: l10n.s.powerSystem,
                    value: MetricFormat.watts(watts)
                )
            }

            // Power Adapter Delivery Row
            if power.externalConnected, let adapter = power.adapterWatts {
                powerRow(
                    icon: "powerplug.fill",
                    color: .accentColor,
                    label: l10n.s.powerAdapter,
                    value: MetricFormat.watts(adapter),
                    caption: power.adapterMaxWatts.map { "(\(Int($0))W Max)" }
                )
            }

            // Net Battery Flow Row
            if power.hasBattery, let flow = power.batteryWatts {
                powerRow(
                    icon: flow >= 0 ? "battery.100.bolt" : "battery.50",
                    color: flow >= 0 ? PanelMetricColor.green(for: colorScheme) : .secondary,
                    label: l10n.s.powerBattery,
                    value: (flow >= 0 ? "+" : "-") + MetricFormat.watts(abs(flow)),
                    caption: flow >= 0 ? "Charging" : "Discharging"
                )
            }
        }
    }

    private func powerRow(icon: String, color: Color, label: String, value: String, caption: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.85))

            if let caption {
                Text(caption)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Battery Quick Actions

    private func batteryQuickActions(_ power: PowerReading) -> some View {
        HStack(spacing: 8) {
            // 80% Charge Health Guard Toggle
            Button {
                withAnimation(.liquidSpring) {
                    batteryHealthAlert80.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: batteryHealthAlert80 ? "shield.fill" : "shield")
                        .font(.system(size: 9.5))
                    Text("80% Charge Guard")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(batteryHealthAlert80 ? Theme.LiquidGlass.emeraldGlow.opacity(0.18) : Color.primary.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(batteryHealthAlert80 ? Theme.LiquidGlass.emeraldGlow.opacity(0.7) : Color.clear, lineWidth: 0.8)
                )
                .foregroundStyle(batteryHealthAlert80 ? Theme.LiquidGlass.emeraldGlow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Notifies you when battery hits 80% to unplug and extend battery longevity")

            Spacer()

            // Low Power Mode Toggle
            Button {
                withAnimation(.liquidSpring) {
                    lowPowerModeEnabled.toggle()
                    toggleLowPowerMode(lowPowerModeEnabled)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9.5))
                    Text(lowPowerModeEnabled ? "Low Power: ON" : "Low Power")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(lowPowerModeEnabled ? Color.yellow.opacity(0.2) : Color.primary.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(lowPowerModeEnabled ? Color.yellow.opacity(0.7) : Color.clear, lineWidth: 0.8)
                )
                .foregroundStyle(lowPowerModeEnabled ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Toggles macOS Low Power Mode to save battery life")
        }
    }

    private func toggleLowPowerMode(_ enabled: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = try? BoundedProcessRunner.run("/usr/bin/pmset", ["-a", "lowpowermode", enabled ? "1" : "0"], timeout: 2.0, maxOutputBytes: 1024)
        }
    }
}
