// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Which per-app breakdown is expanded in the System section.
enum BreakdownKind {
    case cpu, gpu, memory, energy, network
}

/// The "System" section of the panel: component temperatures, hardware usage
/// and memory pressure, with zero clutter and intelligent dynamic coloring.
struct SystemSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var powerModeService = ProcessorPowerModeService.shared
    @Environment(\.colorScheme) private var colorScheme
    var collapsible = true
    @State private var expanded: BreakdownKind?
    @State private var showDeepMetrics = false
    @State private var alertsExpanded = false
    @State private var breakdownRows: [ProcessUsage] = []
    @State private var breakdownIsLoading = false
    @State private var lastBreakdownRefresh = Date.distantPast
    private let breakdownLimit = 15
    @AppStorage(DefaultsKey.monitorGraphCPU) private var graphCPU = true
    @AppStorage(DefaultsKey.monitorGraphGPU) private var graphGPU = true
    @AppStorage(DefaultsKey.monitorGraphMemory) private var graphMemory = true
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorSysTemps) private var sysTemps = true
    @AppStorage(DefaultsKey.monitorSysCPU) private var sysCPU = true
    @AppStorage(DefaultsKey.monitorSysGPU) private var sysGPU = true
    @AppStorage(DefaultsKey.monitorSysMemory) private var sysMemory = true
    @AppStorage(DefaultsKey.monitorSysUptime) private var sysUptime = true
    @AppStorage(DefaultsKey.panelSystemOrder) private var systemOrderRaw = ""
    @State private var draggingBlock: Block?

    var body: some View {
        PanelSection(.system, title: l10n.s.systemSection, collapsible: collapsible,
                     supportsEditing: true,
                     resetAction: resetPanelDefaults) { editing in
            VStack(alignment: .leading, spacing: 10) {
                let currentBlocks = blocks(editing: editing)
                ForEach(Array(currentBlocks.enumerated()), id: \.element) { index, block in
                    if index > 0 { Divider() }
                    PanelReorderableItem(item: block,
                                         isEnabled: editing,
                                         order: blockOrderBinding,
                                         dragging: $draggingBlock) {
                        HStack(alignment: .top, spacing: 8) {
                            if editing {
                                PanelDragHandle()
                            }
                            blockContent(block, editing: editing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if !editing {
                    Divider()
                    processorPowerModeControl
                    Divider()
                    deepMetricsButton
                }
            }
            .panelCard()
        }
        .sheet(isPresented: $showDeepMetrics) {
            DeepMetricsView()
        }
        .onReceive(monitor.$snapshot) { _ in
            guard expanded != nil, Date().timeIntervalSince(lastBreakdownRefresh) > 4 else { return }
            refreshBreakdown()
        }
        .onDisappear {
            expanded = nil
            breakdownRows = []
            breakdownIsLoading = false
        }
    }

    private enum Block: String, PanelOrderItem { case temps, usage, memory, uptime }

    private var cpuAvailable: Bool { AppFeature.monitorCPU.isAvailable }
    private var gpuAvailable: Bool { AppFeature.monitorGPU.isAvailable }
    private var memoryAvailable: Bool { AppFeature.monitorMemory.isAvailable }

    private var usageVisible: Bool {
        (sysCPU && cpuAvailable) || (sysGPU && gpuAvailable)
    }

    private var visibleBlocks: [Block] {
        orderedBlocks.filter { isBlockAvailable($0) && isVisible($0) }
    }

    private func blocks(editing: Bool) -> [Block] {
        editing ? orderedBlocks.filter(isBlockAvailable) : visibleBlocks
    }

    private func isBlockAvailable(_ block: Block) -> Bool {
        switch block {
        case .temps, .usage: return cpuAvailable || gpuAvailable
        case .memory: return memoryAvailable
        case .uptime: return true
        }
    }

    private var orderedBlocks: [Block] {
        _ = systemOrderRaw
        return PanelLayout.itemOrder(Block.self, key: DefaultsKey.panelSystemOrder)
    }

    private var blockOrderBinding: Binding<[Block]> {
        Binding {
            orderedBlocks
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelSystemOrder)
        }
    }

    private func isVisible(_ block: Block) -> Bool {
        switch block {
        case .temps: return sysTemps
        case .usage: return usageVisible
        case .memory: return sysMemory
        case .uptime: return sysUptime
        }
    }

    private func resetPanelDefaults() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelSystemOrder)
        systemOrderRaw = ""
        sysTemps = true
        sysCPU = true
        sysGPU = true
        sysMemory = true
        sysUptime = true
    }

    @ViewBuilder
    private func blockContent(_ block: Block, editing: Bool) -> some View {
        switch block {
        case .temps: temperatureGrid(editing: editing)
        case .usage: usageRows(editing: editing)
        case .memory: memoryRows(editing: editing)
        case .uptime: uptimeRow(editing: editing)
        }
    }

    // MARK: Per-app breakdown

    private func toggleBreakdown(_ kind: BreakdownKind) {
        if expanded == kind {
            expanded = nil
            breakdownRows = []
            breakdownIsLoading = false
        } else {
            expanded = kind
            breakdownRows = ProcessUsageService.shared.cachedTop(kind, limit: breakdownLimit) ?? []
            refreshBreakdown()
        }
    }

    private func refreshBreakdown() {
        guard let kind = expanded else { return }
        lastBreakdownRefresh = Date()
        breakdownIsLoading = breakdownRows.isEmpty
        DispatchQueue.global(qos: .utility).async {
            let rows = ProcessUsageService.shared.top(kind, limit: breakdownLimit)
            DispatchQueue.main.async {
                guard expanded == kind else { return }
                breakdownIsLoading = false
                if !rows.isEmpty || breakdownRows.isEmpty {
                    breakdownRows = rows
                }
            }
        }
    }

    // MARK: Processor Power Mode

    @ViewBuilder
    private var processorPowerModeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Desempenho do Processador", systemImage: "speedometer")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if powerModeService.isWorking {
                    ProgressView().controlSize(.mini)
                }
            }

            HStack(spacing: 4) {
                ForEach(CPUPowerMode.allCases) { mode in
                    let isSelected = powerModeService.currentMode == mode
                    Button {
                        withAnimation(.liquidSpring) {
                            powerModeService.setMode(mode)
                        }
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: powerModeGradient(for: mode),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(Color.primary.opacity(0.04))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(powerModeService.isWorking)

            Text(powerModeService.currentMode.description)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func powerModeGradient(for mode: CPUPowerMode) -> [Color] {
        switch mode {
        case .lowPower:
            return [Theme.LiquidGlass.emeraldGlow, Theme.LiquidGlass.emeraldGlow.opacity(0.85)]
        case .balanced:
            return [Color(red: 0.25, green: 0.45, blue: 0.85), Color(red: 0.18, green: 0.35, blue: 0.75)]
        case .maximum:
            return [Color.orange, Color.orange.opacity(0.85)]
        }
    }

    @ViewBuilder
    private var deepMetricsButton: some View {
        Button(action: {
            showDeepMetrics = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 11))
                Text("Relatório Profundo (Hardware & Energia)")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func breakdownList(for kind: BreakdownKind) -> some View {
        if expanded == kind {
            VStack(alignment: .leading, spacing: 4) {
                if breakdownRows.isEmpty {
                    Text(breakdownIsLoading ? l10n.s.breakdownMeasuring : emptyBreakdownText(for: kind))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 38)
                } else {
                    ForEach(breakdownRows) { row in
                        ProcessUsageRow(row: row,
                                        value: breakdownValue(row, for: kind),
                                        iconSize: 14,
                                        leadingPadding: 38)
                    }
                }
            }
        }
    }

    private func emptyBreakdownText(for kind: BreakdownKind) -> String {
        kind == .energy ? l10n.s.energyAppsIdle : l10n.s.breakdownMeasuring
    }

    private func breakdownValue(_ row: ProcessUsage, for kind: BreakdownKind) -> String {
        kind == .memory ? formatMemory(UInt64(row.value)) : String(format: "%.1f%%", row.value)
    }

    // MARK: Temperatures

    @ViewBuilder
    private func temperatureGrid(editing: Bool) -> some View {
        if !sysTemps {
            PanelHiddenItemRow(title: l10n.s.temperatures,
                               systemImage: "thermometer.medium",
                               isVisible: $sysTemps)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    subsectionLabel(l10n.s.temperatures)
                    Spacer(minLength: 0)
                    if editing {
                        PanelInlineHideButton(isVisible: $sysTemps)
                    }
                }
                HStack(spacing: 8) {
                    if cpuAvailable, let cpuTemp = monitor.snapshot.cpuTemperature {
                        temperatureCell(icon: "cpu", label: l10n.s.cpuLabel, value: cpuTemp)
                    }
                    if gpuAvailable, let gpuTemp = monitor.snapshot.gpuTemperature {
                        temperatureCell(icon: "memorychip", label: l10n.s.gpuLabel, value: gpuTemp)
                    }
                    if let batteryTemp = monitor.snapshot.batteryTemperature {
                        temperatureCell(icon: "battery.100", label: l10n.s.batteryLabel, value: batteryTemp)
                    }
                }
                if monitor.snapshot.cpuTemperature == nil,
                   monitor.snapshot.gpuTemperature == nil {
                    Text(l10n.s.monitorUnavailable)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func temperatureCell(icon: String, label: String, value: Double) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(MetricFormat.temperature(value, unit: displayTemperatureUnit))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value > 85 ? Color.red : (value > 75 ? Color.orange : Color.primary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.8)
        )
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    // MARK: Hardware usage

    private func usageRows(editing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                subsectionLabel(l10n.s.usageSection)
                Spacer(minLength: 0)
                if !editing {
                    ActivityMonitorButton()
                }
            }
            if sysCPU, cpuAvailable {
                usageRow(label: l10n.s.cpuLabel, fraction: monitor.snapshot.cpuUsage,
                         kind: .cpu, tintColor: Theme.LiquidGlass.cyanGlow, editing: editing, visible: $sysCPU)
                if graphCPU, monitor.snapshot.cpuHistory.count >= 2 {
                    Sparkline(values: monitor.snapshot.cpuHistory,
                              color: Theme.LiquidGlass.cyanGlow,
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 22)
                }
                breakdownList(for: .cpu)
            } else if editing, cpuAvailable {
                PanelHiddenItemRow(title: l10n.s.cpuLabel, systemImage: "cpu", isVisible: $sysCPU)
            }
            if sysGPU, gpuAvailable {
                usageRow(label: l10n.s.gpuLabel, fraction: monitor.snapshot.gpuUsage,
                         kind: .gpu, tintColor: Theme.LiquidGlass.violetGlow, editing: editing, visible: $sysGPU)
                if graphGPU, monitor.snapshot.gpuHistory.count >= 2 {
                    Sparkline(values: monitor.snapshot.gpuHistory,
                              color: Theme.LiquidGlass.violetGlow,
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 22)
                }
                breakdownList(for: .gpu)
            } else if editing, gpuAvailable {
                PanelHiddenItemRow(title: l10n.s.gpuLabel, systemImage: "memorychip", isVisible: $sysGPU)
            }
        }
    }

    @ViewBuilder
    private func uptimeRow(editing: Bool) -> some View {
        if !sysUptime {
            PanelHiddenItemRow(title: l10n.s.monitorItemUptime, systemImage: "clock", isVisible: $sysUptime)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("\(l10n.s.systemUptime) \(Self.uptimeString())")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if editing {
                    PanelInlineHideButton(isVisible: $sysUptime)
                }
            }
        }
    }

    static func uptimeString() -> String {
        let total = SystemInfo.wallClockUptimeSeconds() ?? Int(ProcessInfo.processInfo.systemUptime)
        return MetricFormat.uptime(total)
    }

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private func usageRow(label: String, fraction: Double?, kind: BreakdownKind,
                          tintColor: Color, editing: Bool, visible: Binding<Bool>) -> some View {
        Group {
            if editing {
                usageRowContent(label: label, fraction: fraction, kind: kind, tintColor: tintColor, isInteractive: false) {
                    PanelInlineHideButton(isVisible: visible)
                }
            } else {
                Button {
                    toggleBreakdown(kind)
                } label: {
                    usageRowContent(label: label, fraction: fraction, kind: kind, tintColor: tintColor, isInteractive: true) {
                        EmptyView()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func usageRowContent<Trailing: View>(label: String, fraction: Double?,
                                                 kind: BreakdownKind, tintColor: Color, isInteractive: Bool,
                                                 @ViewBuilder trailing: () -> Trailing) -> some View {
        let frac = fraction ?? 0
        let effectiveTint: Color = frac > 0.85 ? Color.red : (frac > 0.60 ? Color.orange : tintColor)

        return HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded == kind ? 90 : 0))
                .opacity(isInteractive ? 1 : 0.35)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 48, alignment: .leading)
            UsageBar(fraction: frac, tint: effectiveTint)
            Text(fraction.map { String(format: "%.0f%%", $0 * 100) } ?? "-")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(frac > 0.85 ? Color.red : Color.primary)
                .frame(width: 38, alignment: .trailing)
            trailing()
        }
    }

    // MARK: Memory

    @ViewBuilder
    private func memoryRows(editing: Bool) -> some View {
        if !sysMemory {
            PanelHiddenItemRow(title: l10n.s.memorySection,
                               systemImage: "memorychip.fill",
                               isVisible: $sysMemory)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    subsectionLabel(l10n.s.memorySection)
                    Spacer(minLength: 0)
                    if editing {
                        PanelInlineHideButton(isVisible: $sysMemory)
                    } else {
                        // Purge RAM Button
                        Button(action: {
                            powerModeService.purgeMemory()
                        }) {
                            HStack(spacing: 3) {
                                if powerModeService.isPurgingMemory {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 8.5))
                                }
                                Text("Liberar RAM")
                                    .font(.system(size: 9.5, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(powerModeService.isPurgingMemory)
                    }
                }
                if editing {
                    memoryRowContent(isInteractive: false)
                } else {
                    Button {
                        toggleBreakdown(.memory)
                    } label: {
                        memoryRowContent(isInteractive: true)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                memorySecondaryRow(l10n.s.memoryCompressed, monitor.snapshot.memoryCompressed)
                memorySecondaryRow(l10n.s.memoryCachedFiles, monitor.snapshot.memoryCached)
                memorySecondaryRow(l10n.s.memorySwapUsed, monitor.snapshot.memorySwapUsed)
                let memoryHistory = MonitorMemoryMetric.current.history(in: monitor.snapshot)
                if graphMemory, memoryHistory.count >= 2 {
                    Sparkline(values: memoryHistory,
                              color: Theme.LiquidGlass.emeraldGlow,
                              maxValue: 1,
                              showsZeroBaseline: true)
                        .frame(height: 22)
                }
                breakdownList(for: .memory)
            }
        }
    }

    private func memoryRowContent(isInteractive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded == .memory ? 90 : 0))
                .opacity(isInteractive ? 1 : 0.35)
            Text(l10n.s.memoryPressure)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            PressureIndicator(pressure: monitor.snapshot.memoryPressure)
            Spacer()
            Text(memoryUsageText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
        }
    }

    private func memorySecondaryRow(_ label: String, _ bytes: UInt64?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.leading, 18)
            Spacer()
            Text(bytes.map(formatMemory) ?? "-")
                .font(.system(size: 10, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var memoryUsageText: String {
        guard let used = monitor.snapshot.memoryUsed,
              let total = monitor.snapshot.memoryTotal else { return "-" }
        return "\(formatMemory(used)) / \(formatMemory(total))"
    }

    private func subsectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        Self.memoryFormatter.string(fromByteCount: Int64(bytes))
    }
}

/// Thin capacity bar for CPU/GPU usage with smooth gradients.
private struct UsageBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let fraction: Double
    var tint: Color? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint ?? Theme.LiquidGlass.cyanGlow)
                    .frame(width: max(3, proxy.size.width * min(1, fraction)))
            }
        }
        .frame(height: 5)
    }
}

/// Traffic-light pill for memory pressure: green = normal, yellow = caution,
/// red = critical.
struct PressureIndicator: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let pressure: MemoryPressure

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch pressure {
        case .normal: return Theme.LiquidGlass.emeraldGlow
        case .warning: return Color.orange
        case .critical: return Color.red
        case .unknown: return Color.secondary
        }
    }

    private var title: String {
        switch pressure {
        case .normal: return l10n.s.pressureNormal
        case .warning: return l10n.s.pressureWarning
        case .critical: return l10n.s.pressureCritical
        case .unknown: return "-"
        }
    }
}
