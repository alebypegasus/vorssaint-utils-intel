// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// macOS Health and Fluidity Advisor dashboard, offering real-time memory diagnostics,
/// bottleneck detection, and 1-click system tune-up actions.
struct SystemAdvisorView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var advisor = SystemOptimizer.shared
    @State private var actionMessage: String?
    @State private var runningAction: String?
    var compact = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                healthScoreCard
                diagnosticsSummary
                quickOptimizationsSection
                if !advisor.report.heavyProcesses.isEmpty {
                    heavyProcessesSection
                }
            }
            .padding(compact ? 16 : 24)
            .frame(maxWidth: 680)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            advisor.refresh()
        }
    }

    // MARK: - Health Score Card

    private var healthScoreCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: Double(advisor.report.score) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Text("\(advisor.report.score)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scoreTitle)
                    .font(.system(size: 16, weight: .bold))
                Text(scoreDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let lastOpt = advisor.report.lastOptimizedDate {
                    Text("Last optimized: \(DateFormatter.localizedString(from: lastOpt, dateStyle: .short, timeStyle: .short))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }

            Spacer()

            Button {
                advisor.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("Refresh Diagnostics")
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var scoreColor: Color {
        if advisor.report.score >= 85 { return .green }
        if advisor.report.score >= 65 { return .orange }
        return .red
    }

    private var scoreTitle: String {
        if advisor.report.score >= 85 { return "Mac Fluid & Healthy" }
        if advisor.report.score >= 65 { return "Mac Needs Optimization" }
        return "High Resource Pressure"
    }

    private var scoreDescription: String {
        if advisor.report.score >= 85 {
            return "Memory buffers are balanced, background daemons are moderate, and disk performance is optimal."
        }
        if advisor.report.score >= 65 {
            return "Memory pressure is elevated or startup items are creating background overhead. Run quick optimizations below."
        }
        return "Critical memory consumption or disk space is low. Free inactive memory and clean caches to restore fluidity."
    }

    // MARK: - Diagnostics Summary

    private var diagnosticsSummary: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "Memory Pressure",
                value: "\(Int(advisor.report.memoryPressurePercent))%",
                subtitle: "\(ByteCountFormatter.string(fromByteCount: advisor.report.freeMemoryBytes, countStyle: .memory)) free",
                icon: "memorychip",
                color: advisor.report.memoryPressurePercent > 75 ? .red : .blue
            )

            metricCard(
                title: "Disk Storage",
                value: "\(ByteCountFormatter.string(fromByteCount: advisor.report.diskFreeBytes, countStyle: .file))",
                subtitle: "available",
                icon: "internaldrive",
                color: .teal
            )

            metricCard(
                title: "Startup Items",
                value: "\(advisor.report.activeStartupItemsCount)",
                subtitle: "background agents",
                icon: "power",
                color: advisor.report.activeStartupItemsCount > 15 ? .orange : .indigo
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Quick Optimizations

    private var quickOptimizationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1-Click System Boost Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let msg = actionMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.system(size: 12))
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 10) {
                optimizationRow(
                    title: "Purge Inactive RAM Buffers",
                    description: "Reclaims unused memory cache pages and refreshes kernel buffer pressure.",
                    icon: "sparkles",
                    actionTitle: "Purge RAM",
                    action: {
                        runningAction = "RAM"
                        advisor.purgeInactiveRAM { _ in
                            runningAction = nil
                            actionMessage = "RAM Purged successfully"
                        }
                    },
                    isRunning: runningAction == "RAM"
                )

                optimizationRow(
                    title: "Flush macOS DNS Cache",
                    description: "Clears corrupt domain resolution cache, speeding up web browsing and network connectivity.",
                    icon: "network",
                    actionTitle: "Flush DNS",
                    action: {
                        runningAction = "DNS"
                        advisor.flushDNSCache { _ in
                            runningAction = nil
                            actionMessage = "DNS Cache cleared"
                        }
                    },
                    isRunning: runningAction == "DNS"
                )

                optimizationRow(
                    title: "Rebuild LaunchServices Database",
                    description: "Fixes duplicate or slow 'Open With' Finder menus and repairs corrupted file type associations.",
                    icon: "arrow.triangle.2.circlepath",
                    actionTitle: "Rebuild",
                    action: {
                        runningAction = "LS"
                        advisor.rebuildLaunchServices { _ in
                            runningAction = nil
                            actionMessage = "LaunchServices database rebuilt"
                        }
                    },
                    isRunning: runningAction == "LS"
                )

                optimizationRow(
                    title: "Reset QuickLook & Font Caches",
                    description: "Resolves Finder preview freezing, thumbnail generation lags, and font rendering glitches.",
                    icon: "eye",
                    actionTitle: "Reset Caches",
                    action: {
                        runningAction = "QL"
                        advisor.clearFontAndQuickLookCaches { _ in
                            runningAction = nil
                            actionMessage = "QuickLook and Font caches reset"
                        }
                    },
                    isRunning: runningAction == "QL"
                )

                optimizationRow(
                    title: "Reindex Spotlight Search",
                    description: "Fixes stalled searches and resets runaway mds background indexing CPU usage.",
                    icon: "magnifyingglass",
                    actionTitle: "Reindex",
                    action: {
                        runningAction = "Spotlight"
                        advisor.rebuildSpotlightIndex { _ in
                            runningAction = nil
                            actionMessage = "Spotlight reindex requested"
                        }
                    },
                    isRunning: runningAction == "Spotlight"
                )
            }
        }
    }

    private func optimizationRow(title: String, description: String, icon: String, actionTitle: String, action: @escaping () -> Void, isRunning: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isRunning {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Heavy Processes Section

    private var heavyProcessesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("High Memory Processes (>1.5 GB)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(advisor.report.heavyProcesses) { proc in
                    HStack(spacing: 10) {
                        if let icon = proc.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "app.dashed")
                                .frame(width: 22, height: 22)
                        }

                        Text(proc.name)
                            .font(.system(size: 12, weight: .medium))

                        Spacer()

                        Text(ByteCountFormatter.string(fromByteCount: proc.memoryBytes, countStyle: .memory))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
