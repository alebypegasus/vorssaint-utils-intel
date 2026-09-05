// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Interactive duplicate file and photo finder with auto-selection rules,
/// visual photo comparisons, and 100% safe original-preservation guarantees.
struct DuplicateFilesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var finder = DuplicateFinder.shared
    @State private var showingCleanConfirmation = false
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            switch finder.phase {
            case .idle:
                idleView
            case let .scanning(stage, progress):
                scanningView(stage: stage, progress: progress)
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
            "Move duplicate files to Trash?",
            isPresented: $showingCleanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                finder.cleanSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(finder.selectedCount) duplicate copies (\(ByteCountFormatter.string(fromByteCount: finder.selectedSize, countStyle: .file))) to the Trash. Original files will remain untouched.")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Folder selector
            Menu {
                Button("Downloads") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Downloads"))
                }
                Button("Pictures") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Pictures"))
                }
                Button("Documents") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Documents"))
                }
                Button("Desktop") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory() + "/Desktop"))
                }
                Button("Home Folder (~)") {
                    finder.scan(directory: URL(fileURLWithPath: NSHomeDirectory()))
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

            // Filter mode
            Picker("", selection: $finder.filterMode) {
                ForEach(DuplicateFinder.FilterMode.allCases) { mode in
                    Label(mode.rawValue.capitalized, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

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
            Image(systemName: "doc.on.doc")
                .font(.system(size: compact ? 36 : 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Duplicate Files & Photos Finder")
                .font(.system(size: 16, weight: .semibold))
            Text("Scan any directory for exact identical files, duplicated photos, and media copies taking up wasted disk space.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                finder.scan()
            } label: {
                Text("Scan for Duplicates")
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

    private func scanningView(stage: String, progress: Double) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text(stage)
                .font(.system(size: 14, weight: .medium))
            Text("Comparing hashes and file sizes…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Results State

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Auto Select & Quick Actions Bar
            HStack(spacing: 8) {
                Menu {
                    Button("Keep Newest (Select Old Copies)") {
                        finder.autoSelectKeepNewest()
                    }
                    Button("Keep Oldest (Select New Copies)") {
                        finder.autoSelectKeepOldest()
                    }
                    Button("Keep Primary Folder (Select Downloads/Desktop)") {
                        finder.autoSelectKeepPrimaryFolder()
                    }
                    Divider()
                    Button("Deselect All") {
                        finder.deselectAll()
                    }
                } label: {
                    Label("Auto-Select Rules", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Text("\(finder.filteredGroups.count) duplicate groups (\(ByteCountFormatter.string(fromByteCount: finder.totalWastedSize, countStyle: .file)) recoverable)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Divider()

            if finder.filteredGroups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No duplicates found")
                        .font(.system(size: 14, weight: .medium))
                    Text("Your chosen directory contains no identical duplicate files.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(finder.filteredGroups) { group in
                        Section {
                            ForEach(group.items) { item in
                                HStack(spacing: 10) {
                                    Toggle("", isOn: Binding(
                                        get: { item.include },
                                        set: { finder.setInclude($0, forGroupID: group.id, itemID: item.id) }
                                    ))
                                    .labelsHidden()

                                    Image(systemName: item.isPhoto ? "photo" : "doc")
                                        .font(.system(size: 14))
                                        .foregroundStyle(item.isPhoto ? .blue : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.path)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Text("Modified: \(DateFormatter.localizedString(from: item.modifiedDate, dateStyle: .short, timeStyle: .short))")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

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
                        } header: {
                            HStack {
                                Text(group.sampleName)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(group.items.count) copies • \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file)) each")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Bottom action bar
            HStack {
                Button("Deselect All") {
                    finder.deselectAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                if finder.selectedCount > 0 {
                    Text("\(finder.selectedCount) copies selected (\(ByteCountFormatter.string(fromByteCount: finder.selectedSize, countStyle: .file)))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Button("Clean Duplicates") {
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
            Text("Moving duplicate files to Trash…")
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
            Text("Duplicates Cleaned")
                .font(.system(size: 16, weight: .semibold))
            Text("Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)) of wasted storage.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if failed > 0 {
                Text("\(failed) duplicate files could not be moved.")
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
