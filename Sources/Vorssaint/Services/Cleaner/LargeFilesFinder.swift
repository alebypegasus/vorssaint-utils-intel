// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Fast scanner for identifying large files and folders on disk, allowing
/// the user to review, sort by size or age, preview with QuickLook, and safely
/// move unwanted items to the Trash.
final class LargeFilesFinder: ObservableObject {
    static let shared = LargeFilesFinder()

    enum Phase: Equatable {
        case idle
        case scanning(scanned: Int)
        case results
        case cleaning
        case done(freed: Int64, failed: Int)
    }

    enum FileKind: String, CaseIterable, Identifiable {
        case all, videos, archives, documents, images, audio, other

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "square.stack.3d.up"
            case .videos: return "film"
            case .archives: return "archivebox"
            case .documents: return "doc.text"
            case .images: return "photo"
            case .audio: return "music.note"
            case .other: return "questionmark.folder"
            }
        }
    }

    enum SizeFilter: Int64, CaseIterable, Identifiable {
        case size50MB = 52428800
        case size100MB = 104857600
        case size500MB = 524288000
        case size1GB = 1073741824
        case size5GB = 5368709120

        var id: Int64 { rawValue }

        var label: String {
            switch self {
            case .size50MB: return "> 50 MB"
            case .size100MB: return "> 100 MB"
            case .size500MB: return "> 500 MB"
            case .size1GB: return "> 1 GB"
            case .size5GB: return "> 5 GB"
            }
        }
    }

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let size: Int64
        let kind: FileKind
        let modifiedDate: Date
        let isDirectory: Bool
        var include: Bool

        var name: String { url.lastPathComponent }
        var path: String { url.path }

        init(url: URL, size: Int64, kind: FileKind, modifiedDate: Date, isDirectory: Bool, include: Bool = false) {
            self.url = url
            self.size = size
            self.kind = kind
            self.modifiedDate = modifiedDate
            self.isDirectory = isDirectory
            self.include = include
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.id == rhs.id && lhs.include == rhs.include
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published var items: [Item] = []
    @Published var selectedKind: FileKind = .all
    @Published var minSize: SizeFilter = .size100MB
    @Published var selectedDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())

    private var scanToken = UUID()

    var selectedCount: Int { items.filter(\.include).count }
    var selectedSize: Int64 { items.filter(\.include).reduce(0) { $0 + $1.size } }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    var filteredItems: [Item] {
        items.filter { item in
            (selectedKind == .all || item.kind == selectedKind) && item.size >= minSize.rawValue
        }
    }

    private init() {}

    func reset() {
        scanToken = UUID()
        items = []
        phase = .idle
    }

    func setInclude(_ include: Bool, for id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].include = include
        }
    }

    func selectAllFiltered(_ select: Bool) {
        let currentFilteredIDs = Set(filteredItems.map(\.id))
        for idx in items.indices {
            if currentFilteredIDs.contains(items[idx].id) {
                items[idx].include = select
            }
        }
    }

    // MARK: - Scan

    func scan(directory: URL? = nil) {
        guard phase != .cleaning else { return }
        let targetURL = directory ?? selectedDirectory
        selectedDirectory = targetURL
        let token = UUID()
        scanToken = token
        items = []
        phase = .scanning(scanned: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var found: [Item] = []
            var scannedCount = 0

            let keys: [URLResourceKey] = [
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey,
                .isPackageKey,
                .isSymbolicLinkKey,
            ]

            let options: FileManager.DirectoryEnumerationOptions = [
                .skipsHiddenFiles,
                .skipsPackageDescendants,
            ]

            guard let enumerator = fm.enumerator(at: targetURL,
                                                 includingPropertiesForKeys: keys,
                                                 options: options,
                                                 errorHandler: { _, _ in true }) else {
                DispatchQueue.main.async {
                    self?.phase = .results
                }
                return
            }

            for case let fileURL as URL in enumerator {
                guard let self, self.scanToken == token else { return }
                scannedCount += 1
                if scannedCount % 500 == 0 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.scanToken == token else { return }
                        self.phase = .scanning(scanned: scannedCount)
                    }
                }

                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
                if values.isSymbolicLink == true { continue }

                let isDir = values.isDirectory ?? false
                let isPackage = values.isPackage ?? false

                // We evaluate individual files and application packages (.app, .bundle)
                if isDir && !isPackage {
                    // Do not descend into Library caches or deep application support during large file search
                    let path = fileURL.path
                    if path.contains("/Library/Caches") || path.contains("/.Trash") {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                // Filter only files above minimum 20MB during scan
                guard size >= 20971520 else { continue }

                let modDate = values.contentModificationDate ?? Date()
                let kind = Self.classify(url: fileURL)

                found.append(Item(url: fileURL, size: size, kind: kind,
                                  modifiedDate: modDate, isDirectory: isDir || isPackage))
            }

            let sortedFound = found.sorted { $0.size > $1.size }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.scanToken == token else { return }
                self.items = sortedFound
                self.phase = .results
            }
        }
    }

    // MARK: - Classification

    private static func classify(url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mov", "mp4", "m4v", "mkv", "avi", "wmv", "flv", "webm", "mpeg", "mpg":
            return .videos
        case "zip", "dmg", "iso", "tar", "gz", "tgz", "bz2", "7z", "rar", "pkg", "ipa":
            return .archives
        case "pdf", "docx", "pptx", "xlsx", "pages", "keynote", "numbers", "sqlite", "db", "csv", "sql", "dump":
            return .documents
        case "jpg", "jpeg", "png", "heic", "tiff", "tif", "psd", "ai", "raw", "cr2", "nef", "dng", "gif", "webp":
            return .images
        case "mp3", "m4a", "wav", "flac", "aac", "aiff", "ogg", "wma":
            return .audio
        default:
            return .other
        }
    }

    // MARK: - Clean

    func cleanSelected() {
        let chosen = items.filter(\.include)
        guard !chosen.isEmpty else { return }
        phase = .cleaning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var freed: Int64 = 0
            var failed = 0

            for item in chosen {
                guard Self.mayRemove(item.url) else {
                    failed += 1
                    continue
                }
                do {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    freed += item.size
                } catch {
                    failed += 1
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.phase == .cleaning else { return }
                self.items.removeAll { chosenIDs in chosen.contains { $0.id == chosenIDs.id } }
                self.phase = .done(freed: freed, failed: failed)
            }
        }
    }

    private static func mayRemove(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = NSHomeDirectory()
        let critical: Set<String> = [
            "/", "/Applications", "/Library", "/System", "/Users", "/usr",
            "/bin", "/sbin", "/etc", "/var", "/private", "/opt",
            home, home + "/Library", home + "/Documents", home + "/Desktop",
            home + "/Downloads", home + "/Pictures", home + "/Music", home + "/Movies",
        ]
        return !critical.contains(path) && url.pathComponents.count >= 3
    }
}
