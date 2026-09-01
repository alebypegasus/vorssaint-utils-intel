// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation
import IOKit.ps

struct EnergyHogProcess: Identifiable, Equatable {
    let id = UUID()
    let pid: pid_t
    let name: String
    let impactScore: Double // 0 to 100
    let memoryMB: Double
    let icon: NSImage?
}

/// Battery Health Guard: deep battery health analytics via IOKit and IOPMPowerSource,
/// tracking real charge cycles, State of Health (SoH), temperature, power draw, and 80% limiters.
final class BatteryHealthGuard: ObservableObject {
    static let shared = BatteryHealthGuard()

    struct BatteryStats: Equatable {
        var hasBattery: Bool = false
        var cycleCount: Int = 0
        var currentCapacity: Int = 0
        var maxCapacity: Int = 0
        var designCapacity: Int = 0
        var healthPercent: Double = 100.0
        var temperatureCelsius: Double = 0.0
        var isCharging: Bool = false
        var isPluggedIn: Bool = false
        var amperageMilliAmps: Int = 0
        var voltageMilliVolts: Int = 0
        var wattageWatts: Double = 0.0
        var timeRemainingMinutes: Int = -1
        var currentPercentage: Int = 100
        var projectedMonthsTo80: Int = 36
    }

    @Published private(set) var stats = BatteryStats()
    @Published private(set) var energyHogs: [EnergyHogProcess] = []
    @Published var chargeLimiter80Enabled: Bool {
        didSet {
            UserDefaults.standard.set(chargeLimiter80Enabled, forKey: DefaultsKey.batteryChargeLimit80Enabled)
        }
    }
    @Published var ultraEconomyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(ultraEconomyEnabled, forKey: DefaultsKey.batteryUltraEconomyEnabled)
            applyUltraEconomyState()
        }
    }
    @Published var thermalAlertEnabled: Bool {
        didSet {
            UserDefaults.standard.set(thermalAlertEnabled, forKey: DefaultsKey.batteryThermalAlertEnabled)
        }
    }

    private var timer: AnyCancellable?
    private var didNotify80 = false

    private init() {
        self.chargeLimiter80Enabled = UserDefaults.standard.bool(forKey: DefaultsKey.batteryChargeLimit80Enabled)
        self.ultraEconomyEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.batteryUltraEconomyEnabled)
        self.thermalAlertEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.batteryThermalAlertEnabled)

        refresh()
        timer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let newStats = Self.probeBattery()
            let hogs = self.findEnergyHogs()

            DispatchQueue.main.async {
                self.stats = newStats
                self.energyHogs = hogs
                self.check80LimitNotification(newStats)
            }
        }
    }

    private func check80LimitNotification(_ s: BatteryStats) {
        guard chargeLimiter80Enabled, s.isCharging, s.currentPercentage >= 80 else {
            if s.currentPercentage < 78 { didNotify80 = false }
            return
        }
        if !didNotify80 {
            didNotify80 = true
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            // Post friendly notification
            Notifier.post(
                title: "Bateria em 80% (Proteção de Vida Útil)",
                body: "O nível ideal de carga para preservação celular foi atingido. Desconecte da tomada se preferir economizar ciclos."
            )
        }
    }

    func toggleUltraEconomy() {
        ultraEconomyEnabled.toggle()
    }

    private func applyUltraEconomyState() {
        if ultraEconomyEnabled {
            ProcessorPowerModeService.shared.setMode(.lowPower)
        } else {
            ProcessorPowerModeService.shared.setMode(.balanced)
        }
    }

    func killEnergyHog(pid: pid_t) {
        kill(pid, SIGTERM)
        refresh()
    }

    private func findEnergyHogs() -> [EnergyHogProcess] {
        var hogs: [EnergyHogProcess] = []
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            guard !app.isTerminated, let name = app.localizedName else { continue }
            let pid = app.processIdentifier
            guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier else { continue }

            var procInfo = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.stride)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &procInfo, size)
            guard result == size else { continue }

            let memMB = Double(procInfo.pti_resident_size) / (1024.0 * 1024.0)
            let cpuTime = Double(procInfo.pti_total_user + procInfo.pti_total_system) / 1_000_000_000.0

            if memMB > 300 || cpuTime > 30 {
                let impact = min(100.0, (memMB / 40.0) + (cpuTime / 5.0))
                hogs.append(EnergyHogProcess(pid: pid, name: name, impactScore: impact, memoryMB: memMB, icon: app.icon))
            }
        }
        return hogs.sorted { $0.impactScore > $1.impactScore }.prefix(5).map { $0 }
    }

    private static func probeBattery() -> BatteryStats {
        var s = BatteryStats()

        // 1. Basic power source info
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
           let first = list.first,
           let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any] {

            s.hasBattery = true
            s.isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            s.isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            s.currentPercentage = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
            s.timeRemainingMinutes = (desc[kIOPSTimeToEmptyKey] as? Int) ?? -1
            if s.isCharging {
                s.timeRemainingMinutes = (desc[kIOPSTimeToFullChargeKey] as? Int) ?? -1
            }
        }

        // 2. Deep IOKit AppleSmartBattery probing
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        if service != 0 {
            defer { IOObjectRelease(service) }

            if let cycles = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.cycleCount = cycles
            }
            if let maxCap = IORegistryEntryCreateCFProperty(service, "AppleRawMaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.maxCapacity = maxCap
            } else if let maxCap = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.maxCapacity = maxCap
            }
            if let curCap = IORegistryEntryCreateCFProperty(service, "AppleRawCurrentCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.currentCapacity = curCap
            } else if let curCap = IORegistryEntryCreateCFProperty(service, "CurrentCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.currentCapacity = curCap
            }
            if let designCap = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.designCapacity = designCap
            }
            if let temp = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Double {
                s.temperatureCelsius = (temp / 100.0)
            }
            if let amp = IORegistryEntryCreateCFProperty(service, "Amperage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.amperageMilliAmps = amp
            }
            if let volt = IORegistryEntryCreateCFProperty(service, "Voltage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                s.voltageMilliVolts = volt
            }

            if s.voltageMilliVolts > 0 && s.amperageMilliAmps != 0 {
                s.wattageWatts = Double(abs(s.amperageMilliAmps) * s.voltageMilliVolts) / 1_000_000.0
            }

            if s.designCapacity > 0 && s.maxCapacity > 0 {
                s.healthPercent = min(100.0, max(0.0, (Double(s.maxCapacity) / Double(s.designCapacity)) * 100.0))
            }

            // Estimate months until 80% based on 1000 cycle standard design lifespan
            let remainingCyclesTo80 = max(0, 1000 - s.cycleCount)
            let avgCyclesPerMonth = max(5, s.cycleCount > 0 ? s.cycleCount / 12 : 15)
            s.projectedMonthsTo80 = max(6, remainingCyclesTo80 / avgCyclesPerMonth)
        }

        return s
    }
}
