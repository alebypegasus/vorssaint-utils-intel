// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct MemoryMaintenanceView: View {
    @ObservedObject private var service = MemoryMaintenanceService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var recentFreedText = ""
    @State private var showFreedAnimation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Overview Header & Memory Gauge in Liquid Glass
                memoryPressureHeader

                // 2. Breakdown Segmented Bar
                memorySegmentedBar

                // 3. Purge & Optimization Level Cards
                purgeActionsGrid

                // 4. Auto-Maintenance Watchdog Settings
                autoCleanSection
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Memory Pressure Header

    @ViewBuilder
    private var memoryPressureHeader: some View {
        let snap = service.snapshot
        let pressure = snap.pressurePercent
        let gaugeColor: Color = pressure > 80 ? Theme.LiquidGlass.magentaGlow : (pressure > 60 ? Theme.LiquidGlass.amberGlow : Theme.LiquidGlass.emeraldGlow)

        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 10)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(max(5, pressure)) / 100.0)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.liquidSpring, value: pressure)

                VStack(spacing: 0) {
                    Text("\(Int(pressure))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("Pressão")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Manutenção e Purga de Memória")
                        .font(.system(size: 16, weight: .bold))
                    if snap.isCritical {
                        Text("CRÍTICA")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }

                Text("Otimize o compressor de páginas e libere memória inativa retida pelo kernel")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                if showFreedAnimation {
                    Text(recentFreedText)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            Spacer()

            Button {
                service.clean(level: .quick) { freed in
                    withAnimation(.liquidBouncy) {
                        recentFreedText = "+\(MetricFormat.bytes(UInt64(max(0, freed)))) liberados instantaneamente!"
                        showFreedAnimation = true
                    }
                }
            } label: {
                Label(service.isCleaning ? "Limpando..." : "Purga Rápida", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.LiquidGlass.cyanGlow)
            .disabled(service.isCleaning)
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 14, glow: gaugeColor)
    }

    // MARK: - Memory Segmented Bar

    @ViewBuilder
    private var memorySegmentedBar: some View {
        let snap = service.snapshot
        let total = max(1.0, Double(snap.totalBytes))
        let appFrac = Double(snap.appBytes) / total
        let wiredFrac = Double(snap.wiredBytes) / total
        let compFrac = Double(snap.compressedBytes) / total
        let cachedFrac = Double(snap.cachedBytes) / total
        let freeFrac = Double(snap.freeBytes) / total

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Distribuição de Memória Física (\(Int(Double(snap.totalBytes) / 1073741824.0)) GB)")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("Livre: \(MetricFormat.bytes(UInt64(max(0, snap.freeBytes))))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
            }

            // Multi-color progress bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.LiquidGlass.cyanGlow)
                        .frame(width: max(2, geo.size.width * CGFloat(appFrac)))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.LiquidGlass.violetGlow)
                        .frame(width: max(2, geo.size.width * CGFloat(wiredFrac)))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.LiquidGlass.amberGlow)
                        .frame(width: max(2, geo.size.width * CGFloat(compFrac)))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: max(2, geo.size.width * CGFloat(cachedFrac)))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.LiquidGlass.emeraldGlow.opacity(0.3))
                        .frame(width: max(2, geo.size.width * CGFloat(freeFrac)))
                }
            }
            .frame(height: 12)

            // Legend indicators
            HStack(spacing: 12) {
                legendItem(title: "Apps", size: snap.appBytes, color: Theme.LiquidGlass.cyanGlow)
                legendItem(title: "Com Fio (Wired)", size: snap.wiredBytes, color: Theme.LiquidGlass.violetGlow)
                legendItem(title: "Comprimida", size: snap.compressedBytes, color: Theme.LiquidGlass.amberGlow)
                legendItem(title: "Cache", size: snap.cachedBytes, color: Color.blue.opacity(0.6))
                legendItem(title: "Livre", size: snap.freeBytes, color: Theme.LiquidGlass.emeraldGlow)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .panelCard(cornerRadius: 12)
    }

    private func legendItem(title: String, size: Int64, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(MetricFormat.bytes(UInt64(max(0, size))))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
        }
    }

    // MARK: - Purge Levels Action Grid

    @ViewBuilder
    private var purgeActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AÇÕES DE PURGA E DESFRAGMENTAÇÃO")
                .font(.system(size: 10, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MemoryMaintenanceService.CleanLevel.allCases) { level in
                    purgeCard(level: level)
                }
            }
        }
    }

    private func purgeCard(level: MemoryMaintenanceService.CleanLevel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: level.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                Text(level.title)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }

            Text(level.description)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 32, alignment: .topLeading)

            Button {
                service.clean(level: level) { freed in
                    withAnimation(.liquidBouncy) {
                        recentFreedText = "+\(MetricFormat.bytes(UInt64(max(0, freed)))) recuperados!"
                        showFreedAnimation = true
                    }
                }
            } label: {
                Text(service.isCleaning ? "Executando..." : "Executar Agora")
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(service.isCleaning)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 12)
    }

    // MARK: - Auto-Clean Watchdog Settings

    @ViewBuilder
    private var autoCleanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
                Text("Auto-Limpeza Inteligente em Segundo Plano")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Toggle("", isOn: $service.autoCleanEnabled)
                    .toggleStyle(.switch)
            }

            Text("Executa automaticamente uma purga suave de buffers inativos quando a pressão de memória exceder o limite escolhido.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if service.autoCleanEnabled {
                HStack(spacing: 12) {
                    Text("Limite de Pressão: \(service.pressureThreshold)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Slider(value: Binding(
                        get: { Double(service.pressureThreshold) },
                        set: { service.pressureThreshold = Int($0) }
                    ), in: 60...95, step: 5)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .panelCard(cornerRadius: 12)
    }
}
