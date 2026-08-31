// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct FileAutoOrganizerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var organizer = FileAutoOrganizer.shared

    var body: some View {
        VStack(spacing: 20) {
            // Target folder picker
            Picker("Folder to Organize", selection: $organizer.selectedTarget) {
                ForEach(FileAutoOrganizer.TargetFolder.allCases) { target in
                    Text(target.label).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .padding(.top, 16)

            // Description Card
            VStack(alignment: .leading, spacing: 10) {
                Label("Smart Category Sorting", systemImage: "folder.badge.gearshape")
                    .font(.headline)
                Text("Scans the chosen folder and organizes loose files into smart subfolders: Screenshots, Documents & PDFs, Images, Archives, Media, and Code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal, 20)

            // Status message
            if let msg = organizer.statusMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            Spacer()

            // Actions
            HStack(spacing: 16) {
                if !organizer.lastOrganizedRecords.isEmpty {
                    Button("Undo Last Organization") {
                        organizer.undoLastOrganization()
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    organizer.organize()
                } label: {
                    Label(organizer.isOrganizing ? "Organizing…" : "Organize Folder Now", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(organizer.isOrganizing)
            }
            .padding(.bottom, 24)
        }
    }
}
