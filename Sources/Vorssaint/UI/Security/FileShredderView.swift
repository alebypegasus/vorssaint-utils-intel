// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import UniformTypeIdentifiers

struct FileShredderView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var shredder = FileShredder.shared
    @State private var selectedURLs: [URL] = []
    @State private var showingConfirm = false

    var body: some View {
        VStack(spacing: 20) {
            // Standard Picker
            Picker("Shredding Algorithm", selection: $shredder.selectedStandard) {
                ForEach(FileShredder.ShreddingStandard.allCases) { std in
                    Text(std.label).tag(std)
                }
            }
            .pickerStyle(.menu)
            .padding(.top, 16)

            // Drop zone / File selector
            VStack(spacing: 14) {
                Image(systemName: "flame")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text(selectedURLs.isEmpty ? "Select Files to Permanently Shred" : "\(selectedURLs.count) Files Selected")
                    .font(.headline)
                Text("Overwrites disk sectors with multi-pass random data before unlinking to prevent any forensic recovery.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Choose Files…") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    if panel.runModal() == .OK {
                        selectedURLs = panel.urls
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal, 20)

            if shredder.isShredding {
                VStack(spacing: 8) {
                    ProgressView(value: shredder.progress)
                    Text("Shredding: \(shredder.currentFile)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
            }

            if let msg = shredder.statusMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            Spacer()

            if !selectedURLs.isEmpty {
                Button(role: .destructive) {
                    showingConfirm = true
                } label: {
                    Label("Shred & Permanently Destroy", systemImage: "flame.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(shredder.isShredding)
                .padding(.bottom, 20)
            }
        }
        .confirmationDialog(
            "Irreversibly Destroy \(selectedURLs.count) Files?",
            isPresented: $showingConfirm
        ) {
            Button("Destroy Files Permanently", role: .destructive) {
                shredder.shredFiles(urls: selectedURLs) { _ in
                    selectedURLs = []
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("WARNING: These files cannot be restored by any data recovery software. Their disk sectors will be overwritten.")
        }
    }
}
