// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation
import Combine
import Foundation

/// Signal types supported by the Acoustic Tone Generator.
enum ToneSignalType: String, CaseIterable, Identifiable {
    case sine = "Sine Wave"
    case sweep = "Frequency Sweep"
    case pinkNoise = "Pink Noise"
    case whiteNoise = "White Noise"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .sine: return "waveform.path"
        case .sweep: return "waveform.badge.magnifyingglass"
        case .pinkNoise: return "waveform.and.person.filled"
        case .whiteNoise: return "chart.bar.xaxis"
        }
    }
}

/// Real-time test tone and noise generator for headphone calibration, room acoustics, and EQ tuning.
final class AudioToneGenerator: ObservableObject {
    static let shared = AudioToneGenerator()

    @Published var isPlaying = false
    @Published var signalType: ToneSignalType = .sine
    @Published var frequency: Double = 1000.0 // 20 Hz - 20,000 Hz
    @Published var sweepProgress: Double = 0.0 // 0.0 - 1.0
    @Published var outputVolume: Double = 0.25 // -12 dB default to avoid loud bursts

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?
    private var sampleRate: Double = 48000.0
    private var phase: Double = 0.0
    private var pinkNoiseState = [Double](repeating: 0.0, count: 7)
    private var sweepTimer: Timer?

    private init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 2) ?? engine.outputNode.outputFormat(forBus: 0)
        self.sampleRate = format.sampleRate
        self.audioFormat = format

        engine.connect(player, to: engine.mainMixerNode, format: format)
        self.audioEngine = engine
        self.playerNode = player
    }

    func togglePlayback() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard let engine = audioEngine, let player = playerNode else { return }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }

        player.play()
        isPlaying = true
        scheduleNextBuffer()

        if signalType == .sweep {
            startSweep()
        }
    }

    func stop() {
        sweepTimer?.invalidate()
        sweepTimer = nil
        sweepProgress = 0.0
        playerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
        phase = 0.0
    }

    private func startSweep() {
        sweepProgress = 0.0
        sweepTimer?.invalidate()
        let duration: Double = 10.0 // 10 second sweep
        let interval: Double = 0.05
        var elapsed: Double = 0.0

        sweepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            elapsed += interval
            let fraction = min(elapsed / duration, 1.0)
            self.sweepProgress = fraction
            let minF = 20.0
            let maxF = 20000.0
            let logMin = log10(minF)
            let logMax = log10(maxF)
            self.frequency = pow(10.0, logMin + fraction * (logMax - logMin))

            if fraction >= 1.0 {
                elapsed = 0.0
            }
        }
    }

    private func scheduleNextBuffer() {
        guard isPlaying, let player = playerNode, let format = audioFormat else { return }

        let frameCount: AVAudioFrameCount = 4096
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount

        let channels = Int(format.channelCount)
        guard let channelData = pcmBuffer.floatChannelData else { return }

        let currentType = signalType
        let currentFreq = frequency
        let currentVol = Float(outputVolume)
        let twoPi = 2.0 * Double.pi
        let sampleRate = self.sampleRate

        for frame in 0..<Int(frameCount) {
            var sample: Float = 0.0

            switch currentType {
            case .sine, .sweep:
                sample = Float(sin(phase)) * currentVol
                phase += twoPi * currentFreq / sampleRate
                if phase >= twoPi { phase -= twoPi }

            case .whiteNoise:
                sample = Float.random(in: -1.0...1.0) * currentVol * 0.5

            case .pinkNoise:
                // Paul Kellet's filtered pink noise generator
                let white = Double.random(in: -1.0...1.0)
                pinkNoiseState[0] = 0.99886 * pinkNoiseState[0] + white * 0.0555179
                pinkNoiseState[1] = 0.99332 * pinkNoiseState[1] + white * 0.0750759
                pinkNoiseState[2] = 0.96900 * pinkNoiseState[2] + white * 0.1538520
                pinkNoiseState[3] = 0.86650 * pinkNoiseState[3] + white * 0.3104856
                pinkNoiseState[4] = 0.55000 * pinkNoiseState[4] + white * 0.5329522
                pinkNoiseState[5] = -0.7616 * pinkNoiseState[5] - white * 0.0168980
                let pink = pinkNoiseState[0] + pinkNoiseState[1] + pinkNoiseState[2] + pinkNoiseState[3] + pinkNoiseState[4] + pinkNoiseState[5] + pinkNoiseState[6] + white * 0.5362
                pinkNoiseState[6] = white * 0.115926
                sample = Float(pink * 0.11) * currentVol
            }

            for ch in 0..<channels {
                channelData[ch][frame] = sample
            }
        }

        player.scheduleBuffer(pcmBuffer, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.scheduleNextBuffer()
            }
        })
    }
}
