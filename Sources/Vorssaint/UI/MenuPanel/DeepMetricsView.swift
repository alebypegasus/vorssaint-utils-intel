// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct DeepMetricsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var report = HardwareInfo.collectDeepReport()
    @State private var loading = true
    @State private var rawPowermetrics = ""
    @State private var showCopiedBanner = false
    @State private var expandedSection: String? = "cpu"

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if loading {
                loadingView
            } else {
                metricsScrollView
            }
        }
        .frame(width: 720, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let deepReport = HardwareInfo.collectDeepReport()
                let powermetrics = HardwareInfo.getBatteryInfo()

                DispatchQueue.main.async {
                    self.report = deepReport
                    self.rawPowermetrics = powermetrics
                    self.loading = false
                }
            }
        }
    }

    // MARK: - Header Bar

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                .shadow(color: Theme.LiquidGlass.cyanGlow.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Relatório Profundo de Hardware")
                        .font(.title3.bold())
                    Text("LIQUID GLASS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.LiquidGlass.cyanGlow.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text("Arquitetura, Consumo Dinâmico em Watts e Saúde de Componentes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showCopiedBanner {
                Text("Copiado!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
                    .transition(.scale.combined(with: .opacity))
            }

            Button {
                copyFullReport()
            } label: {
                Label("Copiar Markdown", systemImage: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Fechar") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func copyFullReport() {
        let md = report.asMarkdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        withAnimation(.liquidSpring) {
            showCopiedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopiedBanner = false
            }
        }
    }

    // MARK: - Metrics Scroll View

    @ViewBuilder
    private var metricsScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Processador (CPU)
                accordionCard(
                    id: "cpu",
                    title: "Processador (CPU & Arquitetura)",
                    subtitle: "\(report.cpu.modelName) • \(report.cpu.coreCount) Cores",
                    icon: "cpu.fill",
                    color: Theme.LiquidGlass.cyanGlow
                ) {
                    cpuDetailGrid
                }

                // 2. Gráficos (GPU)
                accordionCard(
                    id: "gpu",
                    title: "Processador Gráfico (GPU)",
                    subtitle: "\(report.gpu.modelName) • \(report.gpu.vramMB) MB VRAM",
                    icon: "display.2",
                    color: Theme.LiquidGlass.violetGlow
                ) {
                    gpuDetailGrid
                }

                // 3. Memória RAM & Swap
                accordionCard(
                    id: "memory",
                    title: "Memória RAM & Compressor",
                    subtitle: "\(Int(report.memory.totalGB)) GB Total • \(String(format: "%.1f", report.memory.usedGB)) GB em uso",
                    icon: "memorychip.fill",
                    color: Theme.LiquidGlass.amberGlow
                ) {
                    memoryDetailGrid
                }

                // 4. Bateria & Telemetria de Energia
                if report.battery.hasBattery {
                    accordionCard(
                        id: "battery",
                        title: "Bateria & Powermetrics",
                        subtitle: "Saúde: \(Int(report.battery.healthPercent))% • \(report.battery.cycleCount) ciclos",
                        icon: "battery.100.bolt",
                        color: Theme.LiquidGlass.emeraldGlow
                    ) {
                        batteryDetailGrid
                    }
                }

                // 5. Armazenamento & SSD SMART
                accordionCard(
                    id: "storage",
                    title: "Armazenamento & SMART SSD",
                    subtitle: "\(report.storage.driveName) • \(Int(report.storage.freeGB)) GB Livres",
                    icon: "internaldrive.fill",
                    color: Theme.LiquidGlass.magentaGlow
                ) {
                    storageDetailGrid
                }
            }
            .padding(16)
        }
    }

    // MARK: - Accordion Card Wrapper

    private func accordionCard<Content: View>(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedSection == id

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.liquidSpring) {
                    expandedSection = isExpanded ? nil : id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .bold))
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(color.opacity(0.8))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content()
                    .padding(14)
            }
        }
        .liquidGlassCard(cornerRadius: 14, glow: isExpanded ? color : nil)
    }

    // MARK: - Detail Grids

    @ViewBuilder
    private var cpuDetailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricItem(label: "Modelo do Processador", value: report.cpu.modelName)
            metricItem(label: "Arquitetura", value: report.cpu.architecture)
            metricItem(label: "Núcleos Físicos / Lógicos", value: "\(report.cpu.coreCount) Cores / \(report.cpu.threadCount) Threads")
            metricItem(label: "Frequência Base / Turbo", value: "\(report.cpu.baseFrequencyGHz) GHz / \(report.cpu.maxBoostFrequencyGHz) GHz")
            metricItem(label: "Consumo em Tempo Real", value: String(format: "%.1f W", report.cpu.currentPowerWatts), highlightColor: Theme.LiquidGlass.amberGlow)
            metricItem(label: "Margem Térmica TjMax", value: "+\(Int(report.cpu.tjMaxHeadroomCelsius))°C (Sem Throttling)", highlightColor: Theme.LiquidGlass.emeraldGlow)
        }
    }

    @ViewBuilder
    private var gpuDetailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricItem(label: "Placa Gráfica", value: report.gpu.modelName)
            metricItem(label: "Memória VRAM Dedicada", value: "\(report.gpu.vramMB) MB")
            metricItem(label: "Suporte Metal API", value: report.gpu.metalFeatureSet)
            metricItem(label: "Monitores Conectados", value: report.gpu.activeDisplays)
        }
    }

    @ViewBuilder
    private var memoryDetailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricItem(label: "Capacidade Total", value: "\(Int(report.memory.totalGB)) GB RAM")
            metricItem(label: "Tipo de Memória", value: report.memory.memoryType)
            metricItem(label: "Memória em Uso", value: String(format: "%.1f GB", report.memory.usedGB))
            metricItem(label: "Memória Comprimida", value: String(format: "%.2f GB", report.memory.compressedGB))
            metricItem(label: "Pressão de Memória", value: "\(Int(report.memory.pressurePercent))%", highlightColor: Theme.LiquidGlass.cyanGlow)
            metricItem(label: "Arquivo de Troca (Swap)", value: "\(Int(report.memory.swapUsedMB)) MB")
        }
    }

    @ViewBuilder
    private var batteryDetailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricItem(label: "Estado de Saúde (SoH)", value: "\(Int(report.battery.healthPercent))%", highlightColor: Theme.LiquidGlass.emeraldGlow)
            metricItem(label: "Ciclos de Recarga", value: "\(report.battery.cycleCount) ciclos")
            metricItem(label: "Capacidade Atual / Projeto", value: "\(report.battery.maxCapacityMAh) mAh / \(report.battery.designCapacityMAh) mAh")
            metricItem(label: "Potência em Tempo Real", value: String(format: "%.2f W", report.battery.currentWattage))
            metricItem(label: "Voltagem da Célula", value: String(format: "%.2f V", report.battery.voltageVolts))
            metricItem(label: "Temperatura da Bateria", value: String(format: "%.1f °C", report.battery.temperatureCelsius))
        }
    }

    @ViewBuilder
    private var storageDetailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricItem(label: "Volume Principal", value: report.storage.driveName)
            metricItem(label: "Espaço Total", value: "\(Int(report.storage.totalGB)) GB")
            metricItem(label: "Espaço Disponível", value: "\(Int(report.storage.freeGB)) GB (\(Int((report.storage.freeGB / max(1, report.storage.totalGB)) * 100))% livre)", highlightColor: Theme.LiquidGlass.emeraldGlow)
            metricItem(label: "Status SMART", value: report.storage.smartStatus)
        }
    }

    private func metricItem(label: String, value: String, highlightColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(highlightColor ?? Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Carregando telemetria profunda de hardware...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
