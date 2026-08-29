// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Manages built-in and user presets, and handles import/export of Equalizer APO and AutoEq formats.
final class EqualizerPresetManager {
    static let shared = EqualizerPresetManager()

    /// All factory built-in presets.
    var builtInPresets: [EqualizerProfile] {
        [
            flatPreset,
            bassBoostPreset,
            bassReducerPreset,
            trebleBoostPreset,
            trebleReducerPreset,
            vocalClarityPreset,
            electronicPreset,
            rockPreset,
            popPreset,
            classicalPreset,
            jazzPreset,
            gamingFootstepsPreset,
            movieCinemaPreset,
            loudnessPreset
        ]
    }

    // MARK: - Factory Presets

    private var flatPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-flat",
            name: "Flat / Neutral",
            preamp: 0.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 32.0, gain: 0.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 64.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 125.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 250.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 500.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 2000.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 4000.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .peaking, frequency: 8000.0, gain: 0.0, q: 1.41),
                EqualizerBand(type: .highShelf, frequency: 16000.0, gain: 0.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var bassBoostPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-bass-boost",
            name: "Bass Boost",
            preamp: -3.5,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 80.0, gain: 6.0, q: 0.8),
                EqualizerBand(type: .peaking, frequency: 125.0, gain: 3.5, q: 1.2),
                EqualizerBand(type: .peaking, frequency: 250.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 500.0, gain: 0.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 0.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 2000.0, gain: 0.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 4000.0, gain: 1.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 8000.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 14000.0, gain: 2.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var bassReducerPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-bass-reducer",
            name: "Bass Reducer",
            preamp: 0.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .highPass, frequency: 40.0, gain: 0.0, q: 0.71),
                EqualizerBand(type: .lowShelf, frequency: 120.0, gain: -6.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 250.0, gain: -2.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 0.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 4000.0, gain: 0.5, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 12000.0, gain: 0.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var trebleBoostPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-treble-boost",
            name: "Treble Boost & Air",
            preamp: -3.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 100.0, gain: 0.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 0.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 3500.0, gain: 2.5, q: 1.5),
                EqualizerBand(type: .peaking, frequency: 7000.0, gain: 4.5, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 10000.0, gain: 5.5, q: 0.8)
            ],
            isBuiltIn: true
        )
    }

    private var trebleReducerPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-treble-reducer",
            name: "Treble Reducer",
            preamp: 0.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .peaking, frequency: 3500.0, gain: -2.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 6500.0, gain: -4.5, q: 1.5),
                EqualizerBand(type: .highShelf, frequency: 9000.0, gain: -6.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var vocalClarityPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-vocal-clarity",
            name: "Vocal & Speech Clarity",
            preamp: -2.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .highPass, frequency: 75.0, gain: 0.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 250.0, gain: -2.0, q: 1.8),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 2800.0, gain: 4.0, q: 1.6),
                EqualizerBand(type: .peaking, frequency: 5000.0, gain: 3.0, q: 1.5),
                EqualizerBand(type: .highShelf, frequency: 10000.0, gain: 1.5, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var electronicPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-electronic",
            name: "Electronic / EDM",
            preamp: -3.5,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 60.0, gain: 5.5, q: 0.8),
                EqualizerBand(type: .peaking, frequency: 120.0, gain: 3.0, q: 1.5),
                EqualizerBand(type: .peaking, frequency: 350.0, gain: -1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 0.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 3000.0, gain: 2.0, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 8500.0, gain: 4.5, q: 0.75)
            ],
            isBuiltIn: true
        )
    }

    private var rockPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-rock",
            name: "Rock / Metal",
            preamp: -3.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 80.0, gain: 4.0, q: 0.8),
                EqualizerBand(type: .peaking, frequency: 200.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 800.0, gain: -1.5, q: 1.6),
                EqualizerBand(type: .peaking, frequency: 2200.0, gain: 3.0, q: 1.5),
                EqualizerBand(type: .peaking, frequency: 4500.0, gain: 3.5, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 10000.0, gain: 3.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var popPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-pop",
            name: "Pop",
            preamp: -2.5,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 90.0, gain: 3.5, q: 0.75),
                EqualizerBand(type: .peaking, frequency: 300.0, gain: 1.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1200.0, gain: 2.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 3500.0, gain: 2.5, q: 1.5),
                EqualizerBand(type: .highShelf, frequency: 9000.0, gain: 3.5, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var classicalPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-classical",
            name: "Classical / Acoustic",
            preamp: -1.5,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 100.0, gain: 2.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 500.0, gain: 0.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1800.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 4500.0, gain: 2.0, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 10000.0, gain: 2.5, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var jazzPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-jazz",
            name: "Jazz",
            preamp: -2.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 80.0, gain: 3.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 250.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1000.0, gain: 1.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 3000.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 8000.0, gain: 2.5, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var gamingFootstepsPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-gaming",
            name: "Gaming & Footsteps",
            preamp: -2.5,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .highPass, frequency: 60.0, gain: 0.0, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 180.0, gain: -3.0, q: 1.5),
                EqualizerBand(type: .peaking, frequency: 1500.0, gain: 3.0, q: 1.8),
                EqualizerBand(type: .peaking, frequency: 3200.0, gain: 5.0, q: 2.0),
                EqualizerBand(type: .peaking, frequency: 6000.0, gain: 3.5, q: 1.8),
                EqualizerBand(type: .highShelf, frequency: 10000.0, gain: 1.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var movieCinemaPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-movie",
            name: "Movie / Cinema",
            preamp: -3.0,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 70.0, gain: 4.5, q: 0.75),
                EqualizerBand(type: .peaking, frequency: 200.0, gain: 1.5, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 1200.0, gain: 1.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 2800.0, gain: 3.5, q: 1.6),
                EqualizerBand(type: .highShelf, frequency: 9000.0, gain: 3.0, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    private var loudnessPreset: EqualizerProfile {
        EqualizerProfile(
            id: "builtin-loudness",
            name: "Loudness Compensation",
            preamp: -4.5,
            mode: .parametric,
            bands: [
                EqualizerBand(type: .lowShelf, frequency: 100.0, gain: 6.5, q: 0.71),
                EqualizerBand(type: .peaking, frequency: 500.0, gain: -1.0, q: 1.4),
                EqualizerBand(type: .peaking, frequency: 2000.0, gain: 0.5, q: 1.4),
                EqualizerBand(type: .highShelf, frequency: 7500.0, gain: 5.5, q: 0.71)
            ],
            isBuiltIn: true
        )
    }

    // MARK: - Equalizer APO / Peace Text Parser & Exporter

    /// Parses an Equalizer APO configuration file text into an `EqualizerProfile`.
    func parseEqualizerAPO(text: String, name: String = "Imported Profile") -> EqualizerProfile {
        var preamp: Double = 0.0
        var bands: [EqualizerBand] = []
        var graphicGains: [String: Double] = [:]
        var isGraphic = false

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }

            // Preamp: -6.0 dB
            if trimmed.lowercased().hasPrefix("preamp:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let valStr = parts[1].replacingOccurrences(of: "dB", with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                    if let val = Double(valStr) {
                        preamp = min(max(val, -20.0), 20.0)
                    }
                }
                continue
            }

            // GraphicEQ: 25 0; 40 1.5; 63 2.0; ...
            if trimmed.lowercased().hasPrefix("graphiceq:") {
                isGraphic = true
                let content = trimmed.dropFirst("graphiceq:".count).trimmingCharacters(in: .whitespaces)
                let points = content.components(separatedBy: ";")
                for point in points {
                    let tokens = point.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                    if tokens.count >= 2, let f = Double(tokens[0]), let g = Double(tokens[1]) {
                        let key = GraphicEqualizerFrequencies.formatFrequency(f)
                        graphicGains[key] = min(max(g, -24.0), 24.0)
                    }
                }
                continue
            }

            // Filter 1: ON PK Fc 1000 Hz Gain 3.0 dB Q 1.41
            // Filter: ON LS Fc 80.0 Hz Gain 4.5 dB Q 0.71
            if trimmed.lowercased().hasPrefix("filter") {
                if let band = parseFilterLine(trimmed) {
                    bands.append(band)
                }
                continue
            }
        }

        let mode: EqualizerMode = isGraphic ? .graphic10 : .parametric
        if bands.isEmpty && !isGraphic {
            // Fallback default
            return EqualizerProfile.defaultParametric(name: name)
        }

        return EqualizerProfile(
            name: name,
            preamp: preamp,
            mode: mode,
            bands: bands,
            graphicGains: graphicGains,
            isBuiltIn: false
        )
    }

    private func parseFilterLine(_ line: String) -> EqualizerBand? {
        // Example: Filter 1: ON PK Fc 1000 Hz Gain 3.0 dB Q 1.41
        var text = line
        if let colonIndex = text.firstIndex(of: ":") {
            text = String(text[text.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        }

        let tokens = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard tokens.count >= 2 else { return nil }

        var isEnabled = true
        var type: EqualizerFilterType = .peaking
        var freq: Double = 1000.0
        var gain: Double = 0.0
        var q: Double = 1.41
        var channel: EqualizerChannelTarget = .stereo

        var i = 0
        while i < tokens.count {
            let token = tokens[i].uppercased()

            if token == "ON" {
                isEnabled = true
                i += 1
            } else if token == "OFF" {
                isEnabled = false
                i += 1
            } else if let matchedType = EqualizerFilterType(rawValue: token) {
                type = matchedType
                i += 1
            } else if token == "PK" || token == "PEAKING" || token == "BELL" {
                type = .peaking
                i += 1
            } else if token == "LS" || token == "LOWSHELF" {
                type = .lowShelf
                i += 1
            } else if token == "HS" || token == "HIGHSHELF" {
                type = .highShelf
                i += 1
            } else if token == "LP" || token == "LOWPASS" {
                type = .lowPass
                i += 1
            } else if token == "HP" || token == "HIGHPASS" {
                type = .highPass
                i += 1
            } else if token == "BP" || token == "BANDPASS" {
                type = .bandPass
                i += 1
            } else if token == "NO" || token == "NOTCH" {
                type = .notch
                i += 1
            } else if token == "AP" || token == "ALLPASS" {
                type = .allPass
                i += 1
            } else if token == "FC" || token == "FREQ" || token == "FREQUENCY" {
                if i + 1 < tokens.count, let val = Double(tokens[i + 1]) {
                    freq = val
                    i += 2
                    if i < tokens.count && tokens[i].uppercased() == "HZ" { i += 1 }
                } else {
                    i += 1
                }
            } else if token == "GAIN" {
                if i + 1 < tokens.count, let val = Double(tokens[i + 1]) {
                    gain = val
                    i += 2
                    if i < tokens.count && tokens[i].uppercased() == "DB" { i += 1 }
                } else {
                    i += 1
                }
            } else if token == "Q" {
                if i + 1 < tokens.count, let val = Double(tokens[i + 1]) {
                    q = val
                    i += 2
                } else {
                    i += 1
                }
            } else if token == "L" || token == "LEFT" {
                channel = .left
                i += 1
            } else if token == "R" || token == "RIGHT" {
                channel = .right
                i += 1
            } else {
                i += 1
            }
        }

        return EqualizerBand(
            isEnabled: isEnabled,
            type: type,
            frequency: freq,
            gain: gain,
            q: q,
            channel: channel
        )
    }

    /// Exports an `EqualizerProfile` to Equalizer APO configuration format text.
    func exportEqualizerAPO(profile: EqualizerProfile) -> String {
        var lines: [String] = []
        lines.append("# Equalizer APO Configuration Exported by Vorssaint")
        lines.append("# Profile: \(profile.name)")
        lines.append("")
        lines.append(String(format: "Preamp: %.1f dB", profile.preamp))
        lines.append("")

        if profile.mode == .parametric {
            for (index, band) in profile.bands.enumerated() {
                let status = band.isEnabled ? "ON" : "OFF"
                let typeStr = band.type.shortCode
                let freqStr = String(format: "%.1f", band.frequency)
                let gainStr = String(format: "%.1f", band.gain)
                let qStr = String(format: "%.2f", band.q)
                let line = "Filter \(index + 1): \(status) \(typeStr) Fc \(freqStr) Hz Gain \(gainStr) dB Q \(qStr)"
                lines.append(line)
            }
        } else {
            let freqs = GraphicEqualizerFrequencies.frequencies(for: profile.mode)
            var points: [String] = []
            for freq in freqs {
                let key = GraphicEqualizerFrequencies.formatFrequency(freq)
                let gain = profile.graphicGains[key] ?? 0.0
                points.append("\(Int(freq)) \(String(format: "%.1f", gain))")
            }
            lines.append("GraphicEQ: " + points.joined(separator: "; "))
        }

        return lines.joined(separator: "\n")
    }
}
