// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct BatteryHealthGuardView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var battery = BatteryHealthGuard.shared

    private var extStrings: TenFeaturesExtendedStrings {
        TenFeaturesExtendedStrings.localized(l10n.language)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !battery.stats.hasBattery {
                    VStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Battery Detected")
                            .font(.headline)
                        Text("This Mac is connected directly to AC power (Desktop Mac).")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Battery Gauge & Health Card
                    HStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0, to: CGFloat(battery.stats.healthPercent / 100.0))
                                .stroke(
                                    battery.stats.healthPercent > 80 ? Color.green : (battery.stats.healthPercent > 60 ? Color.orange : Color.red),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 2) {
                                Text("\(Int(battery.stats.healthPercent))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                Text("Health")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Battery State of Health (SoH)")
                                .font(.headline)
                            Text(battery.stats.healthPercent >= 80 ? "Condition: Normal (Good health)" : "Condition: Service Recommended")
                                .font(.subheadline)
                                .foregroundStyle(battery.stats.healthPercent >= 80 ? .green : .orange)

                            HStack(spacing: 12) {
                                Label("\(battery.stats.currentPercentage)% Charged", systemImage: battery.stats.isCharging ? "bolt.fill" : "battery.75")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if battery.stats.temperatureCelsius > 0 {
                                    Label(String(format: "%.1f°C", battery.stats.temperatureCelsius), systemImage: "thermometer.medium")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))

                    // Detail Metrics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricTile(title: "Cycle Count", value: "\(battery.stats.cycleCount)", subtitle: "of 1000 design cycles", icon: "arrow.triangle.2.circlepath")
                        MetricTile(title: "Capacity", value: "\(battery.stats.maxCapacity) mAh", subtitle: "Design: \(battery.stats.designCapacity) mAh", icon: "battery.100")
                        MetricTile(title: "Power Draw", value: String(format: "%.1f W", battery.stats.wattageWatts), subtitle: "\(battery.stats.voltageMilliVolts) mV", icon: "bolt")
                    }

                    // Charge Limiter 80% Toggle Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("80% Charge Lifespan Limiter Reminder")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Notifies when battery hits 80% to disconnect charger and reduce lithium cell wear.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $battery.chargeLimiter80Enabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                }
            }
            .padding(20)
        }
    }

    private struct MetricTile: View {
        let title: String
        let value: String
        let subtitle: String
        let icon: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.accentColor)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
        }
    }
}
