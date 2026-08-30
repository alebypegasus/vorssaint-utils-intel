// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Network
import Combine

/// Real-time network latency, jitter, and connection quality monitor.
final class NetworkPulseService: ObservableObject {
    static let shared = NetworkPulseService()

    @Published private(set) var currentPingMs: Double = 0.0
    @Published private(set) var averagePingMs: Double = 0.0
    @Published private(set) var jitterMs: Double = 0.0
    @Published private(set) var packetLossPercent: Double = 0.0
    @Published private(set) var isMeasuring: Bool = false
    @Published private(set) var history: [Double] = []

    private var pingHistory: [Double] = []
    private var timer: AnyCancellable?
    private let maxHistory = 20
    private var failedPings = 0
    private var totalPings = 0

    private init() {
        start()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.measurePulse()
            }
        measurePulse()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Performs a non-blocking TCP socket latency check against Cloudflare DNS (1.1.1.1:53).
    func measurePulse() {
        guard !isMeasuring else { return }
        isMeasuring = true

        let startTime = CFAbsoluteTimeGetCurrent()
        let endpoint = NWEndpoint.hostPort(host: "1.1.1.1", port: 53)
        let parameters = NWParameters.tcp
        parameters.prohibitedInterfaceTypes = []

        let connection = NWConnection(to: endpoint, using: parameters)
        let queue = DispatchQueue(label: "com.vorssaint.utils.network-pulse", qos: .utility)

        var completed = false
        let timeoutWorkItem = DispatchWorkItem { [weak self, weak connection] in
            if !completed {
                completed = true
                connection?.cancel()
                DispatchQueue.main.async {
                    self?.recordResult(pingMs: nil)
                }
            }
        }

        queue.asyncAfter(deadline: .now() + 2.5, execute: timeoutWorkItem)

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .ready:
                if !completed {
                    completed = true
                    timeoutWorkItem.cancel()
                    let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    connection?.cancel()
                    DispatchQueue.main.async {
                        self?.recordResult(pingMs: elapsedMs)
                    }
                }
            case .failed, .cancelled:
                if !completed {
                    completed = true
                    timeoutWorkItem.cancel()
                    DispatchQueue.main.async {
                        self?.recordResult(pingMs: nil)
                    }
                }
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func recordResult(pingMs: Double?) {
        isMeasuring = false
        totalPings += 1

        if let ms = pingMs, ms > 0.1, ms < 2500.0 {
            currentPingMs = round(ms * 10) / 10
            pingHistory.append(currentPingMs)
            if pingHistory.count > maxHistory {
                pingHistory.removeFirst()
            }

            // Calculate moving average
            let sum = pingHistory.reduce(0.0, +)
            averagePingMs = round((sum / Double(pingHistory.count)) * 10) / 10

            // Calculate jitter (mean absolute deviation between consecutive pings)
            if pingHistory.count >= 2 {
                var totalDiff = 0.0
                for i in 1..<pingHistory.count {
                    totalDiff += abs(pingHistory[i] - pingHistory[i - 1])
                }
                jitterMs = round((totalDiff / Double(pingHistory.count - 1)) * 10) / 10
            } else {
                jitterMs = 0.0
            }

            history = pingHistory
        } else {
            failedPings += 1
        }

        if totalPings > 0 {
            packetLossPercent = round((Double(failedPings) / Double(totalPings) * 100.0) * 10) / 10
        }
    }
}
