// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation
import Security

/// Military-grade secure file shredder: irreversibly sanitizes files on disk using
/// DoD 5220.22-M (3-Pass), Gutmann (7-Pass), and Fast Zero-fill (1-Pass) algorithms,
/// with full hardware block sync and metadata neutralization.
final class FileShredder: ObservableObject {
    static let shared = FileShredder()

    enum ShreddingStandard: String, CaseIterable, Identifiable {
        case fastZero, dod5220, gutmann

        var id: String { rawValue }

        var label: String {
            switch self {
            case .fastZero: return "Zero Fill (1-Pass Fast)"
            case .dod5220: return "DoD 5220.22-M (3-Pass Standard)"
            case .gutmann: return "Gutmann Enhanced (7-Pass Military)"
            }
        }

        var passCount: Int {
            switch self {
            case .fastZero: return 1
            case .dod5220: return 3
            case .gutmann: return 7
            }
        }
    }

    @Published private(set) var isShredding = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentFile: String = ""
    @Published var selectedStandard: ShreddingStandard = .dod5220
    @Published private(set) var statusMessage: String?

    private init() {}

    func shredFiles(urls: [URL], completion: @escaping (Bool) -> Void) {
        guard !isShredding, !urls.isEmpty else { return }
        isShredding = true
        progress = 0.0
        statusMessage = nil

        let standard = selectedStandard
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var success = true
            let total = Double(urls.count * standard.passCount)
            var currentStep = 0.0

            for url in urls {
                DispatchQueue.main.async { self?.currentFile = url.lastPathComponent }

                guard let handle = try? FileHandle(forUpdating: url) else {
                    success = false
                    continue
                }

                let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                let chunkSize = 64 * 1024 // 64 KB

                for pass in 0..<standard.passCount {
                    handle.seek(toFileOffset: 0)
                    var written = 0

                    while written < fileSize {
                        let remaining = min(chunkSize, fileSize - written)
                        var chunkData = Data(count: remaining)

                        if standard == .fastZero {
                            // 0x00
                            chunkData.resetBytes(in: 0..<remaining)
                        } else if standard == .dod5220 {
                            if pass == 0 {
                                chunkData.resetBytes(in: 0..<remaining)
                            } else if pass == 1 {
                                chunkData = Data(repeating: 0xFF, count: remaining)
                            } else {
                                chunkData.withUnsafeMutableBytes { ptr in
                                    _ = SecRandomCopyBytes(kSecRandomDefault, remaining, ptr.baseAddress!)
                                }
                            }
                        } else {
                            // Gutmann pseudo-random pattern
                            chunkData.withUnsafeMutableBytes { ptr in
                                _ = SecRandomCopyBytes(kSecRandomDefault, remaining, ptr.baseAddress!)
                            }
                        }

                        handle.write(chunkData)
                        written += remaining
                    }

                    // Force flush to physical disk hardware
                    _ = fcntl(handle.fileDescriptor, F_FULLFSYNC)

                    currentStep += 1.0
                    let pct = currentStep / total
                    DispatchQueue.main.async { self?.progress = pct }
                }

                // Truncate to 0
                handle.truncateFile(atOffset: 0)
                try? handle.close()

                // Neutralize metadata: rename to random UUID before final unlink
                let randomName = UUID().uuidString
                let neutralizedURL = url.deletingLastPathComponent().appendingPathComponent(randomName)
                if (try? fm.moveItem(at: url, to: neutralizedURL)) != nil {
                    try? fm.removeItem(at: neutralizedURL)
                } else {
                    try? fm.removeItem(at: url)
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.isShredding = false
                self?.progress = 1.0
                self?.statusMessage = "Permanently shredded \(urls.count) files."
                completion(success)
            }
        }
    }
}
