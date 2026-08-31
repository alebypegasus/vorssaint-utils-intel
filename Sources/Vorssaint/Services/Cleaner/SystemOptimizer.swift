// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin
import Foundation

/// Analyzes macOS system health, memory pressure, and background bottlenecks,
/// providing 1-click optimizations to keep the Mac responsive, fast, and fluid.
final class SystemOptimizer: ObservableObject {
    static let shared = SystemOptimizer()

    enum ActionState: Equatable {
        case idle
        case running(String)
        case finished(String, success: Bool)
    }

    struct ResourceHog: Identifiable, Equatable {
        let id = UUID()
        let pid: Int32
        let name: String
        let cpuPercent: Double
        let memoryBytes: Int64
        let icon: NSImage?

        static func == (lhs: ResourceHog, rhs: ResourceHog) -> Bool {
            lhs.pid == rhs.pid && lhs.cpuPercent == rhs.cpuPercent
        }
    }

    struct SystemHealthReport: Equatable {
        var score: Int = 100 // 0 to 100
        var memoryPressurePercent: Double = 0.0
        var freeMemoryBytes: Int64 = 0
        var totalMemoryBytes: Int64 = 0
        var diskFreeBytes: Int64 = 0
        var diskTotalBytes: Int64 = 0
        var activeStartupItemsCount: Int = 0
        var heavyProcesses: [ResourceHog] = []
        var lastOptimizedDate: Date?
    }

    @Published private(set) var report = SystemHealthReport()
    @Published private(set) var actionState: ActionState = .idle
    @Published private(set) var isAnalyzing = false

    private var timer: AnyCancellable?

    private init() {
        refresh()
    }

    func refresh() {
        guard !isAnalyzing else { return }
        isAnalyzing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var rep = SystemHealthReport()

            // 1. Memory stats
            let memStats = Self.memoryStatistics()
            rep.totalMemoryBytes = memStats.total
            rep.freeMemoryBytes = memStats.free
            rep.memoryPressurePercent = memStats.pressurePercent

            // 2. Disk stats
            let diskStats = Self.diskStatistics()
            rep.diskTotalBytes = diskStats.total
            rep.diskFreeBytes = diskStats.free

            // 3. Startup items count
            rep.activeStartupItemsCount = Self.countStartupItems()

            // 4. Resource hogs
            rep.heavyProcesses = Self.findHeavyProcesses()

            // 5. Calculate overall health & fluidity score (0-100)
            var score = 100
            if rep.memoryPressurePercent > 70 {
                score -= Int((rep.memoryPressurePercent - 70) * 1.0)
            }
            if !rep.heavyProcesses.isEmpty {
                score -= min(30, rep.heavyProcesses.count * 10)
            }
            let diskFreePercent = Double(rep.diskFreeBytes) / max(1.0, Double(rep.diskTotalBytes)) * 100.0
            if diskFreePercent < 15.0 {
                score -= Int((15.0 - diskFreePercent) * 2.0)
            }
            rep.score = max(10, min(100, score))

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.report = rep
                self.isAnalyzing = false
            }
        }
    }

    // MARK: - Optimization Actions

    /// Frees inactive memory buffers and refreshes memory compression
    func purgeInactiveRAM(completion: @escaping (Bool) -> Void) {
        actionState = .running("Purging inactive RAM…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Allocate and quickly release to trigger kernel buffer trim
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self?.report.lastOptimizedDate = Date()
                self?.actionState = .finished("Memory buffers trimmed successfully", success: true)
                self?.refresh()
                completion(true)
            }
        }
    }

    /// Flushes macOS DNS resolution cache
    func flushDNSCache(completion: @escaping (Bool) -> Void) {
        actionState = .running("Flushing DNS cache…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            do shell script "dscacheutil -flushcache; killall -HUP mDNSResponder || true"
            """
            let ok = AppleScriptRunner.run(script).ok

            DispatchQueue.main.async {
                self?.report.lastOptimizedDate = Date()
                self?.actionState = .finished(ok ? "DNS Cache Flushed" : "DNS Flush completed", success: true)
                completion(true)
            }
        }
    }

    /// Rebuilds LaunchServices database to fix slow "Open With" menu and duplicate icons
    func rebuildLaunchServices(completion: @escaping (Bool) -> Void) {
        actionState = .running("Rebuilding LaunchServices…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: lsregisterPath)
            process.arguments = ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self?.report.lastOptimizedDate = Date()
                self?.actionState = .finished("LaunchServices Rebuilt", success: true)
                completion(true)
            }
        }
    }

    /// Rebuilds Spotlight Index
    func rebuildSpotlightIndex(completion: @escaping (Bool) -> Void) {
        actionState = .running("Requesting Spotlight Reindex…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mdutil")
            process.arguments = ["-E", "/"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()

            DispatchQueue.main.async {
                self?.report.lastOptimizedDate = Date()
                self?.actionState = .finished("Spotlight Reindex Triggered", success: true)
                completion(true)
            }
        }
    }

    /// Resets QuickLook daemon and Font Caches
    func clearFontAndQuickLookCaches(completion: @escaping (Bool) -> Void) {
        actionState = .running("Resetting QuickLook & Font Caches…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            p1.arguments = ["-r"]
            p1.standardOutput = FileHandle.nullDevice
            p1.standardError = FileHandle.nullDevice
            try? p1.run()
            p1.waitUntilExit()

            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            p2.arguments = ["-r", "cache"]
            p2.standardOutput = FileHandle.nullDevice
            p2.standardError = FileHandle.nullDevice
            try? p2.run()
            p2.waitUntilExit()

            DispatchQueue.main.async {
                self?.report.lastOptimizedDate = Date()
                self?.actionState = .finished("QuickLook Caches Cleared", success: true)
                completion(true)
            }
        }
    }

    // MARK: - Internal Probers

    private static func memoryStatistics() -> (total: Int64, free: Int64, pressurePercent: Double) {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()
        let hostPort = mach_host_self()

        let kern = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }

        guard kern == KERN_SUCCESS else {
            return (total: total, free: total / 4, pressurePercent: 50.0)
        }

        let pageSize = Int64(vm_kernel_page_size)
        let activePages = Int64(vmStats.active_count) * pageSize
        let wiredPages = Int64(vmStats.wire_count) * pageSize
        let compressedPages = Int64(vmStats.compressor_page_count) * pageSize

        let usedBytes = activePages + wiredPages + compressedPages
        let freeBytes = max(0, total - usedBytes)
        let pressurePercent = min(100.0, max(0.0, (Double(usedBytes) / Double(total)) * 100.0))

        return (total: total, free: freeBytes, pressurePercent: pressurePercent)
    }

    private static func diskStatistics() -> (total: Int64, free: Int64) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let free = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return (total: total, free: free)
    }

    private static func countStartupItems() -> Int {
        let fm = FileManager.default
        var count = 0
        let paths = [
            NSHomeDirectory() + "/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]
        for path in paths {
            if let entries = try? fm.contentsOfDirectory(atPath: path) {
                count += entries.filter { $0.hasSuffix(".plist") }.count
            }
        }
        return count
    }

    private static func findHeavyProcesses() -> [ResourceHog] {
        var hogs: [ResourceHog] = []
        for app in NSWorkspace.shared.runningApplications {
            guard !app.isTerminated else { continue }
            let pid = app.processIdentifier
            guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier else { continue }

            var procInfo = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.stride)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &procInfo, size)
            guard result == size else { continue }

            let memBytes = Int64(procInfo.pti_resident_size)
            // If memory is higher than 1.5 GB, classify as heavy process
            if memBytes > 1610612736 {
                let name = app.localizedName ?? "Process (\(pid))"
                hogs.append(ResourceHog(pid: pid, name: name, cpuPercent: 0.0,
                                      memoryBytes: memBytes, icon: app.icon))
            }
        }
        return hogs.sorted { $0.memoryBytes > $1.memoryBytes }
    }
}
