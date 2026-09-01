// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

struct DNSServerPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let primary: String
    let secondary: String
    let description: String
    var latencyMs: Double?
}

final class DNSOptimizerService: ObservableObject {
    static let shared = DNSOptimizerService()

    @Published private(set) var presets: [DNSServerPreset] = [
        DNSServerPreset(id: "cloudflare", name: "Cloudflare 1.1.1.1", primary: "1.1.1.1", secondary: "1.0.0.1", description: "Ultra-rápido, foco em privacidade e sem registro de IPs."),
        DNSServerPreset(id: "google", name: "Google Public DNS", primary: "8.8.8.8", secondary: "8.8.4.4", description: "Alta confiabilidade global e resolução rápida de domínios."),
        DNSServerPreset(id: "quad9", name: "Quad9 Secure", primary: "9.9.9.9", secondary: "149.112.112.112", description: "Bloqueio automático de domínios maliciosos e phishing."),
        DNSServerPreset(id: "adguard", name: "AdGuard DNS", primary: "94.140.14.14", secondary: "94.140.15.15", description: "Filtro nativo contra anúncios, rastreadores e malware."),
        DNSServerPreset(id: "default", name: "Padrão do Provedor (DHCP)", primary: "empty", secondary: "empty", description: "Restaura os servidores DNS automáticos da sua rede local.")
    ]
    @Published private(set) var isTesting = false
    @Published private(set) var isApplying = false
    @Published private(set) var currentActiveDNS = "Automático (DHCP)"

    private init() {
        benchmarkAll()
    }

    func benchmarkAll() {
        guard !isTesting else { return }
        isTesting = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var updated = self.presets

            for i in updated.indices {
                let ip = updated[i].primary
                if ip == "empty" {
                    updated[i].latencyMs = 1.0
                    continue
                }
                let ms = Self.ping(host: ip)
                updated[i].latencyMs = ms
            }

            DispatchQueue.main.async {
                self.presets = updated
                self.isTesting = false
            }
        }
    }

    func applyPreset(_ preset: DNSServerPreset, completion: @escaping (Bool) -> Void) {
        guard !isApplying else { completion(false); return }
        isApplying = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let netInterface = Self.getActiveNetworkService() ?? "Wi-Fi"
            let script: String

            if preset.primary == "empty" {
                script = "do shell script \"networksetup -setdnsservers '\(netInterface)' empty; dscacheutil -flushcache\" with administrator privileges"
            } else {
                script = "do shell script \"networksetup -setdnsservers '\(netInterface)' \(preset.primary) \(preset.secondary); dscacheutil -flushcache\" with administrator privileges"
            }

            var err: NSDictionary?
            let ok = NSAppleScript(source: script)?.executeAndReturnError(&err) != nil

            DispatchQueue.main.async {
                self?.isApplying = false
                if ok {
                    self?.currentActiveDNS = preset.name
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
                completion(ok)
            }
        }
    }

    private static func getActiveNetworkService() -> String? {
        let res = Shell.run("/usr/sbin/networksetup", ["-listallnetworkservices"])
        let lines = res.output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("Wi-Fi") || trimmed.contains("Ethernet") {
                return trimmed
            }
        }
        return "Wi-Fi"
    }

    private static func ping(host: String) -> Double {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "2", "-W", "1000", host]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let start = CFAbsoluteTimeGetCurrent()
        try? process.run()
        process.waitUntilExit()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8),
               let avgRange = str.range(of: "min/avg/max/stddev = ") {
                let tail = str[avgRange.upperBound...]
                let parts = tail.components(separatedBy: "/")
                if parts.count >= 2, let avg = Double(parts[1]) {
                    return avg
                }
            }
            return max(5.0, elapsed / 2.0)
        }
        return 999.0
    }
}
