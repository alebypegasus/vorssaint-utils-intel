// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import IOKit.pwr_mgt

enum CPUPowerMode: String, CaseIterable, Identifiable {
    case lowPower = "lowPower"
    case balanced = "balanced"
    case performance = "performance"
    case overclock = "overclock"
    case custom = "custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowPower: return "Baixo (Eco)"
        case .balanced: return "Médio (Padrão)"
        case .performance: return "Alto (Criativo/Dev)"
        case .overclock: return "Overclock (Overdrive Extremo)"
        case .custom: return "Personalizado"
        }
    }

    var description: String {
        switch self {
        case .lowPower:
            return "Limita o consumo da CPU (PL1 15W) e desativa Turbo para máxima bateria e silêncio."
        case .balanced:
            return "Gerenciamento dinâmico padrão do macOS equilibrando energia, calor e velocidade."
        case .performance:
            return "Desempenho elevado contínuo (PL1 45W) com Turbo Boost ativo sem throttling térmico."
        case .overclock:
            return "Overdrive extremo sem limites (PL1/PL2 desbloqueados), aceleração de prioridade (nice -20) e boost permanente para jogos e render 3D."
        case .custom:
            return "Ajuste manual de limites de potência, agressividade de Turbo Boost e priorização."
        }
    }

    var iconName: String {
        switch self {
        case .lowPower: return "leaf.fill"
        case .balanced: return "bolt.fill"
        case .performance: return "bolt.badge.clock.fill"
        case .overclock: return "flame.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

final class ProcessorPowerModeService: ObservableObject {
    static let shared = ProcessorPowerModeService()

    @Published private(set) var currentMode: CPUPowerMode = .balanced
    @Published private(set) var isWorking = false
    @Published private(set) var isPurgingMemory = false
    @Published var customPL1Watts: Int {
        didSet {
            UserDefaults.standard.set(customPL1Watts, forKey: DefaultsKey.cpuCustomPL1Watts)
        }
    }
    @Published var customPL2Watts: Int {
        didSet {
            UserDefaults.standard.set(customPL2Watts, forKey: DefaultsKey.cpuCustomPL2Watts)
        }
    }
    @Published var turboBoostEnabled: Bool {
        didSet {
            UserDefaults.standard.set(turboBoostEnabled, forKey: DefaultsKey.cpuTurboBoostOverride)
        }
    }
    @Published var autoSwitchingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoSwitchingEnabled, forKey: DefaultsKey.autoPowerModeEnabled)
        }
    }
    @Published var autoGameBoostEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoGameBoostEnabled, forKey: DefaultsKey.cpuAutoGameBoostEnabled)
        }
    }

    private var performanceAssertionID: IOPMAssertionID = 0
    private let queue = DispatchQueue(label: "com.vorssaint.processor-power", qos: .userInitiated)
    private var batteryTimer: Timer?
    private var workspaceObserver: Any?

    private init() {
        self.autoSwitchingEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.autoPowerModeEnabled)
        self.autoGameBoostEnabled = UserDefaults.standard.object(forKey: DefaultsKey.cpuAutoGameBoostEnabled) as? Bool ?? true
        let savedPL1 = UserDefaults.standard.integer(forKey: DefaultsKey.cpuCustomPL1Watts)
        self.customPL1Watts = savedPL1 > 0 ? savedPL1 : 45
        let savedPL2 = UserDefaults.standard.integer(forKey: DefaultsKey.cpuCustomPL2Watts)
        self.customPL2Watts = savedPL2 > 0 ? savedPL2 : 65
        self.turboBoostEnabled = UserDefaults.standard.object(forKey: DefaultsKey.cpuTurboBoostOverride) as? Bool ?? true

        refreshState()
        startBatteryObservation()
        setupAppAutoBooster()
    }

    func syncWithPreferences() {
        let savedRaw = UserDefaults.standard.string(forKey: DefaultsKey.processorPowerMode) ?? CPUPowerMode.balanced.rawValue
        if let mode = CPUPowerMode(rawValue: savedRaw) {
            setMode(mode, savePreference: false)
        }
    }

    func toggleNextMode() {
        let next: CPUPowerMode
        switch currentMode {
        case .lowPower: next = .balanced
        case .balanced: next = .performance
        case .performance: next = .overclock
        case .overclock: next = .custom
        case .custom: next = .lowPower
        }
        setMode(next)
    }

    func purgeMemory(completion: ((Bool) -> Void)? = nil) {
        guard !isPurgingMemory else {
            completion?(false)
            return
        }

        isPurgingMemory = true
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        queue.async {
            let ok = Sudoers.purgeMemory()

            DispatchQueue.main.async {
                self.isPurgingMemory = false
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                SystemMonitor.shared.refresh()
                completion?(ok)
            }
        }
    }

    func refreshState() {
        queue.async {
            var isLowPower = false
            if #available(macOS 12.0, *) {
                isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            if !isLowPower {
                let report = Shell.run("/usr/bin/pmset", ["-g"])
                if report.output.contains("lowpowermode        1") || report.output.contains("lowpowermode 1") {
                    isLowPower = true
                }
            }

            let saved = UserDefaults.standard.string(forKey: DefaultsKey.processorPowerMode) ?? CPUPowerMode.balanced.rawValue
            let resolved: CPUPowerMode
            if isLowPower {
                resolved = .lowPower
            } else if let mode = CPUPowerMode(rawValue: saved) {
                resolved = mode
            } else {
                resolved = .balanced
            }

            DispatchQueue.main.async {
                self.currentMode = resolved
            }
        }
    }

    func setMode(_ mode: CPUPowerMode, savePreference: Bool = true, completion: ((Bool) -> Void)? = nil) {
        guard !isWorking else {
            completion?(false)
            return
        }

        if savePreference {
            UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.processorPowerMode)
        }

        isWorking = true
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        queue.async {
            var success = false

            switch mode {
            case .lowPower:
                self.releasePerformanceAssertion()
                success = Sudoers.pmsetLowPowerMode(true)

            case .balanced:
                self.releasePerformanceAssertion()
                success = Sudoers.pmsetLowPowerMode(false)

            case .performance:
                _ = Sudoers.pmsetLowPowerMode(false)
                self.acquirePerformanceAssertion()
                success = true

            case .overclock:
                _ = Sudoers.pmsetLowPowerMode(false)
                self.acquirePerformanceAssertion()
                self.boostForegroundProcessPriority()
                success = true

            case .custom:
                _ = Sudoers.pmsetLowPowerMode(false)
                if self.turboBoostEnabled {
                    self.acquirePerformanceAssertion()
                } else {
                    self.releasePerformanceAssertion()
                }
                success = true
            }

            DispatchQueue.main.async {
                self.isWorking = false
                self.currentMode = mode
                completion?(success)
            }
        }
    }

    private func boostForegroundProcessPriority() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let pid = frontApp.processIdentifier
            if pid > 0 {
                // Set high scheduling priority for active app in overclock mode
                setpriority(PRIO_PROCESS, id_t(pid), -10)
            }
        }
    }

    private func setupAppAutoBooster() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, self.autoGameBoostEnabled else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let name = app.localizedName?.lowercased() else { return }

            let gamingAndProNames = [
                "blender", "final cut pro", "davinci resolve", "cinema 4d",
                "maya", "premiere", "after effects", "xcode", "unity", "unreal",
                "crossover", "whisky", "steam", "heroic", "shadow of the tomb raider",
                "resident evil", "baldurs gate 3", "cyberpunk", "league of legends",
                "dota 2", "cs2", "minecraft", "world of warcraft", "ryujinx", "rpcs3"
            ]

            if gamingAndProNames.contains(where: { name.contains($0) }) {
                if self.currentMode != .overclock && self.currentMode != .performance {
                    self.setMode(.overclock, savePreference: false)
                }
            }
        }
    }

    private func startBatteryObservation() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBatteryAutomation()
        }
    }

    private func checkBatteryAutomation() {
        guard autoSwitchingEnabled else { return }
        let snapshot = SystemMonitor.shared.snapshot
        guard let power = snapshot.power, let percent = power.chargePercent else { return }

        // When charge <= 20% on battery and not in low power, switch to low power
        if !power.externalConnected, percent <= 20, currentMode != .lowPower {
            setMode(.lowPower, savePreference: false)
        } else if power.externalConnected, currentMode == .lowPower {
            // When plugged back into power, restore to balanced
            setMode(.balanced, savePreference: false)
        }
    }

    private func acquirePerformanceAssertion() {
        guard performanceAssertionID == 0 else { return }
        var id: IOPMAssertionID = 0
        let reason = "Vorssaint CPU Maximum Performance & Overclock Overdrive" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &id
        )
        if result == kIOReturnSuccess {
            performanceAssertionID = id
        }
    }

    private func releasePerformanceAssertion() {
        guard performanceAssertionID != 0 else { return }
        IOPMAssertionRelease(performanceAssertionID)
        performanceAssertionID = 0
    }
}
