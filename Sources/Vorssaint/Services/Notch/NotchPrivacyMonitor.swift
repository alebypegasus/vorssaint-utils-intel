// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import CoreAudio
import CoreMediaIO
import Foundation

/// Watches whether any app is using the Mac's camera or microphone so the
/// Dynamic Island can display green (camera) and orange (microphone) dots.
/// Event-driven through CoreMediaIO and CoreAudio property listeners with zero polling.
final class NotchPrivacyMonitor: ObservableObject {
    static let shared = NotchPrivacyMonitor()

    @Published private(set) var cameraInUse = false
    @Published private(set) var microphoneInUse = false

    private let queue = DispatchQueue(label: "com.vorssaint.notch.privacy", qos: .utility)
    private var started = false
    private var watchedCameras: [CMIOObjectID] = []
    private var watchedMics: [AudioObjectID] = []
    private var devicesListenerBlock: CMIOObjectPropertyListenerBlock?
    private var cameraRunListenerBlock: CMIOObjectPropertyListenerBlock?
    private var audioDevicesListenerBlock: AudioObjectPropertyListenerBlock?
    private var micRunListenerBlock: AudioObjectPropertyListenerBlock?

    private static let cmioDevicesAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )

    private static let cmioRunningAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )

    private static let audioDevicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let audioRunningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let audioInputStreamsAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )

    var enabled: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.notchPrivacyDots) as? Bool ?? true
    }

    var anyActive: Bool {
        enabled && (cameraInUse || microphoneInUse)
    }

    func syncWithPreferences() {
        if NotchSupport.isEnabled() && enabled {
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard !started else { return }
        started = true
        queue.async { [weak self] in
            self?.installListeners()
            self?.rebindCameras()
            self?.rebindMicrophones()
            self?.refreshStates()
        }
    }

    func stop() {
        guard started else { return }
        started = false
        queue.async { [weak self] in
            self?.removeListeners()
        }
        DispatchQueue.main.async {
            if self.cameraInUse { self.cameraInUse = false }
            if self.microphoneInUse { self.microphoneInUse = false }
        }
    }

    private func installListeners() {
        let camDevicesBlock: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.rebindCameras()
            self?.refreshStates()
        }
        let camRunBlock: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshStates()
        }
        let micDevicesBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.rebindMicrophones()
            self?.refreshStates()
        }
        let micRunBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshStates()
        }
        devicesListenerBlock = camDevicesBlock
        cameraRunListenerBlock = camRunBlock
        audioDevicesListenerBlock = micDevicesBlock
        micRunListenerBlock = micRunBlock

        var cmioAddr = Self.cmioDevicesAddress
        CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &cmioAddr, queue, camDevicesBlock)

        var audioAddr = Self.audioDevicesAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &audioAddr, queue, micDevicesBlock)
    }

    private func removeListeners() {
        var cmioAddr = Self.cmioDevicesAddress
        if let block = devicesListenerBlock {
            CMIOObjectRemovePropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &cmioAddr, queue, block)
            devicesListenerBlock = nil
        }
        var camRunAddr = Self.cmioRunningAddress
        if let block = cameraRunListenerBlock {
            for id in watchedCameras {
                CMIOObjectRemovePropertyListenerBlock(id, &camRunAddr, queue, block)
            }
            cameraRunListenerBlock = nil
        }
        watchedCameras.removeAll()

        var audioAddr = Self.audioDevicesAddress
        if let block = audioDevicesListenerBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &audioAddr, queue, block)
            audioDevicesListenerBlock = nil
        }
        var micRunAddr = Self.audioRunningAddress
        if let block = micRunListenerBlock {
            for id in watchedMics {
                AudioObjectRemovePropertyListenerBlock(id, &micRunAddr, queue, block)
            }
            micRunListenerBlock = nil
        }
        watchedMics.removeAll()
    }

    private func rebindCameras() {
        guard let block = cameraRunListenerBlock else { return }
        var runAddr = Self.cmioRunningAddress
        for id in watchedCameras {
            CMIOObjectRemovePropertyListenerBlock(id, &runAddr, queue, block)
        }
        watchedCameras = allCameras()
        for id in watchedCameras {
            CMIOObjectAddPropertyListenerBlock(id, &runAddr, queue, block)
        }
    }

    private func rebindMicrophones() {
        guard let block = micRunListenerBlock else { return }
        var runAddr = Self.audioRunningAddress
        for id in watchedMics {
            AudioObjectRemovePropertyListenerBlock(id, &runAddr, queue, block)
        }
        watchedMics = allMicrophones()
        for id in watchedMics {
            AudioObjectAddPropertyListenerBlock(id, &runAddr, queue, block)
        }
    }

    private func refreshStates() {
        let cam = watchedCameras.contains(where: isCameraRunning)
        let mic = watchedMics.contains(where: isMicrophoneRunning)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.cameraInUse != cam { self.cameraInUse = cam }
            if self.microphoneInUse != mic { self.microphoneInUse = mic }
        }
    }

    private func allCameras() -> [CMIOObjectID] {
        var addr = Self.cmioDevicesAddress
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        var devices = Array(repeating: CMIOObjectID(0), count: count)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &devices) == noErr else {
            return []
        }
        return devices
    }

    private func isCameraRunning(_ id: CMIOObjectID) -> Bool {
        var addr = Self.cmioRunningAddress
        var running: UInt32 = 0
        var used: UInt32 = 0
        let status = CMIOObjectGetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &running)
        return status == noErr && running != 0
    }

    private func allMicrophones() -> [AudioObjectID] {
        var addr = Self.audioDevicesAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var devices = Array(repeating: AudioObjectID(0), count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devices) == noErr else {
            return []
        }
        return devices.filter(hasInputStreams)
    }

    private func hasInputStreams(_ id: AudioObjectID) -> Bool {
        var addr = Self.audioInputStreamsAddress
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }

    private func isMicrophoneRunning(_ id: AudioObjectID) -> Bool {
        var addr = Self.audioRunningAddress
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &running)
        return status == noErr && running != 0
    }
}
