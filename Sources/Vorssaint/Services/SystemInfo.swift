// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation
import IOKit.ps

struct BatteryInfo {
    let percent: Int
    let isCharging: Bool
    let isOnBattery: Bool
}

/// Point-in-time system facts that need no special permissions.
/// The battery snapshot feeds the keep-awake battery protection; the memory
/// reading feeds the system monitor.
enum SystemInfo {
    static func wallClockUptimeSeconds(now: Date = Date()) -> Int? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0 else { return nil }
        guard bootTime.tv_sec > 0 else { return nil }

        let bootSeconds = Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000
        let elapsed = now.timeIntervalSince1970 - bootSeconds
        guard elapsed.isFinite, elapsed >= 0 else { return nil }
        return Int(elapsed.rounded(.down))
    }

    static func batterySnapshot() -> BatteryInfo? {
        guard PowerSampler.hasInternalBattery else { return nil }
        guard let blobRef = IOPSCopyPowerSourcesInfo() else { return nil }
        let blob = blobRef.takeRetainedValue()
        guard let listRef = IOPSCopyPowerSourcesList(blob) else { return nil }
        let list = listRef.takeRetainedValue() as [AnyObject]
        guard let first = list.first,
              let descRef = IOPSGetPowerSourceDescription(blob, first),
              let desc = descRef.takeUnretainedValue() as? [String: Any]
        else { return nil }

        let current = desc["Current Capacity"] as? Int ?? 0
        let max = desc["Max Capacity"] as? Int ?? 100
        let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
        let charging = desc["Is Charging"] as? Bool ?? false
        let state = desc["Power Source State"] as? String ?? ""
        return BatteryInfo(percent: percent,
                           isCharging: charging,
                           isOnBattery: state == "Battery Power")
    }

    static func memoryUsage() -> (used: UInt64, appUsed: UInt64, total: UInt64, compressed: UInt64, cached: UInt64, swapUsed: UInt64?)? {
        guard let stats = VMStatisticsDecoder.read() else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(vm_kernel_page_size)
        let tagStoragePages = VMStatisticsDecoder.validatedTagStoragePages(
            stats.tagStoragePages,
            totalBytes: total,
            pageSize: pageSize)
        let appUsed = MetricFormat.appMemory(totalBytes: total,
                                             pageSize: pageSize,
                                             internalPages: stats.internalPages,
                                             purgeablePages: stats.purgeablePages)
        let used = MetricFormat.memoryUsed(totalBytes: total,
                                           appBytes: appUsed,
                                           pageSize: pageSize,
                                           wiredPages: stats.wiredPages,
                                           compressorPages: stats.compressorPages,
                                           tagStoragePages: tagStoragePages)
        let compressed = MetricFormat.compressedMemory(totalBytes: total,
                                                       pageSize: pageSize,
                                                       compressorPages: stats.compressorPages)
        let cached = MetricFormat.cachedFiles(totalBytes: total,
                                              pageSize: pageSize,
                                              fileBackedPages: stats.externalPages)
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.stride
        let swapUsed = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
            ? swap.xsu_used
            : nil
        return (used, appUsed, total, compressed, cached, swapUsed)
    }

    static func cpuBrandString() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return "Mac Processor"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else {
            return "Mac Processor"
        }
        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cpuFrequencyHz() -> UInt64? {
        var freq: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.cpufrequency", &freq, &size, nil, 0) == 0, freq > 0 {
            return freq
        }
        var freq32: UInt32 = 0
        var size32 = MemoryLayout<UInt32>.size
        if sysctlbyname("hw.cpufrequency", &freq32, &size32, nil, 0) == 0, freq32 > 0 {
            return UInt64(freq32)
        }
        return nil
    }
}
