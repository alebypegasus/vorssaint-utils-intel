//
//  FanControlSection.swift
//  Vorssaint
//

import SwiftUI

struct FanControlSection: View {
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var service = SMCFanControlService(smc: SMCClient())

    var collapsible = true

    var body: some View {
        PanelSection(
            .fanControl,
            title: FeatureStrings.fanControl(l10n.language).title,
            collapsible: collapsible
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if service.fans.isEmpty {
                    Text("No fans detected or lacking SMC permission.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                } else {
                    fanRows
                }
            }
            .panelCard()
            .onAppear {
                service.refresh()
            }
        }
    }

    @ViewBuilder
    private var fanRows: some View {
        if service.fans.indices.contains(0) {
            fanRow(service.fans[0])
        }

        if service.fans.indices.contains(1) {
            fanRow(service.fans[1])
        }

        if service.fans.indices.contains(2) {
            fanRow(service.fans[2])
        }

        if service.fans.indices.contains(3) {
            fanRow(service.fans[3])
        }

        if service.fans.indices.contains(4) {
            fanRow(service.fans[4])
        }

        if service.fans.indices.contains(5) {
            fanRow(service.fans[5])
        }
    }

    @ViewBuilder
    private func fanRow(_ fan: FanStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(fan.name)
                    .font(.system(size: 11, weight: .medium))

                Spacer()

                Text("\(Int(fan.actualSpeed)) RPM")
                    .font(.system(size: 11))
                    .monospacedDigit()
            }

            Picker(
                "",
                selection: Binding(
                    get: {
                        fan.isManual ? "manual" : "automatic"
                    },
                    set: { mode in
                        service.setManualMode(
                            for: fan.id,
                            manual: mode == "manual"
                        )
                    }
                )
            ) {
                Text("Automatic")
                    .tag("automatic")

                Text("Manual")
                    .tag("manual")
            }
            .pickerStyle(.segmented)

            if fan.isManual {
                Slider(
                    value: Binding(
                        get: {
                            fan.targetSpeed
                        },
                        set: { speed in
                            service.setTargetSpeed(
                                for: fan.id,
                                speed: speed
                            )
                        }
                    ),
                    in: fan.minSpeed...fan.maxSpeed,
                    step: 10
                )

                HStack {
                    Text("\(Int(fan.minSpeed))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("\(Int(fan.maxSpeed))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.top, 4)
    }
}
