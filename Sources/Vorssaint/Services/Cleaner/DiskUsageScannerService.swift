// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation
import QuickLookUI
import SwiftUI

enum DiskFileCategory: String, CaseIterable, Identifiable {
    case apps = "Aplicativos"
    case developer = "Desenvolvimento"
    case media = "Mídia & Vídeos"
    case documents = "Documentos"
    case archives = "Instaladores & Zips"
    case caches = "Caches & Temporários"
    case other = "Outros Arquivos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .apps: return "app.badge.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .media: return "play.rectangle.fill"
        case .documents: return "doc.fill"
        case .archives: return "archivebox.fill"
        case .caches: return "trash.fill"
        case .other: return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .apps: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .developer: return Color(red: 0.15, green: 0.85, blue: 0.55)
        case .media: return Color(red: 1.0, green: 0.35, blue: 0.65)
        case .documents: return Color(red: 1.0, green: 0.7, blue: 0.2)
        case .archives: return Color(red: 0.7, green: 0.4, blue: 1.0)
        case .caches: return Color(red: 1.0, green: 0.4, blue: 0.4)
        case .other: return Color(white: 0.55)
        }
    }
}

final class DiskNode: Identifiable, ObservableObject, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    var size: Int64
    var category: DiskFileCategory
    var children: [DiskNode]
    var percentage: Double
    var itemCount: Int

    init(url: URL, name: String, isDirectory: Bool, size: Int64, category: DiskFileCategory, children: [DiskNode] = [], percentage: Double = 0.0, itemCount: Int = 1) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.category = category
        self.children = children
        self.percentage = percentage
        self.itemCount = itemCount
    }

    static func == (lhs: DiskNode, rhs: DiskNode) -> Bool {
        lhs.id == rhs.id && lhs.size == rhs.size
    }
}

final class DiskUsageScannerService: ObservableObject {
    static let shared = DiskUsageScannerService()

    @Published private(set) var rootNode: DiskNode?
    @Published private(set) var currentNode: DiskNode?
    @Published private(set) var breadcrumbs: [DiskNode] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedFilesCount = 0
    @Published var selectedTargetURL: URL = URL(fileURLWithPath: NSHomeDirectory())

    private var scanToken = UUID()

    private init() {}

    func scan(url: URL? = nil) {
        let target = url ?? selectedTargetURL
        selectedTargetURL = target
        isScanning = true
        scannedFilesCount = 0
        let token = UUID()
        scanToken = token

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let root = self.buildTree(for: target, token: token, maxDepth: 2)

            DispatchQueue.main.async {
                guard self.scanToken == token else { return }
                self.rootNode = root
                self.currentNode = root
                self.breadcrumbs = [root]
                self.isScanning = false
            }
        }
    }

    func navigateInto(node: DiskNode) {
        guard node.isDirectory else { return }
        currentNode = node
        if !breadcrumbs.contains(where: { $0.id == node.id }) {
            breadcrumbs.append(node)
        }
    }

    func navigateBack(to index: Int) {
        guard index >= 0, index < breadcrumbs.count else { return }
        let target = breadcrumbs[index]
        breadcrumbs = Array(breadcrumbs.prefix(index + 1))
        currentNode = target
    }

    func revealInFinder(node: DiskNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    func trashItem(node: DiskNode, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            do {
                try fm.trashItem(at: node.url, resultingItemURL: nil)
                DispatchQueue.main.async {
                    self?.removeNodeFromTree(node)
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    func deletePermanently(node: DiskNode, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            do {
                try fm.removeItem(at: node.url)
                DispatchQueue.main.async {
                    self?.removeNodeFromTree(node)
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    private func removeNodeFromTree(_ node: DiskNode) {
        if let current = currentNode {
            current.children.removeAll { $0.id == node.id }
            current.size = current.children.reduce(0) { $0 + $1.size }
            for child in current.children {
                child.percentage = current.size > 0 ? (Double(child.size) / Double(current.size)) * 100.0 : 0
            }
            objectWillChange.send()
        }
    }

    // MARK: - Tree Builder

    private func buildTree(for directoryURL: URL, token: UUID, maxDepth: Int) -> DiskNode {
        let fm = FileManager.default
        let name = directoryURL.lastPathComponent.isEmpty ? directoryURL.path : directoryURL.lastPathComponent

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue else {
            let size = (try? directoryURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return DiskNode(url: directoryURL, name: name, isDirectory: false, size: Int64(size),
                            category: Self.categorize(url: directoryURL))
        }

        var directChildren: [DiskNode] = []
        let keys: [URLResourceKey] = [
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .isDirectoryKey,
            .isPackageKey
        ]

        if let contents = try? fm.contentsOfDirectory(at: directoryURL,
                                                      includingPropertiesForKeys: keys,
                                                      options: [.skipsHiddenFiles]) {
            for itemURL in contents {
                guard scanToken == token else { break }
                scannedFilesCount += 1

                let vals = try? itemURL.resourceValues(forKeys: Set(keys))
                let isChildDir = vals?.isDirectory ?? false
                let isPkg = vals?.isPackage ?? false

                if isPkg || !isChildDir {
                    let size = Int64(vals?.totalFileAllocatedSize ?? vals?.fileAllocatedSize ?? 0)
                    let cat = Self.categorize(url: itemURL)
                    directChildren.append(DiskNode(url: itemURL, name: itemURL.lastPathComponent,
                                                   isDirectory: false, size: size, category: cat))
                } else if maxDepth > 0 {
                    let subTree = buildTree(for: itemURL, token: token, maxDepth: maxDepth - 1)
                    directChildren.append(subTree)
                } else {
                    let size = calculateShallowSize(for: itemURL)
                    let cat = Self.categorize(url: itemURL)
                    directChildren.append(DiskNode(url: itemURL, name: itemURL.lastPathComponent,
                                                   isDirectory: true, size: size, category: cat))
                }
            }
        }

        directChildren.sort { $0.size > $1.size }
        let totalSize = directChildren.reduce(0) { $0 + $1.size }

        for child in directChildren {
            child.percentage = totalSize > 0 ? (Double(child.size) / Double(totalSize)) * 100.0 : 0.0
        }

        return DiskNode(url: directoryURL, name: name, isDirectory: true, size: totalSize,
                        category: Self.categorize(url: directoryURL), children: directChildren,
                        percentage: 100.0, itemCount: directChildren.count)
    }

    private func calculateShallowSize(for url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url,
                                             includingPropertiesForKeys: [.fileAllocatedSizeKey],
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        var total: Int64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 400 { break } // Quick shallow limit
            if let size = (try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey]))?.fileAllocatedSize {
                total += Int64(size)
            }
        }
        return total
    }

    static func categorize(url: URL) -> DiskFileCategory {
        let path = url.path.lowercased()
        let ext = url.pathExtension.lowercased()

        if path.contains("node_modules") || path.contains(".git") || path.contains("pods") || path.contains("deriveddata") || ext == "swift" || ext == "ts" || ext == "js" || ext == "py" || ext == "rs" || ext == "go" || ext == "cpp" {
            return .developer
        }
        if ext == "app" || path.contains("/applications") {
            return .apps
        }
        if ["mov", "mp4", "mkv", "avi", "flac", "wav", "mp3", "m4a", "png", "jpg", "jpeg", "heic", "webp", "gif"].contains(ext) {
            return .media
        }
        if ["zip", "dmg", "tar", "gz", "7z", "rar", "pkg", "iso"].contains(ext) {
            return .archives
        }
        if path.contains("/caches") || path.contains("/logs") || ext == "log" || ext == "tmp" {
            return .caches
        }
        if ["pdf", "doc", "docx", "pages", "numbers", "key", "txt", "md", "csv", "xlsx", "pptx"].contains(ext) {
            return .documents
        }
        return .other
    }
}
