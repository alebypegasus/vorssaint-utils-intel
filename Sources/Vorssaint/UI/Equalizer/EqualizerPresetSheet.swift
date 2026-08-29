// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Sheet for managing presets and importing/exporting Equalizer APO configurations.
struct EqualizerPresetSheet: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @Environment(\.dismiss) private var dismiss

    @State private var newPresetName: String = ""
    @State private var showSaveAlert = false
    @State private var importErrorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            // Title Header
            HStack {
                Label("Equalizer Profiles & Presets", systemImage: "slider.vertical.3")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            Divider()

            // Main Actions (Import / Export / Save Current)
            HStack(spacing: 12) {
                Button {
                    openImportPanel()
                } label: {
                    Label("Import Equalizer APO / AutoEq", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)

                Button {
                    openExportPanel()
                } label: {
                    Label("Export .eqapo", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                HStack(spacing: 6) {
                    TextField("New Profile Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)

                    Button {
                        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        var newProfile = equalizer.activeProfile
                        newProfile.id = UUID().uuidString
                        newProfile.name = name
                        newProfile.isBuiltIn = false
                        equalizer.saveAsCustomProfile(newProfile)
                        newPresetName = ""
                    } label: {
                        Text("Save Preset")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let error = importErrorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Presets List
            List {
                Section(header: Text("Factory Built-in Presets").font(.system(size: 11, weight: .bold))) {
                    ForEach(EqualizerPresetManager.shared.builtInPresets) { preset in
                        presetRow(preset, isCustom: false)
                    }
                }

                if !equalizer.customProfiles.isEmpty {
                    Section(header: Text("Custom & Imported Profiles").font(.system(size: 11, weight: .bold))) {
                        ForEach(equalizer.customProfiles) { preset in
                            presetRow(preset, isCustom: true)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(height: 280)
        }
        .padding(18)
        .frame(width: 580, height: 420)
    }

    private func presetRow(_ preset: EqualizerProfile, isCustom: Bool) -> some View {
        let isCurrent = equalizer.activeProfile.id == preset.id

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(size: 12.5, weight: isCurrent ? .bold : .medium))
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)

                    if isCurrent {
                        Text("ACTIVE")
                            .font(.system(size: 8.5, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text(preset.mode.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text("Preamp: \(String(format: "%+.1f dB", preset.preamp))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if preset.mode == .parametric {
                        Text("\(preset.bands.count) bands")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if !isCurrent {
                Button("Apply") {
                    equalizer.selectProfile(id: preset.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isCustom {
                Button {
                    equalizer.deleteCustomProfile(id: preset.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete custom preset")
            }
        }
        .padding(.vertical, 3)
    }

    private func openImportPanel() {
        importErrorMessage = nil
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [UTType.plainText, UTType(filenameExtension: "eqapo") ?? .plainText]
        panel.title = "Import Equalizer APO / AutoEq Profile"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let name = url.deletingPathExtension().lastPathComponent
                let profile = EqualizerPresetManager.shared.parseEqualizerAPO(text: content, name: name)
                equalizer.saveAsCustomProfile(profile)
            } catch {
                importErrorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        }
    }

    private func openExportPanel() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "eqapo") ?? .plainText]
        panel.nameFieldStringValue = "\(equalizer.activeProfile.name).eqapo"
        panel.title = "Export Equalizer APO Profile"

        if panel.runModal() == .OK, let url = panel.url {
            let content = EqualizerPresetManager.shared.exportEqualizerAPO(profile: equalizer.activeProfile)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
