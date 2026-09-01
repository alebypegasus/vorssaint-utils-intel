// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct DiskUsageVisualizerView: View {
    @ObservedObject private var scanner = DiskUsageScannerService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedNode: DiskNode?
    @State private var hoveredNode: DiskNode?
    @State private var showDeleteConfirmation = false
    @State private var isPermanentDelete = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if scanner.isScanning {
                scanningView
            } else if let current = scanner.currentNode, !current.children.isEmpty {
                mainContentView(current: current)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if scanner.rootNode == nil {
                scanner.scan()
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(isPermanentDelete ? "Apagar Permanentemente?" : "Mover para o Lixo?"),
                message: Text(isPermanentDelete
                    ? "Esta ação não pode ser desfeita. O arquivo '\(selectedNode?.name ?? "")' será removido permanentemente."
                    : "O item '\(selectedNode?.name ?? "")' será movido para o Lixo."),
                primaryButton: .destructive(Text(isPermanentDelete ? "Apagar Definitivamente" : "Mover para o Lixo")) {
                    if let node = selectedNode {
                        if isPermanentDelete {
                            scanner.deletePermanently(node: node) { _ in selectedNode = nil }
                        } else {
                            scanner.trashItem(node: node) { _ in selectedNode = nil }
                        }
                    }
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }

    // MARK: - Header Bar & Breadcrumbs

    @ViewBuilder
    private var headerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Visualizador de Uso de Disco")
                        .font(.system(size: 15, weight: .bold))
                    Text("Explore a ocupação em gráfico de pizza e gerencie arquivos pesados")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Quick directory presets
                HStack(spacing: 6) {
                    quickTargetButton(title: "Início", path: NSHomeDirectory(), icon: "house.fill")
                    quickTargetButton(title: "Downloads", path: NSHomeDirectory() + "/Downloads", icon: "arrow.down.circle.fill")
                    quickTargetButton(title: "Apps", path: "/Applications", icon: "app.fill")
                    quickTargetButton(title: "Documentos", path: NSHomeDirectory() + "/Documents", icon: "folder.fill")

                    Button {
                        chooseCustomFolder()
                    } label: {
                        Label("Escolher...", systemImage: "ellipsis.folder")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        scanner.scan(url: scanner.currentNode?.url ?? scanner.selectedTargetURL)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Recarregar diretório atual")
                }
            }

            // Breadcrumbs Navigation Bar
            if !scanner.breadcrumbs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(scanner.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }

                        Button {
                            scanner.navigateBack(to: index)
                            selectedNode = nil
                        } label: {
                            Text(index == 0 ? "Raiz" : crumb.name)
                                .font(.system(size: 11, weight: index == scanner.breadcrumbs.count - 1 ? .bold : .regular))
                                .foregroundStyle(index == scanner.breadcrumbs.count - 1 ? Color.primary : Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(index == scanner.breadcrumbs.count - 1 ? Color.primary.opacity(0.06) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func quickTargetButton(title: String, path: String, icon: String) -> some View {
        let isSelected = scanner.selectedTargetURL.path == path
        return Button {
            scanner.scan(url: URL(fileURLWithPath: path))
            selectedNode = nil
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Analisar Pasta"
        if panel.runModal() == .OK, let url = panel.url {
            scanner.scan(url: url)
            selectedNode = nil
        }
    }

    // MARK: - Main Content: Donut Chart & File Explorer Panel

    @ViewBuilder
    private func mainContentView(current: DiskNode) -> some View {
        HStack(spacing: 0) {
            // Left: Donut Chart
            VStack(spacing: 12) {
                ZStack {
                    DonutChartView(nodes: current.children, selectedNode: $selectedNode, hoveredNode: $hoveredNode)
                        .frame(width: 280, height: 280)

                    // Center information badge
                    VStack(spacing: 2) {
                        let active = hoveredNode ?? selectedNode ?? current
                        Image(systemName: active.category.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(active.category.color)
                            .padding(.bottom, 2)

                        Text(active.name)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 130)

                        Text(MetricFormat.bytes(UInt64(max(0, active.size))))
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.LiquidGlass.cyanGlow)

                        if active.id != current.id {
                            Text(String(format: "%.1f%% do total", active.percentage))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                // Category Legends Bar
                HStack(spacing: 8) {
                    ForEach(DiskFileCategory.allCases) { cat in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text(cat.rawValue)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(width: 340)

            Divider()

            // Right: File List & Action Inspector
            VStack(spacing: 0) {
                // Table of children items
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(current.children) { node in
                            nodeRow(node: node, isSelected: selectedNode?.id == node.id)
                        }
                    }
                    .padding(12)
                }

                Divider()

                // Inspector Action Bottom Bar
                if let selected = selectedNode {
                    inspectorBottomBar(node: selected)
                } else {
                    HStack {
                        Text("Selecione um arquivo ou pasta acima para ações rápidas")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func nodeRow(node: DiskNode, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: node.isDirectory ? "folder.fill" : node.category.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(node.category.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(node.category.rawValue)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                    if node.isDirectory {
                        Text("• \(node.itemCount) itens")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Relative proportion bar
            VStack(alignment: .trailing, spacing: 2) {
                Text(MetricFormat.bytes(UInt64(max(0, node.size))))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)

                Text(String(format: "%.1f%%", node.percentage))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if node.isDirectory {
                Button {
                    scanner.navigateInto(node: node)
                    selectedNode = nil
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.LiquidGlass.cyanGlow)
                }
                .buttonStyle(.plain)
                .help("Abrir pasta e navegar")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : (hoveredNode?.id == node.id ? Color.primary.opacity(0.04) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNode = node
        }
    }

    private func inspectorBottomBar(node: DiskNode) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Text(node.url.path)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if node.isDirectory {
                Button("Entrar") {
                    scanner.navigateInto(node: node)
                    selectedNode = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                scanner.revealInFinder(node: node)
            } label: {
                Label("Finder", systemImage: "folder")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Revelar no Finder")

            Button {
                isPermanentDelete = false
                showDeleteConfirmation = true
            } label: {
                Label("Lixo", systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Mover para o Lixo")
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Scanning & Empty States

    @ViewBuilder
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Indexando ocupação de disco...")
                .font(.system(size: 14, weight: .bold))
            Text("\(scanner.scannedFilesCount) arquivos processados")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Nenhum arquivo encontrado nesta pasta")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Button("Voltar para o Início") {
                scanner.scan(url: URL(fileURLWithPath: NSHomeDirectory()))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SVG / SwiftUI Donut Slices Renderer

private struct DonutChartView: View {
    let nodes: [DiskNode]
    @Binding var selectedNode: DiskNode?
    @Binding var hoveredNode: DiskNode?

    private var slices: [(node: DiskNode, startAngle: Angle, endAngle: Angle)] {
        var result: [(node: DiskNode, startAngle: Angle, endAngle: Angle)] = []
        var currentDegrees: Double = -90.0

        for node in nodes {
            let sweep = (node.percentage / 100.0) * 360.0
            if sweep < 1.0 { continue }
            let endDegrees = currentDegrees + sweep
            result.append((node, Angle(degrees: currentDegrees), Angle(degrees: endDegrees)))
            currentDegrees = endDegrees
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let innerRadius = radius * 0.58

            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.primary.opacity(0.04), lineWidth: radius - innerRadius)
                    .frame(width: radius * 2 - (radius - innerRadius), height: radius * 2 - (radius - innerRadius))

                ForEach(slices, id: \.node.id) { slice in
                    let isSelected = selectedNode?.id == slice.node.id
                    let isHovered = hoveredNode?.id == slice.node.id

                    DonutSliceShape(startAngle: slice.startAngle, endAngle: slice.endAngle, innerRadius: innerRadius, outerRadius: (isSelected || isHovered) ? radius * 1.04 : radius)
                        .fill(slice.node.category.color)
                        .shadow(color: (isSelected || isHovered) ? slice.node.category.color.opacity(0.5) : Color.clear, radius: 6)
                        .scaleEffect((isSelected || isHovered) ? 1.03 : 1.0, anchor: .center)
                        .animation(.liquidSpring, value: isSelected)
                        .animation(.liquidSpring, value: isHovered)
                        .contentShape(DonutSliceShape(startAngle: slice.startAngle, endAngle: slice.endAngle, innerRadius: innerRadius, outerRadius: radius))
                        .onTapGesture {
                            selectedNode = slice.node
                        }
                        .onHover { h in
                            hoveredNode = h ? slice.node : nil
                        }
                }
            }
            .position(center)
        }
    }
}

private struct DonutSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()

        return path
    }
}
