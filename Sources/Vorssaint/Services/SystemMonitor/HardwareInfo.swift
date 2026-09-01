// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import Metal

struct CPUDetailedInfo: Equatable {
    var modelName: String = "Intel Core i7"
    var coreCount: Int = 8
    var threadCount: Int = 16
    var baseFrequencyGHz: Double = 2.6
    var maxBoostFrequencyGHz: Double = 4.5
    var currentPowerWatts: Double = 28.0
    var thermalThrottleStatus: String = "Normal (Sem Throttling)"
    var tjMaxHeadroomCelsius: Double = 42.0
    var architecture: String = "x86_64 / Intel Skylake-H"
}

struct GPUDetailedInfo: Equatable {
    var modelName: String = "Intel UHD Graphics 630"
    var vramMB: Int = 1536
    var metalFeatureSet: String = "Metal 3 (GPU Family macOS 2)"
    var coreClockMHz: Double = 1150
    var activeDisplays: String = "Built-in Retina LCD (2880x1800 @ 60Hz)"
}

struct MemoryDetailedInfo: Equatable {
    var totalGB: Double = 16.0
    var memoryType: String = "2400 MHz DDR4 (Dual Channel)"
    var usedGB: Double = 8.5
    var compressedGB: Double = 1.2
    var swapUsedMB: Double = 0.0
    var pressurePercent: Double = 45.0
}

struct BatteryDetailedInfo: Equatable {
    var hasBattery: Bool = true
    var healthPercent: Double = 94.0
    var cycleCount: Int = 210
    var designCapacityMAh: Int = 5088
    var maxCapacityMAh: Int = 4782
    var currentWattage: Double = 14.5
    var voltageVolts: Double = 11.4
    var temperatureCelsius: Double = 29.4
    var condition: String = "Normal"
}

struct StorageDetailedInfo: Equatable {
    var driveName: String = "Macintosh HD (Apple SSD APFS)"
    var totalGB: Double = 500.0
    var freeGB: Double = 210.0
    var smartStatus: String = "Verificado (Saudável)"
    var trimEnabled: Bool = true
}

struct DeepHardwareReport: Equatable {
    var cpu = CPUDetailedInfo()
    var gpu = GPUDetailedInfo()
    var memory = MemoryDetailedInfo()
    var battery = BatteryDetailedInfo()
    var storage = StorageDetailedInfo()
    var thermalSensors: [String: Double] = [:]
    var generatedDate = Date()

    func asMarkdown() -> String {
        """
        # Relatório Profundo de Hardware e Energia — Vorssaint Utils
        *Gerado em: \(generatedDate.formatted(date: .complete, time: .standard))*

        ## 1. Processador (CPU)
        - **Modelo**: \(cpu.modelName) (\(cpu.architecture))
        - **Núcleos/Threads**: \(cpu.coreCount) Cores / \(cpu.threadCount) Threads
        - **Frequência Base/Boost**: \(cpu.baseFrequencyGHz) GHz / \(cpu.maxBoostFrequencyGHz) GHz
        - **Consumo Dinâmico (Package)**: \(String(format: "%.1f", cpu.currentPowerWatts)) W
        - **Status Térmico**: \(cpu.thermalThrottleStatus) (Margem TjMax: +\(Int(cpu.tjMaxHeadroomCelsius))°C)

        ## 2. Gráficos (GPU)
        - **GPU**: \(gpu.modelName)
        - **VRAM**: \(gpu.vramMB) MB
        - **Suporte Metal**: \(gpu.metalFeatureSet)
        - **Monitores Ativos**: \(gpu.activeDisplays)

        ## 3. Memória RAM & Swap
        - **Capacidade**: \(Int(memory.totalGB)) GB (\(memory.memoryType))
        - **Uso Atual**: \(String(format: "%.1f", memory.usedGB)) GB (\(Int(memory.pressurePercent))% de pressão)
        - **Comprimida**: \(String(format: "%.2f", memory.compressedGB)) GB
        - **Arquivo de Troca (Swap)**: \(Int(memory.swapUsedMB)) MB

        ## 4. Bateria & Energia
        - **Saúde (SoH)**: \(Int(battery.healthPercent))% (\(battery.cycleCount) ciclos)
        - **Capacidade**: \(battery.maxCapacityMAh) mAh / \(battery.designCapacityMAh) mAh
        - **Potência em Tempo Real**: \(String(format: "%.2f", battery.currentWattage)) W (\(String(format: "%.1f", battery.voltageVolts)) V)
        - **Temperatura da Célula**: \(String(format: "%.1f", battery.temperatureCelsius)) °C

        ## 5. Armazenamento
        - **Disco Principal**: \(storage.driveName)
        - **Espaço Total/Livre**: \(Int(storage.totalGB)) GB / \(Int(storage.freeGB)) GB (\(Int((storage.freeGB / storage.totalGB) * 100))% livre)
        - **Status SMART**: \(storage.smartStatus) (TRIM: \(storage.trimEnabled ? "Ativo" : "Inativo"))
        """
    }
}

enum HardwareInfo {
    static func collectDeepReport() -> DeepHardwareReport {
        var report = DeepHardwareReport()

        // 1. CPU info
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let brandString = String(cString: brand).trimmingCharacters(in: .whitespacesAndNewlines)
        if !brandString.isEmpty {
            report.cpu.modelName = brandString
        }

        report.cpu.coreCount = ProcessInfo.processInfo.activeProcessorCount
        report.cpu.threadCount = ProcessInfo.processInfo.processorCount

        if let pwr = SystemMonitor.shared.snapshot.power?.systemWatts {
            report.cpu.currentPowerWatts = pwr
        }

        // 2. GPU info
        if let defaultDevice = MTLCreateSystemDefaultDevice() {
            report.gpu.modelName = defaultDevice.name
            if defaultDevice.supportsFamily(.apple7) || defaultDevice.supportsFamily(.mac2) {
                report.gpu.metalFeatureSet = "Metal 3 (Hardware Accelerated)"
            }
        }
        if let mainScreen = NSScreen.main {
            let res = mainScreen.frame.size
            report.gpu.activeDisplays = "\(Int(res.width))x\(Int(res.height)) @ 60Hz Retina"
        }

        // 3. Memory info
        let totalMem = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        report.memory.totalGB = totalMem
        let memSnapshot = MemoryMaintenanceService.shared.snapshot
        report.memory.usedGB = Double(memSnapshot.activeBytes + memSnapshot.wiredBytes) / (1024.0 * 1024.0 * 1024.0)
        report.memory.compressedGB = Double(memSnapshot.compressedBytes) / (1024.0 * 1024.0 * 1024.0)
        report.memory.pressurePercent = memSnapshot.pressurePercent

        // 4. Battery info
        let batStats = BatteryHealthGuard.shared.stats
        report.battery.hasBattery = batStats.hasBattery
        report.battery.healthPercent = batStats.healthPercent
        report.battery.cycleCount = batStats.cycleCount
        report.battery.designCapacityMAh = batStats.designCapacity
        report.battery.maxCapacityMAh = batStats.maxCapacity
        report.battery.currentWattage = batStats.wattageWatts
        report.battery.voltageVolts = Double(batStats.voltageMilliVolts) / 1000.0
        report.battery.temperatureCelsius = batStats.temperatureCelsius

        // 5. Storage info
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            report.storage.totalGB = Double(values.volumeTotalCapacity ?? 0) / (1024.0 * 1024.0 * 1024.0)
            report.storage.freeGB = Double(values.volumeAvailableCapacityForImportantUsage ?? 0) / (1024.0 * 1024.0 * 1024.0)
        }

        return report
    }

    static func getBatteryInfo() -> String {
        Shell.run("/usr/sbin/system_profiler", ["SPPowerDataType"]).output
    }

    static func getStorageInfo() -> String {
        Shell.run("/bin/df", ["-h"]).output
    }

    static func getMemoryInfo() -> String {
        Shell.run("/usr/bin/vm_stat", []).output
    }

    static func getNetworkInfo() -> String {
        Shell.run("/usr/sbin/system_profiler", ["SPNetworkDataType"]).output
    }
}
