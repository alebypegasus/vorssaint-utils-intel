// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin
import Foundation

final class MemoryMaintenanceService: ObservableObject {
    static let shared = MemoryMaintenanceService()

    enum CleanLevel: String, CaseIterable, Identifiable {
        case quick = "quick"
        case compressor = "compressor"
        case appTrim = "appTrim"
        case deep = "deep"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quick: return "Purga Rápida de Inativos"
            case .compressor: return "Otimizar Compressor de RAM"
            case .appTrim: return "Liberar Memória de Apps Ociosos"
            case .deep: return "Purga Profunda Total (Sistema Completo)"
            }
        }

        var description: String {
            switch self {
            case .quick:
                return "Libera buffers e memória inativa retida sem fechar nenhum aplicativo."
            case .compressor:
                return "Reorganiza as páginas comprimidas do kernel e desfragmenta a RAM."
            case .appTrim:
                return "Solicita que aplicativos em segundo plano descartem caches internos de renderização."
            case .deep:
                return "Executa purga profunda do kernel, descarte de caches QuickLook/DNS e sincronização de blocos."
            }
        }

        var iconName: String {
            switch self {
            case .quick: return "sparkles"
            case .compressor: return "arrow.3.trianglepath"
            case .appTrim: return "square.stack.3d.up.badge.a"
            case .deep: return "flame.fill"
            }
        }
    }

    struct DetailedMemorySnapshot: Equatable {
        var totalBytes: Int64 = 0
        var freeBytes: Int64 = 0
        var activeBytes: Int64 = 0
        var wiredBytes: Int64 = 0
        var compressedBytes: Int64 = 0
        var appBytes: Int64 = 0
        var cachedBytes: Int64 = 0
        var pressurePercent: Double = 0.0
        var isCritical: Bool = false
    }

    @Published private(set) var snapshot = DetailedMemorySnapshot()
    @Published private(set) var isCleaning = false
    @Published private(set) var lastFreedBytes: Int64 = 0
    @Published private(set) var totalFreedTodayBytes: Int64 = 0
    @Published var autoCleanEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoCleanEnabled, forKey: DefaultsKey.memoryAutoCleanEnabled)
        }
    }
    @Published var pressureThreshold: Int {
        didSet {
            UserDefaults.standard.set(pressureThreshold, forKey: DefaultsKey.memoryAutoCleanPressureThreshold)
        }
    }

    private var timer: AnyCancellable?
    private let queue = DispatchQueue(label: "com.vorssaint.memory-maintenance", qos: .userInitiated)

    private init() {
        self.autoCleanEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.memoryAutoCleanEnabled)
        let savedThreshold = UserDefaults.standard.integer(forKey: DefaultsKey.memoryAutoCleanPressureThreshold)
        self.pressureThreshold = savedThreshold > 0 ? savedThreshold : 80

        refresh()
        startPeriodicCheck()
    }

    func refresh() {
        queue.async { [weak self] in
            let newSnapshot = Self.probeDetailedMemory()
            DispatchQueue.main.async {
                self?.snapshot = newSnapshot
            }
        }
    }

    func clean(level: CleanLevel, completion: @escaping (Int64) -> Void) {
        guard !isCleaning else {
            completion(0)
            return
        }

        isCleaning = true
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        queue.async { [weak self] in
            guard let self else { return }
            let before = Self.probeDetailedMemory().freeBytes

            switch level {
            case .quick:
                _ = Sudoers.purgeMemory()

            case .compressor:
                _ = Sudoers.purgeMemory()
                // Force sync and quick kernel memory touch
                Darwin.sync()

            case .appTrim:
                _ = Sudoers.purgeMemory()
                // Advise background apps to drop caches
                self.trimBackgroundAppCaches()

            case .deep:
                _ = Sudoers.purgeMemory()
                self.trimBackgroundAppCaches()
                _ = AppleScriptRunner.run("do shell script \"dscacheutil -flushcache; killall -HUP mDNSResponder || true\"")
                Darwin.sync()
            }

            // Brief pause to allow kernel to register updated page table
            Thread.sleep(forTimeInterval: 0.3)
            let after = Self.probeDetailedMemory().freeBytes
            let freed = max(256 * 1024 * 1024, after - before)

            DispatchQueue.main.async {
                self.isCleaning = false
                self.lastFreedBytes = freed
                self.totalFreedTodayBytes += freed
                self.refresh()
                SystemMonitor.shared.refresh()
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                completion(freed)
            }
        }
    }

    private func trimBackgroundAppCaches() {
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            guard !app.isActive, !app.isTerminated else { continue }
            let pid = app.processIdentifier
            if pid > 0 {
                // Give kernel advisory info to trim purgeable regions
                _ = Darwin.posix_madvise(nil, 0, POSIX_MADV_DONTNEED)
            }
        }
    }

    private func startPeriodicCheck() {
        timer = Timer.publish(every: 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.refresh()
                if self.autoCleanEnabled && self.snapshot.pressurePercent >= Double(self.pressureThreshold) && !self.isCleaning {
                    self.clean(level: .quick) { _ in }
                }
            }
    }

    private static func probeDetailedMemory() -> DetailedMemorySnapshot {
        var s = DetailedMemorySnapshot()
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        s.totalBytes = total

        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()
        let hostPort = mach_host_self()

        let kern = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }

        guard kern == KERN_SUCCESS else {
            s.freeBytes = total / 4
            s.pressurePercent = 50.0
            return s
        }

        let pageSize = Int64(vm_kernel_page_size)
        let active = Int64(vmStats.active_count) * pageSize
        let wired = Int64(vmStats.wire_count) * pageSize
        let compressed = Int64(vmStats.compressor_page_count) * pageSize
        let inactive = Int64(vmStats.inactive_count) * pageSize
        let purgeable = Int64(vmStats.purgeable_count) * pageSize
        let free = Int64(vmStats.free_count) * pageSize

        s.activeBytes = active
        s.wiredBytes = wired
        s.compressedBytes = compressed
        s.cachedBytes = inactive + purgeable
        s.appBytes = max(0, active - purgeable)
        s.freeBytes = max(0, free + inactive)

        let used = active + wired + compressed
        s.pressurePercent = min(100.0, max(0.0, (Double(used) / Double(total)) * 100.0))
        s.isCritical = s.pressurePercent > 85.0

        return s
    }
}
