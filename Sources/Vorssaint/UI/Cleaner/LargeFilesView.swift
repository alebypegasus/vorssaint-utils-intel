// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Fast, interactive visual browser for large files occupying disk space.
/// Allows instant filtering by type and size threshold, native QuickLook previews,
/// and safe removal to the macOS Trash.
struct LargeFilesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var finder = LargeFilesFinder.shared
    @State private var showingCleanConfirmation = false
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            switch finder.phase {
            case .idle:
                idleView
            case let .scanning(count):
                scanningView(count: count)
            case .results:
                resultsView
            case .cleaning:
                cleaningView
            case let .done(freed, failed):
                doneView(freed: freed, failed: failed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Move selected files to Trash?",
            isPresented: $showingCleanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                finder.cleanSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(finder.selectedCount) items (\(ByteCountFormatter.string(fromByteCount: finder.selectedSize, countStyle: .file))) to the Trash.")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Folder selector
            Menu {
                Button("Home Folder (~)") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory()))
                }
                Button("Downloads") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Downloads"))
                }
                Button("Documents") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Documents"))
                }
                Button("Movies") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Movies"))
                }
                Button("Desktop") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Desktop"))
                }
                Divider()
                Button("Choose Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        finder.scan(directory: url)
                    }
                }
            } label: {
                Label(finder.selectedDirectory.lastPathComponent, systemImage: "folder")
                    .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Size Filter Picker
            Picker("", selection: $finder.minSize) {
                ForEach(LargeFilesFinder.SizeFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)

            // Rescan button
            Button {
                finder.scan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Rescan Directory")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: compact ? 36 : 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Large & Old Files Finder")
                .font(.system(size: 16, weight: .semibold))
            Text("Find massive files, ancient archives, high-res videos, and unused installers taking up your storage.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button {
                finder.scan()
            } label: {
                Text("Scan Folder")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Scanning State

    private func scanningView(count: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("Scanning for large files…")
                .font(.system(size: 14, weight: .medium))
            if count > 0 {
                Text("\(count) items inspected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Results State

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Category Filter Bar
            HStack(spacing: 6) {
                ForEach(LargeFilesFinder.FileKind.allCases) { kind in
                    Button {
                        finder.selectedKind = kind
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: kind.icon)
                            Text(kind.rawValue.capitalized)
                        }
                        .font(.system(size: 11, weight: finder.selectedKind == kind ? .semibold : .regular))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(finder.selectedKind == kind ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Divider()

            // List of items
            if finder.filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No large files matching criteria")
                        .font(.system(size: 14, weight: .medium))
                    Text("Try lowering the minimum size filter or changing directory.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(finder.filteredItems) { item in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { item.include },
                                set: { finder.setInclude($0, for: item.id) }
                            ))
                            .labelsHidden()

                            Image(systemName: item.kind.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(item.path)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Bottom action bar
            HStack {
                Button(finder.selectedCount == finder.filteredItems.count && !finder.filteredItems.isEmpty ? "Deselect All" : "Select All") {
                    let allSelected = finder.selectedCount == finder.filteredItems.count && !finder.filteredItems.isEmpty
                    finder.selectAllFiltered(!allSelected)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                if finder.selectedCount > 0 {
                    Text("\(finder.selectedCount) selected (\(ByteCountFormatter.string(fromByteCount: finder.selectedSize, countStyle: .file)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Button("Move to Trash") {
                    showingCleanConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(finder.selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Cleaning State

    private var cleaningView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("Moving selected files to Trash…")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
    }

    // MARK: - Done State

    private func doneView(freed: Int64, failed: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Large Files Cleaned")
                .font(.system(size: 16, weight: .semibold))
            Text("Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)) of disk space.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if failed > 0 {
                Text("\(failed) items could not be moved (permission denied).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button("Scan Again") {
                finder.scan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            Spacer()
        }
        .padding(24)
    }
}
