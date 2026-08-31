// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CommonCrypto
import Foundation

/// Fast scanner for identifying identical duplicate files and duplicate photos,
/// with multi-tier hashing (size grouping -> 4KB header sample -> full SHA256)
/// and safety mechanisms that always protect original copies.
final class DuplicateFinder: ObservableObject {
    static let shared = DuplicateFinder()

    enum Phase: Equatable {
        case idle
        case scanning(stage: String, progress: Double)
        case results
        case cleaning
        case done(freed: Int64, failed: Int)
    }

    enum FilterMode: String, CaseIterable, Identifiable {
        case allDuplicates, photosOnly, documentsOnly, mediaOnly

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .allDuplicates: return "doc.on.doc"
            case .photosOnly: return "photo.on.rectangle.angled"
            case .documentsOnly: return "doc.text"
            case .mediaOnly: return "film"
            }
        }
    }

    struct DuplicateItem: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let size: Int64
        let modifiedDate: Date
        let isPhoto: Bool
        var include: Bool

        var name: String { url.lastPathComponent }
        var path: String { url.path }

        static func == (lhs: DuplicateItem, rhs: DuplicateItem) -> Bool {
            lhs.id == rhs.id && lhs.include == rhs.include
        }
    }

    struct DuplicateGroup: Identifiable, Equatable {
        let id = UUID()
        let hash: String
        let size: Int64
        var items: [DuplicateItem]
        let isPhoto: Bool

        var sampleName: String { items.first?.name ?? "" }
        var selectedSize: Int64 {
            let count = items.filter(\.include).count
            return Int64(count) * size
        }

        static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
            lhs.id == rhs.id && lhs.items == rhs.items
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published var groups: [DuplicateGroup] = []
    @Published var filterMode: FilterMode = .allDuplicates
    @Published var selectedDirectory: URL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")

    private var scanToken = UUID()

    var filteredGroups: [DuplicateGroup] {
        switch filterMode {
        case .allDuplicates:
            return groups
        case .photosOnly:
            return groups.filter(\.isPhoto)
        case .documentsOnly:
            return groups.filter { group in
                let ext = (group.sampleName as NSString).pathExtension.lowercased()
                return ["pdf", "docx", "pptx", "xlsx", "pages", "keynote", "txt", "rtf", "md"].contains(ext)
            }
        case .mediaOnly:
            return groups.filter { group in
                let ext = (group.sampleName as NSString).pathExtension.lowercased()
                return ["mov", "mp4", "m4v", "mkv", "avi", "mp3", "m4a", "wav", "flac"].contains(ext)
            }
        }
    }

    var selectedCount: Int {
        groups.reduce(0) { $0 + $1.items.filter(\.include).count }
    }

    var selectedSize: Int64 {
        groups.reduce(0) { $0 + $1.selectedSize }
    }

    var totalWastedSize: Int64 {
        groups.reduce(0) { total, group in
            let extraCopies = max(0, group.items.count - 1)
            return total + (Int64(extraCopies) * group.size)
        }
    }

    private init() {}

    func reset() {
        scanToken = UUID()
        groups = []
        phase = .idle
    }

    // MARK: - Auto-Selection Helpers

    func autoSelectKeepNewest() {
        for gIdx in groups.indices {
            let sorted = groups[gIdx].items.sorted { $0.modifiedDate > $1.modifiedDate }
            guard let newestID = sorted.first?.id else { continue }
            for iIdx in groups[gIdx].items.indices {
                groups[gIdx].items[iIdx].include = (groups[gIdx].items[iIdx].id != newestID)
            }
        }
    }

    func autoSelectKeepOldest() {
        for gIdx in groups.indices {
            let sorted = groups[gIdx].items.sorted { $0.modifiedDate < $1.modifiedDate }
            guard let oldestID = sorted.first?.id else { continue }
            for iIdx in groups[gIdx].items.indices {
                groups[gIdx].items[iIdx].include = (groups[gIdx].items[iIdx].id != oldestID)
            }
        }
    }

    func autoSelectKeepPrimaryFolder() {
        for gIdx in groups.indices {
            // Keep the file whose path has fewest components or is not in Downloads/Desktop
            let sorted = groups[gIdx].items.sorted {
                let aScore = ($0.path.contains("/Downloads/") ? 10 : 0) + ($0.path.contains("/Desktop/") ? 5 : 0) + $0.url.pathComponents.count
                let bScore = ($1.path.contains("/Downloads/") ? 10 : 0) + ($1.path.contains("/Desktop/") ? 5 : 0) + $1.url.pathComponents.count
                return aScore < bScore
            }
            guard let primaryID = sorted.first?.id else { continue }
            for iIdx in groups[gIdx].items.indices {
                groups[gIdx].items[iIdx].include = (groups[gIdx].items[iIdx].id != primaryID)
            }
        }
    }

    func deselectAll() {
        for gIdx in groups.indices {
            for iIdx in groups[gIdx].items.indices {
                groups[gIdx].items[iIdx].include = false
            }
        }
    }

    func setInclude(_ include: Bool, forGroupID groupID: UUID, itemID: UUID) {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard let iIdx = groups[gIdx].items.firstIndex(where: { $0.id == itemID }) else { return }

        if include {
            // Guarantee at least 1 copy remains unselected
            let otherSelected = groups[gIdx].items.filter { $0.id != itemID && $0.include }.count
            if otherSelected + 1 >= groups[gIdx].items.count {
                return // Cannot select all copies in a group
            }
        }
        groups[gIdx].items[iIdx].include = include
    }

    // MARK: - Scan Pipeline

    func scan(directory: URL? = nil) {
        guard phase != .cleaning else { return }
        let targetURL = directory ?? selectedDirectory
        selectedDirectory = targetURL
        let token = UUID()
        scanToken = token
        groups = []
        phase = .scanning(stage: "Collecting files…", progress: 0.0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default

            // 1. Traverse directory and group by exact file size
            var filesBySize: [Int64: [URL]] = [:]
            let keys: [URLResourceKey] = [
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey,
                .isPackageKey,
                .isSymbolicLinkKey,
            ]

            guard let enumerator = fm.enumerator(at: targetURL,
                                                 includingPropertiesForKeys: keys,
                                                 options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                                 errorHandler: { _, _ in true }) else {
                DispatchQueue.main.async { self?.phase = .results }
                return
            }

            for case let fileURL as URL in enumerator {
                guard let self, self.scanToken == token else { return }
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
                if values.isSymbolicLink == true { continue }
                if (values.isDirectory ?? false) && !(values.isPackage ?? false) {
                    let path = fileURL.path
                    if path.contains("/Library/Caches") || path.contains("/.Trash") {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                // Only consider files larger than 100 KB for duplicate hashing
                guard size >= 102400 else { continue }
                filesBySize[size, default: []].append(fileURL)
            }

            // Filter sizes that have 2 or more files
            let candidates = filesBySize.filter { $0.value.count >= 2 }
            guard !candidates.isEmpty else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.scanToken == token else { return }
                    self.phase = .results
                }
                return
            }

            // 2. Sample 4KB Header Hash for quick mismatch elimination
            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.phase = .scanning(stage: "Analyzing candidates…", progress: 0.3)
            }

            var headerGroups: [String: [URL]] = [:]
            for (size, urls) in candidates {
                for url in urls {
                    guard let self, self.scanToken == token else { return }
                    let sampleHash = Self.sampleHash(url: url, size: size)
                    headerGroups[sampleHash, default: []].append(url)
                }
            }

            let survivingHeaders = headerGroups.filter { $0.value.count >= 2 }

            // 3. Full SHA-256 Hash on remaining identical candidates
            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.phase = .scanning(stage: "Hashing matching files…", progress: 0.7)
            }

            var fullHashGroups: [String: [(url: URL, size: Int64, modDate: Date, isPhoto: Bool)]] = [:]
            for (_, urls) in survivingHeaders {
                for url in urls {
                    guard let self, self.scanToken == token else { return }
                    guard let hash = Self.fullSHA256(url: url) else { continue }
                    let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey])
                    let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                    let modDate = values?.contentModificationDate ?? Date()
                    let isPhoto = Self.isPhotoExtension(url.pathExtension)
                    fullHashGroups[hash, default: []].append((url, size, modDate, isPhoto))
                }
            }

            var resultGroups: [DuplicateGroup] = []
            for (hash, items) in fullHashGroups where items.count >= 2 {
                let size = items.first?.size ?? 0
                let isPhoto = items.contains(where: \.isPhoto)
                let dupItems = items.enumerated().map { index, item in
                    // Default to selecting all but the first item
                    DuplicateItem(url: item.url, size: item.size,
                                  modifiedDate: item.modDate, isPhoto: item.isPhoto,
                                  include: (index > 0))
                }
                resultGroups.append(DuplicateGroup(hash: hash, size: size, items: dupItems, isPhoto: isPhoto))
            }

            resultGroups.sort { $0.size * Int64($0.items.count) > $1.size * Int64($1.items.count) }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.groups = resultGroups
                self.phase = .results
            }
        }
    }

    // MARK: - Hashing

    private static func sampleHash(url: URL, size: Int64) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return "\(size)-\(url.path)"
        }
        defer { try? handle.close() }
        let headerData = (try? handle.read(upToCount: 4096)) ?? Data()
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        headerData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(headerData.count), &digest)
        }
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(size)-\(hex)"
    }

    private static func fullSHA256(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        let bufferSize = 65536
        while let data = try? handle.read(upToCount: bufferSize), !data.isEmpty {
            data.withUnsafeBytes {
                _ = CC_SHA256_Update(&context, $0.baseAddress, CC_LONG(data.count))
            }
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func isPhotoExtension(_ ext: String) -> Bool {
        let lowered = ext.lowercased()
        return ["jpg", "jpeg", "png", "heic", "tiff", "tif", "raw", "cr2", "nef", "dng", "gif", "webp"].contains(lowered)
    }

    // MARK: - Clean

    func cleanSelected() {
        var toRemove: [DuplicateItem] = []
        for group in groups {
            let selected = group.items.filter(\.include)
            // Double check safety: never delete all items in a group
            if selected.count < group.items.count {
                toRemove.append(contentsOf: selected)
            }
        }
        guard !toRemove.isEmpty else { return }
        phase = .cleaning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var freed: Int64 = 0
            var failed = 0
            var deletedIDs = Set<UUID>()

            for item in toRemove {
                do {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    freed += item.size
                    deletedIDs.insert(item.id)
                } catch {
                    failed += 1
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.phase == .cleaning else { return }
                for gIdx in self.groups.indices {
                    self.groups[gIdx].items.removeAll { deletedIDs.contains($0.id) }
                }
                self.groups.removeAll { $0.items.count <= 1 }
                self.phase = .done(freed: freed, failed: failed)
            }
        }
    }
}
