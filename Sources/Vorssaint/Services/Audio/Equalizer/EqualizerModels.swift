// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import SwiftUI

/// Types of biquad IIR filters supported by the equalizer, matching Equalizer APO standards.
enum EqualizerFilterType: String, Codable, CaseIterable, Identifiable {
    case peaking = "PK"
    case lowShelf = "LS"
    case highShelf = "HS"
    case lowPass = "LP"
    case highPass = "HP"
    case bandPass = "BP"
    case notch = "NO"
    case allPass = "AP"

    var id: String { rawValue }

    var shortCode: String { rawValue }

    var displayName: String {
        switch self {
        case .peaking: return "Peaking (Bell)"
        case .lowShelf: return "Low Shelf"
        case .highShelf: return "High Shelf"
        case .lowPass: return "Low Pass"
        case .highPass: return "High Pass"
        case .bandPass: return "Band Pass"
        case .notch: return "Notch (Cut)"
        case .allPass: return "All Pass (Phase)"
        }
    }

    var systemImage: String {
        switch self {
        case .peaking: return "waveform.path.ecg"
        case .lowShelf: return "arrow.down.right.and.arrow.up.left"
        case .highShelf: return "arrow.up.right.and.arrow.down.left"
        case .lowPass: return "arrow.down.right"
        case .highPass: return "arrow.up.left"
        case .bandPass: return "waveform.path"
        case .notch: return "waveform.path.badge.minus"
        case .allPass: return "arrow.triangle.2.circlepath"
        }
    }

    /// Whether this filter type supports gain adjustment (dB).
    var hasGain: Bool {
        switch self {
        case .peaking, .lowShelf, .highShelf:
            return true
        case .lowPass, .highPass, .bandPass, .notch, .allPass:
            return false
        }
    }
}

/// Target channels for filtering.
enum EqualizerChannelTarget: String, Codable, CaseIterable, Identifiable {
    case stereo = "all"
    case left = "L"
    case right = "R"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stereo: return "Stereo (L+R)"
        case .left: return "Left (L)"
        case .right: return "Right (R)"
        }
    }

    var shortLabel: String {
        switch self {
        case .stereo: return "L+R"
        case .left: return "L"
        case .right: return "R"
        }
    }
}

/// Equalizer operational mode.
enum EqualizerMode: String, Codable, CaseIterable, Identifiable {
    case parametric = "parametric"
    case graphic10 = "graphic10"
    case graphic15 = "graphic15"
    case graphic31 = "graphic31"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .parametric: return "Parametric EQ"
        case .graphic10: return "10-Band Graphic"
        case .graphic15: return "15-Band Graphic (2/3 Oct)"
        case .graphic31: return "31-Band Graphic (1/3 Oct)"
        }
    }
}

/// A single parametric filter band.
struct EqualizerBand: Identifiable, Codable, Equatable {
    var id: UUID
    var isEnabled: Bool
    var type: EqualizerFilterType
    var frequency: Double // Hz (20 ... 20000)
    var gain: Double // dB (-24 ... +24)
    var q: Double // Quality factor (0.1 ... 20.0)
    var channel: EqualizerChannelTarget

    init(id: UUID = UUID(),
         isEnabled: Bool = true,
         type: EqualizerFilterType = .peaking,
         frequency: Double = 1000.0,
         gain: Double = 0.0,
         q: Double = 1.41,
         channel: EqualizerChannelTarget = .stereo) {
        self.id = id
        self.isEnabled = isEnabled
        self.type = type
        self.frequency = min(max(frequency, 20.0), 20000.0)
        self.gain = min(max(gain, -24.0), 24.0)
        self.q = min(max(q, 0.1), 20.0)
        self.channel = channel
    }

    /// Evaluates the magnitude response in dB of this band at target frequency `f` (Hz).
    func magnitudeResponse(atFrequency freq: Double, sampleRate: Double = 48000.0) -> Double {
        guard isEnabled else { return 0.0 }
        let coeffs = BiquadCoefficients.compute(type: type, frequency: frequency, gainDB: gain, q: q, sampleRate: sampleRate)
        return coeffs.responseGainDB(at: freq, sampleRate: sampleRate)
    }
}

/// Standard ISO frequency centers for Graphic Equalizers.
enum GraphicEqualizerFrequencies {
    /// 10 standard octave bands (ISO)
    static let bands10: [Double] = [
        31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0
    ]

    /// 15 standard 2/3 octave bands (ISO)
    static let bands15: [Double] = [
        25.0, 40.0, 63.0, 100.0, 160.0, 250.0, 400.0, 630.0,
        1000.0, 1600.0, 2500.0, 4000.0, 6300.0, 10000.0, 16000.0
    ]

    /// 31 standard 1/3 octave bands (ISO)
    static let bands31: [Double] = [
        20.0, 25.0, 31.5, 40.0, 50.0, 63.0, 80.0, 100.0, 125.0, 160.0,
        200.0, 250.0, 315.0, 400.0, 500.0, 630.0, 800.0, 1000.0, 1250.0, 1600.0,
        2000.0, 2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0, 10000.0, 12500.0, 16000.0,
        20000.0
    ]

    static func frequencies(for mode: EqualizerMode) -> [Double] {
        switch mode {
        case .graphic10: return bands10
        case .graphic15: return bands15
        case .graphic31: return bands31
        case .parametric: return bands10
        }
    }

    static func formatFrequency(_ hz: Double) -> String {
        if hz >= 1000.0 {
            let khz = hz / 1000.0
            if khz.truncatingRemainder(dividingBy: 1.0) == 0 {
                return "\(Int(khz))k"
            } else {
                return String(format: "%.1fk", khz)
            }
        } else {
            return "\(Int(hz))"
        }
    }
}

/// An Equalizer Profile (contains preamp, filter bands, and graphic EQ gains).
struct EqualizerProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var preamp: Double // dB (-20 ... +20)
    var mode: EqualizerMode
    var bands: [EqualizerBand]
    var graphicGains: [String: Double] // Freq (formatted as string) -> Gain (dB)
    var isBuiltIn: Bool

    init(id: String = UUID().uuidString,
         name: String,
         preamp: Double = 0.0,
         mode: EqualizerMode = .parametric,
         bands: [EqualizerBand] = [],
         graphicGains: [String: Double] = [:],
         isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.preamp = min(max(preamp, -20.0), 20.0)
        self.mode = mode
        self.bands = bands
        self.graphicGains = graphicGains
        self.isBuiltIn = isBuiltIn
    }

    /// Evaluates the composite magnitude response in dB across all enabled bands or graphic gains.
    func compositeMagnitudeResponse(atFrequency freq: Double, sampleRate: Double = 48000.0) -> Double {
        switch mode {
        case .parametric:
            var total = 0.0
            for band in bands where band.isEnabled {
                total += band.magnitudeResponse(atFrequency: freq, sampleRate: sampleRate)
            }
            return total
        case .graphic10, .graphic15, .graphic31:
            let freqs = GraphicEqualizerFrequencies.frequencies(for: mode)
            var total = 0.0
            for f in freqs {
                let key = GraphicEqualizerFrequencies.formatFrequency(f)
                let g = graphicGains[key] ?? 0.0
                if abs(g) > 0.01 {
                    let q = mode == .graphic31 ? 4.3 : (mode == .graphic15 ? 2.0 : 1.41)
                    let coeffs = BiquadCoefficients.compute(type: .peaking, frequency: f, gainDB: g, q: q, sampleRate: sampleRate)
                    total += coeffs.responseGainDB(at: freq, sampleRate: sampleRate)
                }
            }
            return total
        }
    }

    /// Creates a default 10-band parametric profile.
    static func defaultParametric(name: String = "Default") -> EqualizerProfile {
        let defaultFrequencies: [(Double, EqualizerFilterType, Double)] = [
            (32.0, .lowShelf, 0.71),
            (64.0, .peaking, 1.41),
            (125.0, .peaking, 1.41),
            (250.0, .peaking, 1.41),
            (500.0, .peaking, 1.41),
            (1000.0, .peaking, 1.41),
            (2000.0, .peaking, 1.41),
            (4000.0, .peaking, 1.41),
            (8000.0, .peaking, 1.41),
            (16000.0, .highShelf, 0.71)
        ]
        let bands = defaultFrequencies.map { freq, type, q in
            EqualizerBand(isEnabled: true, type: type, frequency: freq, gain: 0.0, q: q)
        }
        return EqualizerProfile(name: name, preamp: 0.0, mode: .parametric, bands: bands, isBuiltIn: false)
    }

    /// Creates a flat profile.
    static func flat() -> EqualizerProfile {
        var profile = defaultParametric(name: "Flat / Neutral")
        profile.isBuiltIn = true
        return profile
    }
}
