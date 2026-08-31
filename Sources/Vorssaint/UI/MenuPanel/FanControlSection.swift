// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct FanControlSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = FanControlService.shared
    @AppStorage(DefaultsKey.fanControlMode) private var modeRaw = FanControlMode.system.rawValue
    @AppStorage(DefaultsKey.fanControlCoolingLevel) private var coolingLevel =
        FanControlPolicy.defaultCoolingLevel
    @AppStorage(DefaultsKey.fanControlCurves) private var curvesStorage =
        FanControlConfiguration.defaultCurvesStorage
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit =
        TemperatureUnit.celsius.rawValue
    var collapsible = true

    private var strings: FanControlFeatureStrings {
        FeatureStrings.fanControl(l10n.language)
    }

    var body: some View {
        PanelSection(.fanControl, title: strings.title, collapsible: collapsible) {
            FanControlCardContent(strings: strings,
                                  snapshot: service.snapshot,
                                  accessState: service.accessState,
                                  error: service.error,
                                  isWorking: service.isWorking,
                                  mode: modeBinding,
                                  coolingLevel: $coolingLevel,
                                  curves: curvesBinding,
                                  temperatureUnit: displayTemperatureUnit,
                                  authorize: service.authorize,
                                  applyConfiguration: service.applyConfiguration,
                                  stopCooling: service.restoreAutomatic)
                .panelCard()
                .onAppear { service.panelDidAppear() }
                .onDisappear { service.panelDidDisappear() }
        }
    }

    private var modeBinding: Binding<FanControlMode> {
        Binding(
            get: { FanControlMode(rawValue: modeRaw) ?? .system },
            set: { modeRaw = $0.rawValue }
        )
    }

    private var curvesBinding: Binding<[FanControlCurve]> {
        Binding(
            get: {
                FanControlConfiguration.decodeCurves(curvesStorage)
                    ?? [FanControlConfiguration.defaultCurve]
            },
            set: { curves in
                if let encoded = FanControlConfiguration.encodeCurves(curves) {
                    curvesStorage = encoded
                }
            }
        )
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }
}

struct FanControlCardContent: View {
    let strings: FanControlFeatureStrings
    let snapshot: FanControlSnapshot
    let accessState: FanControlService.AccessState
    let error: FanControlErrorCode?
    let isWorking: Bool
    @Binding var mode: FanControlMode
    @Binding var coolingLevel: Int
    @Binding var curves: [FanControlCurve]
    let temperatureUnit: TemperatureUnit
    let authorize: () -> Void
    let applyConfiguration: (FanControlConfiguration) -> Void
    let stopCooling: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader

            if !snapshot.fans.isEmpty { fanRows }

            if let message = stateMessage {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(messageIsError ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if canConfigure {
                modePicker
                switch mode {
                case .system:
                    EmptyView()
                case .manual:
                    manualControl
                case .curve:
                    FanControlCurveEditor(strings: strings,
                                          curves: $curves,
                                          temperatures: snapshot.temperatures ?? [],
                                          temperatureUnit: temperatureUnit,
                                          disabled: isWorking)
                    if !curveCanRun {
                        Text(strings.curveUnavailable)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            action

            if controlsCanAppear {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.LiquidGlass.emeraldGlow)
                    Text("Proteção térmica ativa com restauração automática.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            modePill(FanControlMode.system, title: strings.systemControl, icon: "gearshape")
            modePill(FanControlMode.manual, title: strings.manualControl, icon: "slider.horizontal.3")
            modePill(FanControlMode.curve, title: strings.customCurve, icon: "chart.xyaxis.line")
        }
        .padding(3)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
        .disabled(isWorking)
    }

    private func modePill(_ targetMode: FanControlMode, title: String, icon: String) -> some View {
        let isSelected = mode == targetMode
        return Button {
            withAnimation(.liquidSpring) {
                mode = targetMode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4.5)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Theme.LiquidGlass.cyanGlow,
                                Theme.LiquidGlass.cyanGlow.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
            .shadow(color: isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.4) : Color.clear, radius: 4)
        }
        .buttonStyle(.plain)
    }

    private var manualControl: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(strings.coolingIntensity)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedCoolingLevel)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.LiquidGlass.cyanGlow)
            }
            Slider(value: coolingLevelBinding,
                   in: Double(FanControlPolicy.minimumCoolingLevel)...Double(FanControlPolicy.maximumCoolingLevel),
                   step: Double(FanControlPolicy.coolingLevelStep))
                .tint(Theme.LiquidGlass.cyanGlow)
                .controlSize(.small)
                .disabled(isWorking)
        }
        .padding(.vertical, 2)
    }

    private var statusHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((snapshot.isCooling ? Theme.LiquidGlass.cyanGlow : Color.primary).opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: snapshot.isCooling ? "fanblades.fill" : "fanblades")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(snapshot.isCooling ? Theme.LiquidGlass.cyanGlow : Color.secondary)
                    .symbolEffect(.variableColor.iterative, options: .repeating,
                                  isActive: snapshot.isCooling)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(strings.title)
                    .font(.system(size: 12, weight: .bold))

                Text(statusText)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(snapshot.isCooling ? Theme.LiquidGlass.cyanGlow : Color.secondary)
            }
            Spacer()
            if isWorking { ProgressView().controlSize(.small) }
        }
    }

    private var fanRows: some View {
        VStack(spacing: 4) {
            ForEach(snapshot.fans) { fan in
                HStack(spacing: 6) {
                    Text(String(format: strings.fanNameFormat, fan.index + 1))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(String(format: strings.currentRPMFormat, Int(fan.actualRPM.rounded())))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.primary)
                        if fan.isManuallyControlled {
                            Text("(\(Int(fan.targetRPM.rounded())) RPM alvo)")
                                .font(.system(size: 9.5).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private var action: some View {
        if error == .noFans || error == .unsupportedHardware || error == .alreadyControlled {
            EmptyView()
        } else if accessState == .notRegistered, !snapshot.fans.isEmpty {
            liquidActionButton(title: strings.allowControl, action: authorize)
        } else if accessState == .requiresApproval, !snapshot.fans.isEmpty {
            liquidActionButton(title: strings.openSettings, action: authorize)
        } else if accessState == .enabled, controlsCanAppear {
            switch mode {
            case .system:
                if snapshot.isCooling {
                    liquidActionButton(title: strings.returnToSystem, action: stopCooling)
                }
            case .manual:
                liquidActionButton(title: strings.applyManual) {
                    coolingLevel = selectedCoolingLevel
                    applyConfiguration(.manual(level: selectedCoolingLevel))
                }
            case .curve:
                liquidActionButton(title: strings.applyCurve, disabled: isWorking || !curveCanRun) {
                    applyConfiguration(.curve(curves))
                }
            }
        }
    }

    private func liquidActionButton(title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Theme.LiquidGlass.cyanGlow,
                        Theme.LiquidGlass.cyanGlow.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
            )
            .foregroundStyle(Color.white)
            .shadow(color: Theme.LiquidGlass.cyanGlow.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(disabled || isWorking)
    }

    private var statusText: String {
        guard snapshot.isCooling else { return strings.systemControl }
        let level = snapshot.coolingLevel ?? FanControlPolicy.defaultCoolingLevel
        switch snapshot.configuration?.mode ?? .manual {
        case .system:
            return strings.systemControl
        case .manual:
            return "\(strings.manualControl) · \(level)%"
        case .curve:
            let activeCurves = snapshot.configuration?.curves ?? []
            let temperature = activeCurves.count == 1
                ? snapshot.temperatures?.first { $0.source == activeCurves[0].sensor }?.celsius
                : nil
            if let temperature {
                return "\(strings.customCurve) · \(MetricFormat.temperature(temperature, unit: temperatureUnit)) · \(level)%"
            }
            return "\(strings.customCurve) · \(level)%"
        }
    }

    private var stateMessage: String? {
        if error == .noFans { return strings.noFans }
        if accessState == .unavailable { return strings.unsupported }
        switch error {
        case .alreadyControlled: return strings.alreadyControlled
        case .unsupportedHardware: return strings.unsupported
        case .helperUnavailable, .controlFailed: return strings.failed
        case .authorizationRequired: return strings.approvalCaption
        case .noFans, .none: break
        }
        if accessState == .notRegistered, !snapshot.fans.isEmpty { return strings.approvalCaption }
        if accessState == .requiresApproval { return strings.approvalCaption }
        switch snapshot.stopReason {
        case .temperatureUnavailable: return strings.temperatureUnavailable
        case .timeLimit, .appDisconnected, .heartbeatLost, .hardwareChanged,
             .thermalPressure, .recovery:
            return strings.safetyStopped
        case .none:
            return nil
        }
    }

    private var messageIsError: Bool {
        switch error {
        case .alreadyControlled, .unsupportedHardware, .helperUnavailable, .controlFailed:
            return true
        default:
            return false
        }
    }

    private var controlsCanAppear: Bool {
        !snapshot.fans.isEmpty
            && (error == nil || error == .controlFailed || snapshot.isCooling)
    }

    private var canConfigure: Bool {
        controlsCanAppear && accessState == .enabled
    }

    private var selectedCoolingLevel: Int {
        let clamped = min(max(coolingLevel, FanControlPolicy.minimumCoolingLevel),
                          FanControlPolicy.maximumCoolingLevel)
        let remainder = clamped % FanControlPolicy.coolingLevelStep
        return remainder == 0 ? clamped : clamped + FanControlPolicy.coolingLevelStep - remainder
    }

    private var coolingLevelBinding: Binding<Double> {
        Binding(
            get: { Double(selectedCoolingLevel) },
            set: { coolingLevel = Int($0.rounded()) }
        )
    }

    private var curveCanRun: Bool {
        guard FanControlPolicy.validCurves(curves) else { return false }
        let available = Set((snapshot.temperatures ?? []).map(\.source))
        return curves.allSatisfy { available.contains($0.sensor) }
    }
}
