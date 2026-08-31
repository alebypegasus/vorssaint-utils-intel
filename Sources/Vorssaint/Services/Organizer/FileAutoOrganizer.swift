// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Desktop & Downloads Auto-Organizer: organizes loose files into categorized subfolders
/// with full Undo support to restore previous file locations.
final class FileAutoOrganizer: ObservableObject {
    static let shared = FileAutoOrganizer()

    enum TargetFolder: String, CaseIterable, Identifiable {
        case desktop, downloads

        var id: String { rawValue }

        var label: String {
            switch self {
            case .desktop: return "Desktop"
            case .downloads: return "Downloads"
            }
        }

        var url: URL {
            switch self {
            case .desktop:
                return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            case .downloads:
                return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            }
        }
    }

    enum FileCategory: String, CaseIterable {
        case screenshots = "Screenshots"
        case documents = "Documents & PDFs"
        case images = "Images & Photos"
        case archives = "Archives & DMGs"
        case media = "Audio & Video"
        case code = "Code & Scripts"
        case other = "Other Files"

        static func category(for url: URL) -> FileCategory {
            let ext = url.pathExtension.lowercased()
            let name = url.lastPathComponent.lowercased()

            if name.contains("screenshot") || name.contains("screen shot") || name.contains("captura de tela") {
                return .screenshots
            }
            switch ext {
            case "pdf", "docx", "doc", "xlsx", "xls", "pptx", "txt", "rtf", "md", "pages", "numbers", "key":
                return .documents
            case "jpg", "jpeg", "png", "heic", "gif", "svg", "webp", "tiff", "bmp":
                return .images
            case "zip", "tar", "gz", "7z", "rar", "dmg", "pkg", "iso":
                return .archives
            case "mp4", "mov", "mkv", "avi", "mp3", "wav", "m4a", "aac", "flac":
                return .media
            case "swift", "py", "js", "ts", "html", "css", "json", "sh", "cpp", "c", "rs", "go", "sql":
                return .code
            default:
                return .other
            }
        }
    }

    struct MovedRecord: Identifiable {
        let id = UUID()
        let sourceURL: URL
        let destinationURL: URL
        let category: FileCategory
    }

    @Published var selectedTarget: TargetFolder = .desktop
    @Published private(set) var lastOrganizedRecords: [MovedRecord] = []
    @Published private(set) var isOrganizing = false
    @Published private(set) var statusMessage: String?

    private init() {}

    func organize() {
        guard !isOrganizing else { return }
        isOrganizing = true
        statusMessage = nil

        let targetURL = selectedTarget.url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(at: targetURL,
                                                             includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                                                             options: [.skipsHiddenFiles]) else {
                DispatchQueue.main.async { self?.isOrganizing = false }
                return
            }

            var movedList: [MovedRecord] = []
            let organizedRoot = targetURL.appendingPathComponent("Organized")

            for fileURL in contents {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else { continue }

                let cat = FileCategory.category(for: fileURL)
                let catDir = organizedRoot.appendingPathComponent(cat.rawValue)
                try? fm.createDirectory(at: catDir, withIntermediateDirectories: true)

                let destURL = catDir.appendingPathComponent(fileURL.lastPathComponent)
                do {
                    try fm.moveItem(at: fileURL, to: destURL)
                    movedList.append(MovedRecord(sourceURL: fileURL, destinationURL: destURL, category: cat))
                } catch {
                    // Item already exists or locked
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.lastOrganizedRecords = movedList
                self.isOrganizing = false
                self.statusMessage = "Organized \(movedList.count) files successfully."
            }
        }
    }

    func undoLastOrganization() {
        guard !lastOrganizedRecords.isEmpty else { return }
        let records = lastOrganizedRecords

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var reverted = 0
            for record in records {
                if fm.fileExists(atPath: record.destinationURL.path) {
                    try? fm.moveItem(at: record.destinationURL, to: record.sourceURL)
                    reverted += 1
                }
            }

            DispatchQueue.main.async {
                self?.lastOrganizedRecords = []
                self?.statusMessage = "Restored \(reverted) files to original locations."
            }
        }
    }
}
