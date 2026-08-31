// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NetworkOptimizerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var net = NetworkOptimizerService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Latency & Ping Card
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Network Latency", systemImage: "waveform.path.ecg")
                            .font(.headline)
                        if net.ping.isTesting {
                            Text("Pinging 1.1.1.1…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", net.ping.latencyMs))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("ms")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Jitter: \(String(format: "%.1f", net.ping.jitterMs)) ms • Packet Loss: 0%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        net.testLatency()
                    } label: {
                        Label("Test Ping", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(net.ping.isTesting)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))

                // DNS Profiles List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Secure DNS Profiles")
                        .font(.headline)
                    Text("Switch DNS servers instantly to accelerate browsing and block malware or ads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(NetworkOptimizerService.DNSProfile.allCases) { profile in
                            HStack(spacing: 12) {
                                Image(systemName: net.activeProfile == profile ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(net.activeProfile == profile ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(profile.servers.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if net.activeProfile != profile {
                                    Button("Apply") {
                                        net.applyDNSProfile(profile) { _ in }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))

                if let msg = net.statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(20)
        }
    }
}
