// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import CoreAudio
import Foundation
import SwiftUI

/// Equalizer target scope (Global system output or Per-App).
enum EqualizerTargetScope: Equatable {
    case globalMaster
    case app(bundleID: String, name: String)

    var displayName: String {
        switch self {
        case .globalMaster: return "Global Output (All Audio)"
        case .app(_, let name): return "App: \(name)"
        }
    }
}

/// Central state manager and service for audio equalization in Vorssaint.
final class AudioEqualizerService: ObservableObject {
    static let shared = AudioEqualizerService()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: DefaultsKey.equalizerEnabled)
            syncDSP()
        }
    }

    @Published var isBypassed: Bool {
        didSet {
            UserDefaults.standard.set(isBypassed, forKey: DefaultsKey.equalizerBypassed)
            syncDSP()
        }
    }

    @Published var activeProfile: EqualizerProfile {
        didSet {
            saveActiveProfile()
            syncDSP()
        }
    }

    @Published var customProfiles: [EqualizerProfile] = [] {
        didSet {
            saveCustomProfiles()
        }
    }

    @Published var activeTargetScope: EqualizerTargetScope = .globalMaster {
        didSet {
            syncScopeProfile()
        }
    }

    /// Map of App persistence ID -> Profile ID
    @Published var appProfileMappings: [String: String] = [:] {
        didSet {
            saveAppMappings()
            syncDSP()
        }
    }

    @Published var isBassExciterEnabled: Bool = false {
        didSet {
            syncDSP()
        }
    }

    @Published var isSpatialVirtualizerEnabled: Bool = false {
        didSet {
            syncDSP()
        }
    }

    @Published var activeChannelFilter: EqualizerChannelTarget = .stereo

    /// Master DSP instance applied to system output or aggregate devices.
    let masterDSP = EqualizerDSPInstance()

    /// Per-app DSP instances.
    private var appDSPInstances: [String: EqualizerDSPInstance] = [:]
    private var currentSampleRate: Double = 48000.0

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: DefaultsKey.equalizerEnabled) as? Bool ?? true
        self.isBypassed = UserDefaults.standard.bool(forKey: DefaultsKey.equalizerBypassed)

        // Load custom profiles
        let loadedCustom = Self.loadCustomProfilesFromDefaults()
        self.customProfiles = loadedCustom

        // Load active profile
        if let savedActive = Self.loadActiveProfileFromDefaults() {
            self.activeProfile = savedActive
        } else {
            self.activeProfile = EqualizerPresetManager.shared.builtInPresets.first ?? .flat()
        }

        // Load app mappings
        if let mappings = UserDefaults.standard.dictionary(forKey: DefaultsKey.equalizerAppMappings) as? [String: String] {
            self.appProfileMappings = mappings
        }

        syncDSP()
    }

    // MARK: - DSP Syncing

    /// Updates all active DSP instances with current profile settings and sample rate.
    func syncDSP() {
        let effectivelyBypassed = !isEnabled || isBypassed
        masterDSP.update(
            profile: activeProfile,
            isBypassed: effectivelyBypassed,
            sampleRate: currentSampleRate,
            isBassExciterEnabled: isBassExciterEnabled,
            isSpatialVirtualizerEnabled: isSpatialVirtualizerEnabled
        )

        // Update per-app DSPs
        for (appID, dsp) in appDSPInstances {
            let profileToUse = profileForApp(id: appID)
            dsp.update(
                profile: profileToUse,
                isBypassed: effectivelyBypassed,
                sampleRate: currentSampleRate,
                isBassExciterEnabled: isBassExciterEnabled,
                isSpatialVirtualizerEnabled: isSpatialVirtualizerEnabled
            )
        }
    }

    /// Returns a dedicated DSP instance for a specific app row.
    func dspForApp(id: String) -> EqualizerDSPInstance {
        if let existing = appDSPInstances[id] {
            return existing
        }
        let instance = EqualizerDSPInstance()
        let profileToUse = profileForApp(id: id)
        let effectivelyBypassed = !isEnabled || isBypassed
        instance.update(profile: profileToUse, isBypassed: effectivelyBypassed, sampleRate: currentSampleRate)
        appDSPInstances[id] = instance
        return instance
    }

    /// Removes an app's DSP instance when its tap terminates.
    func removeAppDSP(id: String) {
        appDSPInstances.removeValue(forKey: id)
    }

    /// Updates the sample rate across all DSP engines.
    func setSampleRate(_ rate: Double) {
        guard rate > 0, rate != currentSampleRate else { return }
        currentSampleRate = rate
        syncDSP()
    }

    // MARK: - Profile & Scope Management

    func allProfiles() -> [EqualizerProfile] {
        EqualizerPresetManager.shared.builtInPresets + customProfiles
    }

    func selectProfile(id: String) {
        if let found = allProfiles().first(where: { $0.id == id }) {
            self.activeProfile = found
            switch activeTargetScope {
            case .globalMaster:
                break
            case .app(let bundleID, _):
                appProfileMappings[bundleID] = found.id
            }
        }
    }

    func profileForApp(id: String) -> EqualizerProfile {
        if let profileID = appProfileMappings[id],
           let profile = allProfiles().first(where: { $0.id == profileID }) {
            return profile
        }
        return activeProfile
    }

    private func syncScopeProfile() {
        switch activeTargetScope {
        case .globalMaster:
            // Keep current activeProfile
            break
        case .app(let bundleID, _):
            if let profileID = appProfileMappings[bundleID],
               let profile = allProfiles().first(where: { $0.id == profileID }) {
                self.activeProfile = profile
            }
        }
    }

    // MARK: - Editing Helpers

    func updatePreamp(_ db: Double) {
        activeProfile.preamp = min(max(db, -20.0), 20.0)
    }

    func updateBand(id: UUID, mutate: (inout EqualizerBand) -> Void) {
        if let index = activeProfile.bands.firstIndex(where: { $0.id == id }) {
            mutate(&activeProfile.bands[index])
            // Ensure built-in flag is cleared when user modifies
            if activeProfile.isBuiltIn {
                activeProfile.id = UUID().uuidString
                activeProfile.name = "\(activeProfile.name) (Custom)"
                activeProfile.isBuiltIn = false
                saveAsCustomProfile(activeProfile)
            }
        }
    }

    func addBand(frequency: Double = 1000.0, gain: Double = 0.0, q: Double = 1.41, type: EqualizerFilterType = .peaking) {
        let newBand = EqualizerBand(
            id: UUID(),
            isEnabled: true,
            type: type,
            frequency: frequency,
            gain: gain,
            q: q,
            channel: activeChannelFilter
        )
        activeProfile.bands.append(newBand)
        activeProfile.bands.sort(by: { $0.frequency < $1.frequency })
        if activeProfile.isBuiltIn {
            activeProfile.id = UUID().uuidString
            activeProfile.name = "\(activeProfile.name) (Custom)"
            activeProfile.isBuiltIn = false
            saveAsCustomProfile(activeProfile)
        }
    }

    func removeBand(id: UUID) {
        activeProfile.bands.removeAll(where: { $0.id == id })
        if activeProfile.isBuiltIn {
            activeProfile.id = UUID().uuidString
            activeProfile.name = "\(activeProfile.name) (Custom)"
            activeProfile.isBuiltIn = false
            saveAsCustomProfile(activeProfile)
        }
    }

    func resetToFlat() {
        activeProfile.preamp = 0.0
        for i in 0..<activeProfile.bands.count {
            activeProfile.bands[i].gain = 0.0
        }
        for (k, _) in activeProfile.graphicGains {
            activeProfile.graphicGains[k] = 0.0
        }
    }

    func updateGraphicGain(freqKey: String, gain: Double) {
        activeProfile.graphicGains[freqKey] = min(max(gain, -24.0), 24.0)
        if activeProfile.isBuiltIn {
            activeProfile.id = UUID().uuidString
            activeProfile.name = "\(activeProfile.name) (Custom)"
            activeProfile.isBuiltIn = false
            saveAsCustomProfile(activeProfile)
        }
    }

    func saveAsCustomProfile(_ profile: EqualizerProfile) {
        var copy = profile
        if copy.isBuiltIn || copy.id.starts(with: "builtin-") {
            copy.id = UUID().uuidString
            copy.isBuiltIn = false
        }
        if let existingIndex = customProfiles.firstIndex(where: { $0.id == copy.id }) {
            customProfiles[existingIndex] = copy
        } else {
            customProfiles.append(copy)
        }
        self.activeProfile = copy
    }

    func deleteCustomProfile(id: String) {
        customProfiles.removeAll(where: { $0.id == id })
        if activeProfile.id == id {
            self.activeProfile = EqualizerPresetManager.shared.builtInPresets.first ?? .flat()
        }
    }

    // MARK: - Persistence

    private func saveActiveProfile() {
        if let encoded = try? JSONEncoder().encode(activeProfile) {
            UserDefaults.standard.set(encoded, forKey: DefaultsKey.equalizerActiveProfileData)
        }
    }

    private static func loadActiveProfileFromDefaults() -> EqualizerProfile? {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.equalizerActiveProfileData),
              let profile = try? JSONDecoder().decode(EqualizerProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    private func saveCustomProfiles() {
        if let encoded = try? JSONEncoder().encode(customProfiles) {
            UserDefaults.standard.set(encoded, forKey: DefaultsKey.equalizerCustomProfilesData)
        }
    }

    private static func loadCustomProfilesFromDefaults() -> [EqualizerProfile] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.equalizerCustomProfilesData),
              let profiles = try? JSONDecoder().decode([EqualizerProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    private func saveAppMappings() {
        UserDefaults.standard.set(appProfileMappings, forKey: DefaultsKey.equalizerAppMappings)
    }
}
