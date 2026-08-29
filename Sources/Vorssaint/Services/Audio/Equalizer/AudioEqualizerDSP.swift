// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Accelerate
import CoreAudio
import Foundation

/// Normalized biquad filter coefficients: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
struct BiquadCoefficients: Equatable {
    var b0: Float = 1.0
    var b1: Float = 0.0
    var b2: Float = 0.0
    var a1: Float = 0.0
    var a2: Float = 0.0

    /// Neutral passthrough filter.
    static let identity = BiquadCoefficients()

    /// Computes coefficients using Robert Bristow-Johnson Audio EQ Cookbook formulas.
    static func compute(type: EqualizerFilterType,
                        frequency: Double,
                        gainDB: Double,
                        q: Double,
                        sampleRate: Double) -> BiquadCoefficients {
        let fs = max(sampleRate, 8000.0)
        let f0 = min(max(frequency, 10.0), fs * 0.499)
        let Q = max(q, 0.05)
        let A = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * f0 / fs
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * Q)

        var b0_d: Double = 1.0
        var b1_d: Double = 0.0
        var b2_d: Double = 0.0
        var a0_d: Double = 1.0
        var a1_d: Double = 0.0
        var a2_d: Double = 0.0

        switch type {
        case .peaking:
            b0_d = 1.0 + alpha * A
            b1_d = -2.0 * cosW0
            b2_d = 1.0 - alpha * A
            a0_d = 1.0 + alpha / A
            a1_d = -2.0 * cosW0
            a2_d = 1.0 - alpha / A

        case .lowShelf:
            let sqrtA = sqrt(A)
            let twoSqrtAAlpha = 2.0 * sqrtA * alpha
            b0_d = A * ((A + 1.0) - (A - 1.0) * cosW0 + twoSqrtAAlpha)
            b1_d = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosW0)
            b2_d = A * ((A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha)
            a0_d = (A + 1.0) + (A - 1.0) * cosW0 + twoSqrtAAlpha
            a1_d = -2.0 * ((A - 1.0) + (A + 1.0) * cosW0)
            a2_d = (A + 1.0) + (A - 1.0) * cosW0 - twoSqrtAAlpha

        case .highShelf:
            let sqrtA = sqrt(A)
            let twoSqrtAAlpha = 2.0 * sqrtA * alpha
            b0_d = A * ((A + 1.0) + (A - 1.0) * cosW0 + twoSqrtAAlpha)
            b1_d = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW0)
            b2_d = A * ((A + 1.0) + (A - 1.0) * cosW0 - twoSqrtAAlpha)
            a0_d = (A + 1.0) - (A - 1.0) * cosW0 + twoSqrtAAlpha
            a1_d = 2.0 * ((A - 1.0) - (A + 1.0) * cosW0)
            a2_d = (A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha

        case .lowPass:
            b0_d = (1.0 - cosW0) / 2.0
            b1_d = 1.0 - cosW0
            b2_d = (1.0 - cosW0) / 2.0
            a0_d = 1.0 + alpha
            a1_d = -2.0 * cosW0
            a2_d = 1.0 - alpha

        case .highPass:
            b0_d = (1.0 + cosW0) / 2.0
            b1_d = -(1.0 + cosW0)
            b2_d = (1.0 + cosW0) / 2.0
            a0_d = 1.0 + alpha
            a1_d = -2.0 * cosW0
            a2_d = 1.0 - alpha

        case .bandPass:
            b0_d = alpha
            b1_d = 0.0
            b2_d = -alpha
            a0_d = 1.0 + alpha
            a1_d = -2.0 * cosW0
            a2_d = 1.0 - alpha

        case .notch:
            b0_d = 1.0
            b1_d = -2.0 * cosW0
            b2_d = 1.0
            a0_d = 1.0 + alpha
            a1_d = -2.0 * cosW0
            a2_d = 1.0 - alpha

        case .allPass:
            b0_d = 1.0 - alpha
            b1_d = -2.0 * cosW0
            b2_d = 1.0 + alpha
            a0_d = 1.0 + alpha
            a1_d = -2.0 * cosW0
            a2_d = 1.0 - alpha
        }

        guard a0_d != 0.0 else { return .identity }
        let invA0 = 1.0 / a0_d
        return BiquadCoefficients(
            b0: Float(b0_d * invA0),
            b1: Float(b1_d * invA0),
            b2: Float(b2_d * invA0),
            a1: Float(a1_d * invA0),
            a2: Float(a2_d * invA0)
        )
    }

    /// Evaluates the frequency response magnitude in dB at target frequency `f` (Hz).
    func responseGainDB(at frequency: Double, sampleRate: Double = 48000.0) -> Double {
        let w = 2.0 * Double.pi * frequency / sampleRate
        let cosW = cos(w)
        let cos2W = cos(2.0 * w)
        let sinW = sin(w)
        let sin2W = sin(2.0 * w)

        let numReal = Double(b0) + Double(b1) * cosW + Double(b2) * cos2W
        let numImag = -Double(b1) * sinW - Double(b2) * sin2W
        let denReal = 1.0 + Double(a1) * cosW + Double(a2) * cos2W
        let denImag = -Double(a1) * sinW - Double(a2) * sin2W

        let numMag2 = numReal * numReal + numImag * numImag
        let denMag2 = denReal * denReal + denImag * denImag

        guard denMag2 > 1e-12, numMag2 > 1e-12 else { return 0.0 }
        let gainSquared = numMag2 / denMag2
        return 10.0 * log10(gainSquared)
    }
}

/// Single-channel Direct Form II Transposed biquad filter.
struct BiquadFilter {
    var coeffs: BiquadCoefficients = .identity
    var z1: Float = 0.0
    var z2: Float = 0.0

    mutating func reset() {
        z1 = 0.0
        z2 = 0.0
    }

    /// Processes a single sample in-place.
    @inline(__always)
    mutating func processSample(_ x: Float) -> Float {
        let y = coeffs.b0 * x + z1
        z1 = coeffs.b1 * x - coeffs.a1 * y + z2
        z2 = coeffs.b2 * x - coeffs.a2 * y
        // Underflow / denormal protection
        if abs(z1) < 1e-15 { z1 = 0.0 }
        if abs(z2) < 1e-15 { z2 = 0.0 }
        return y
    }
}

/// Real-time Equalizer DSP Instance containing filter cascades for stereo audio channels.
final class EqualizerDSPInstance {
    private var leftFilters: [BiquadFilter] = []
    private var rightFilters: [BiquadFilter] = []
    private var isBypassed: Bool = false
    private var preampLinear: Float = 1.0
    private var sampleRate: Double = 48000.0

    // Lock-free double-buffering configuration lock
    private let configLock = os_unfair_lock_t.allocate(capacity: 1)

    init() {
        configLock.initialize(to: os_unfair_lock())
    }

    deinit {
        configLock.deinitialize(count: 1)
        configLock.deallocate()
    }

    /// Updates filter coefficients and preamp for the DSP engine.
    func update(profile: EqualizerProfile, isBypassed: Bool, sampleRate: Double) {
        self.sampleRate = sampleRate > 0 ? sampleRate : 48000.0
        let preampDB = profile.preamp
        let preampScale = Float(pow(10.0, preampDB / 20.0))

        var newLeft: [BiquadFilter] = []
        var newRight: [BiquadFilter] = []

        if profile.mode == .parametric {
            for band in profile.bands where band.isEnabled {
                let coeffs = BiquadCoefficients.compute(
                    type: band.type,
                    frequency: band.frequency,
                    gainDB: band.gain,
                    q: band.q,
                    sampleRate: self.sampleRate
                )
                let filter = BiquadFilter(coeffs: coeffs, z1: 0, z2: 0)
                switch band.channel {
                case .stereo:
                    newLeft.append(filter)
                    newRight.append(filter)
                case .left:
                    newLeft.append(filter)
                case .right:
                    newRight.append(filter)
                }
            }
        } else {
            // Graphic EQ mode: map graphic faders to peaking/shelf biquad filters
            let freqs = GraphicEqualizerFrequencies.frequencies(for: profile.mode)
            for (index, freq) in freqs.enumerated() {
                let key = GraphicEqualizerFrequencies.formatFrequency(freq)
                let gain = profile.graphicGains[key] ?? 0.0
                if abs(gain) > 0.01 {
                    let type: EqualizerFilterType
                    let q: Double
                    if index == 0 {
                        type = .lowShelf
                        q = 0.71
                    } else if index == freqs.count - 1 {
                        type = .highShelf
                        q = 0.71
                    } else {
                        type = .peaking
                        // ISO 10-band: Q ≈ 1.41, 15-band: Q ≈ 2.15, 31-band: Q ≈ 4.31
                        switch profile.mode {
                        case .graphic10: q = 1.41
                        case .graphic15: q = 2.15
                        case .graphic31: q = 4.31
                        case .parametric: q = 1.41
                        }
                    }
                    let coeffs = BiquadCoefficients.compute(
                        type: type,
                        frequency: freq,
                        gainDB: gain,
                        q: q,
                        sampleRate: self.sampleRate
                    )
                    let filter = BiquadFilter(coeffs: coeffs, z1: 0, z2: 0)
                    newLeft.append(filter)
                    newRight.append(filter)
                }
            }
        }

        os_unfair_lock_lock(configLock)
        self.preampLinear = preampScale
        self.isBypassed = isBypassed
        self.leftFilters = newLeft
        self.rightFilters = newRight
        os_unfair_lock_unlock(configLock)
    }

    /// Realtime audio thread buffer processing (in-place on interleaved stereo float samples).
    func processInterleavedStereo(_ samples: UnsafeMutablePointer<Float>, frames: Int) {
        guard frames > 0 else { return }

        // If lock cannot be taken instantly, keep processing with current filters
        let hasLock = os_unfair_lock_trylock(configLock)
        defer {
            if hasLock { os_unfair_lock_unlock(configLock) }
        }

        guard !isBypassed else { return }

        let preamp = preampLinear
        let leftCount = leftFilters.count
        let rightCount = rightFilters.count

        if leftCount == 0 && rightCount == 0 {
            if abs(preamp - 1.0) > 1e-4 {
                var p = preamp
                vDSP_vsmul(samples, 1, &p, samples, 1, vDSP_Length(frames * 2))
            }
            return
        }

        var base = 0
        for _ in 0..<frames {
            var left = samples[base] * preamp
            var right = samples[base + 1] * preamp

            for i in 0..<leftCount {
                left = leftFilters[i].processSample(left)
            }
            for i in 0..<rightCount {
                right = rightFilters[i].processSample(right)
            }

            samples[base] = left
            samples[base + 1] = right
            base += 2
        }
    }

    /// Realtime audio thread processing across an AudioBufferList.
    func processAudioBufferList(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
        guard frames > 0 else { return }
        guard !isBypassed else { return }

        if buffers.count == 1, buffers[0].mNumberChannels == 2,
           let samples = buffers[0].mData?.assumingMemoryBound(to: Float.self) {
            processInterleavedStereo(samples, frames: frames)
        } else if buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
            let hasLock = os_unfair_lock_trylock(configLock)
            defer {
                if hasLock { os_unfair_lock_unlock(configLock) }
            }
            let preamp = preampLinear
            let leftCount = leftFilters.count
            let rightCount = rightFilters.count

            for f in 0..<frames {
                var l = left[f] * preamp
                var r = right[f] * preamp
                for i in 0..<leftCount { l = leftFilters[i].processSample(l) }
                for i in 0..<rightCount { r = rightFilters[i].processSample(r) }
                left[f] = l
                right[f] = r
            }
        }
    }
}

/// Real-time spectrum analyzer for visualizer UI (calculates FFT magnitudes from live audio).
final class SpectrumAnalyzerDSP: ObservableObject {
    static let shared = SpectrumAnalyzerDSP()

    static let fftSize = 1024
    static let log2N = vDSP_Length(10)
    static let binCount = 32

    @Published private(set) var spectrumMagnitudes: [Float] = Array(repeating: 0.0, count: binCount)
    @Published private(set) var peakLevelL: Float = 0.0
    @Published private(set) var peakLevelR: Float = 0.0
    @Published private(set) var isClipping: Bool = false

    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var inputBuffer: [Float]
    private var smoothedMagnitudes: [Float]
    private var currentPeakL: Float = 0.0
    private var currentPeakR: Float = 0.0
    private var clipHoldUntil: CFAbsoluteTime = 0
    private let sampleQueue = DispatchQueue(label: "com.vorssaint.utils.equalizer.spectrum", qos: .userInteractive)
    private var pendingFrames: [Float] = []
    private var lastPublishTime: CFAbsoluteTime = 0

    init() {
        window = [Float](repeating: 0, count: Self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        inputBuffer = [Float](repeating: 0, count: Self.fftSize)
        smoothedMagnitudes = [Float](repeating: 0, count: Self.binCount)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.fftSize), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    /// Feeds output samples from the audio render callback to compute the real-time spectrum and stereo peak levels.
    func feedSamples(_ samples: UnsafePointer<Float>, frameCount: Int, channels: Int) {
        guard frameCount > 0, channels > 0 else { return }

        // Compute peak levels
        var maxL: Float = 0.0
        var maxR: Float = 0.0
        let stride = channels
        let checkCount = min(frameCount, 512)

        for i in 0..<checkCount {
            let sL = abs(samples[i * stride])
            if sL > maxL { maxL = sL }
            if channels > 1 {
                let sR = abs(samples[i * stride + 1])
                if sR > maxR { maxR = sR }
            } else {
                maxR = maxL
            }
        }

        // Downmix to mono and copy into lightweight array
        var mono = [Float](repeating: 0, count: checkCount)
        for i in 0..<checkCount {
            mono[i] = channels > 1 ? (samples[i * stride] + samples[i * stride + 1]) * 0.5 : samples[i * stride]
        }

        sampleQueue.async { [weak self] in
            self?.processAudioMetrics(mono: mono, peakL: maxL, peakR: maxR)
        }
    }

    private func processAudioMetrics(mono: [Float], peakL: Float, peakR: Float) {
        // Smooth peak decay
        currentPeakL = max(peakL, currentPeakL * 0.82)
        currentPeakR = max(peakR, currentPeakR * 0.82)

        let now = CFAbsoluteTimeGetCurrent()
        if peakL >= 0.99 || peakR >= 0.99 {
            clipHoldUntil = now + 1.2 // Hold clip indicator for 1.2s
        }

        pendingFrames.append(contentsOf: mono)
        guard pendingFrames.count >= Self.fftSize else { return }

        let activeWindow = Array(pendingFrames.suffix(Self.fftSize))
        pendingFrames.removeAll(keepingCapacity: true)

        guard let setup = fftSetup else { return }

        var windowedInput = [Float](repeating: 0, count: Self.fftSize)
        vDSP_vmul(activeWindow, 1, window, 1, &windowedInput, 1, vDSP_Length(Self.fftSize))

        var realIn = windowedInput
        var imagIn = [Float](repeating: 0, count: Self.fftSize)
        var realOut = [Float](repeating: 0, count: Self.fftSize)
        var imagOut = [Float](repeating: 0, count: Self.fftSize)

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        var magnitudes = [Float](repeating: 0, count: Self.fftSize / 2)
        realOut.withUnsafeMutableBufferPointer { rBuf in
            imagOut.withUnsafeMutableBufferPointer { iBuf in
                guard let rPtr = rBuf.baseAddress, let iPtr = iBuf.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: rPtr, imagp: iPtr)
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(Self.fftSize / 2))
            }
        }

        // Group FFT bins logarithmically into 32 display bins
        var newBins = [Float](repeating: 0, count: Self.binCount)
        let minFreq = 20.0
        let maxFreq = 20000.0
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)

        for b in 0..<Self.binCount {
            let logLow = logMin + (logMax - logMin) * (Double(b) / Double(Self.binCount))
            let logHigh = logMin + (logMax - logMin) * (Double(b + 1) / Double(Self.binCount))
            let fLow = pow(10.0, logLow)
            let fHigh = pow(10.0, logHigh)

            let binLow = max(1, Int(fLow / (48000.0 / Double(Self.fftSize))))
            let binHigh = min(Self.fftSize / 2 - 1, max(binLow + 1, Int(fHigh / (48000.0 / Double(Self.fftSize)))))

            var sum: Float = 0
            var count = 0
            for k in binLow..<binHigh {
                sum += magnitudes[k]
                count += 1
            }
            let avg = count > 0 ? sum / Float(count) : 0
            // Normalize and map to 0.0 ... 1.0 with dB curve
            let db = 20.0 * log10(max(avg, 1e-5))
            let normalized = max(0.0, min(1.0, (db + 60.0) / 60.0))
            newBins[b] = Float(normalized)
        }

        // Smooth with decay
        for b in 0..<Self.binCount {
            let target = newBins[b]
            if target > smoothedMagnitudes[b] {
                smoothedMagnitudes[b] = target // Fast attack
            } else {
                smoothedMagnitudes[b] = smoothedMagnitudes[b] * 0.75 + target * 0.25 // Smooth decay
            }
        }

        if now - lastPublishTime >= 0.033 { // ~30 fps UI refresh limit
            lastPublishTime = now
            let result = smoothedMagnitudes
            let pL = min(1.0, currentPeakL)
            let pR = min(1.0, currentPeakR)
            let clipping = now < clipHoldUntil
            DispatchQueue.main.async {
                self.spectrumMagnitudes = result
                self.peakLevelL = pL
                self.peakLevelR = pR
                self.isClipping = clipping
            }
        }
    }
}
