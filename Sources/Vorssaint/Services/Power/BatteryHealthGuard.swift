// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation
import IOKit.ps

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
    }

    @Published private(set) var stats = BatteryStats()
    @Published var chargeLimiter80Enabled: Bool = false

    private var timer: AnyCancellable?

    private init() {
        refresh()
        timer = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newStats = Self.probeBattery()
            DispatchQueue.main.async {
                self?.stats = newStats
            }
        }
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
        }

        return s
    }
}
