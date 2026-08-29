// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Interactive Bode magnitude response plot with real-time FFT spectrum analyzer and draggable filter nodes.
struct EqualizerBodePlotView: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @ObservedObject var spectrum: SpectrumAnalyzerDSP = .shared
    @Binding var selectedBandID: UUID?

    @State private var hoveredBandID: UUID?
    @State private var dragStartLocation: CGPoint?
    @State private var initialBandFrequency: Double = 1000.0
    @State private var initialBandGain: Double = 0.0

    private let minFreq: Double = 20.0
    private let maxFreq: Double = 20000.0
    private let minDB: Double = -24.0
    private let maxDB: Double = 24.0

    private let gridFrequencies: [(Double, String)] = [
        (20.0, "20"), (50.0, "50"), (100.0, "100"), (200.0, "200"),
        (500.0, "500"), (1000.0, "1k"), (2000.0, "2k"), (5000.0, "5k"),
        (10000.0, "10k"), (20000.0, "20k")
    ]

    private let gridDecibels: [Double] = [24, 18, 12, 6, 0, -6, -12, -18, -24]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // Liquid Glass Background surface
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.LiquidGlass.refractionGradient(for: .dark).opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.85)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)

                // Grid lines & labels
                gridBackground(size: size)

                // Live Neon FFT Spectrum Analyzer overlay
                if equalizer.isEnabled && !equalizer.isBypassed {
                    spectrumVisualizer(size: size)
                }

                // Individual filter curves (faint dashed curves)
                individualFilterCurves(size: size)

                // Combined composite frequency response curve
                compositeResponseCurve(size: size)

                // Draggable filter nodes (Parametric mode)
                if equalizer.activeProfile.mode == .parametric {
                    filterNodesOverlay(size: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(minHeight: 230, maxHeight: 350)
    }

    // MARK: - Grid Background

    private func gridBackground(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Horizontal dB grid lines
            for db in gridDecibels {
                let y = yForDB(db, height: canvasSize.height)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))

                let isCenter = abs(db) < 0.01
                let strokeColor = isCenter ? Color.white.opacity(0.35) : Color.white.opacity(0.07)
                let lineWidth: CGFloat = isCenter ? 1.2 : 0.75
                let style = isCenter ? StrokeStyle(lineWidth: lineWidth) : StrokeStyle(lineWidth: lineWidth, dash: [4, 4])
                context.stroke(path, with: .color(strokeColor), style: style)
            }

            // Vertical Frequency grid lines
            for (freq, _) in gridFrequencies {
                let x = xForFreq(freq, width: canvasSize.width)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                context.stroke(path, with: .color(Color.white.opacity(0.07)), style: StrokeStyle(lineWidth: 0.75, dash: [4, 4]))
            }
        }
        .overlay(gridLabels(size: size))
    }

    private func gridLabels(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            // dB labels on left edge
            ForEach(gridDecibels, id: \.self) { db in
                if db != minDB && db != maxDB {
                    Text(String(format: "%+.0f dB", db))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(db == 0 ? Theme.LiquidGlass.cyanGlow : Color.white.opacity(0.45))
                        .position(x: 28, y: yForDB(db, height: size.height))
                }
            }

            // Frequency labels on bottom edge
            ForEach(gridFrequencies, id: \.0) { freq, label in
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .position(x: xForFreq(freq, width: size.width), y: size.height - 12)
            }
        }
    }

    // MARK: - Spectrum Visualizer

    private func spectrumVisualizer(size: CGSize) -> some View {
        let bins = spectrum.spectrumMagnitudes
        let binCount = bins.count
        return GeometryReader { _ in
            Path { path in
                guard binCount > 0 else { return }
                let stepWidth = size.width / CGFloat(binCount)
                path.move(to: CGPoint(x: 0, y: size.height))

                for i in 0..<binCount {
                    let mag = CGFloat(bins[i])
                    let x = CGFloat(i) * stepWidth + stepWidth * 0.5
                    let y = size.height - (mag * (size.height * 0.85))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.LiquidGlass.cyanGlow.opacity(0.35),
                        Theme.LiquidGlass.violetGlow.opacity(0.22),
                        Theme.LiquidGlass.magentaGlow.opacity(0.10),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .allowsHitTesting(false)
        .animation(.liquidSpring, value: spectrum.spectrumMagnitudes)
    }

    // MARK: - Individual Filter Curves

    private func individualFilterCurves(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            guard equalizer.activeProfile.mode == .parametric else { return }
            let bands = equalizer.activeProfile.bands.filter { $0.isEnabled }

            for band in bands {
                let coeffs = BiquadCoefficients.compute(
                    type: band.type,
                    frequency: band.frequency,
                    gainDB: band.gain,
                    q: band.q,
                    sampleRate: 48000.0
                )

                var path = Path()
                let points = 80
                for i in 0...points {
                    let fraction = Double(i) / Double(points)
                    let logMin = log10(minFreq)
                    let logMax = log10(maxFreq)
                    let f = pow(10.0, logMin + fraction * (logMax - logMin))
                    let db = coeffs.responseGainDB(at: f)
                    let x = CGFloat(fraction) * canvasSize.width
                    let y = yForDB(db, height: canvasSize.height)

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let isSelected = selectedBandID == band.id
                let strokeColor = isSelected ? Theme.LiquidGlass.cyanGlow.opacity(0.9) : Color.white.opacity(0.22)
                context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: isSelected ? 1.6 : 1.0, dash: [3, 3]))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Composite Frequency Response Curve

    private func compositeResponseCurve(size: CGSize) -> some View {
        let profile = equalizer.activeProfile
        let isBypassed = !equalizer.isEnabled || equalizer.isBypassed
        let preamp = isBypassed ? 0.0 : profile.preamp

        // Precompute active filter coefficients
        var activeCoeffs: [BiquadCoefficients] = []
        if !isBypassed {
            if profile.mode == .parametric {
                for band in profile.bands where band.isEnabled {
                    let c = BiquadCoefficients.compute(
                        type: band.type,
                        frequency: band.frequency,
                        gainDB: band.gain,
                        q: band.q,
                        sampleRate: 48000.0
                    )
                    activeCoeffs.append(c)
                }
            } else {
                let freqs = GraphicEqualizerFrequencies.frequencies(for: profile.mode)
                for (index, freq) in freqs.enumerated() {
                    let key = GraphicEqualizerFrequencies.formatFrequency(freq)
                    let gain = profile.graphicGains[key] ?? 0.0
                    if abs(gain) > 0.01 {
                        let type: EqualizerFilterType = (index == 0) ? .lowShelf : (index == freqs.count - 1 ? .highShelf : .peaking)
                        let q: Double = profile.mode == .graphic10 ? 1.41 : (profile.mode == .graphic15 ? 2.15 : 4.31)
                        let c = BiquadCoefficients.compute(type: type, frequency: freq, gainDB: gain, q: q, sampleRate: 48000.0)
                        activeCoeffs.append(c)
                    }
                }
            }
        }

        return Canvas { context, canvasSize in
            let pointsCount = 140
            let logMin = log10(minFreq)
            let logMax = log10(maxFreq)

            var curvePoints: [CGPoint] = []
            for i in 0...pointsCount {
                let fraction = Double(i) / Double(pointsCount)
                let f = pow(10.0, logMin + fraction * (logMax - logMin))
                var totalDB = preamp
                for c in activeCoeffs {
                    totalDB += c.responseGainDB(at: f)
                }
                let x = CGFloat(fraction) * canvasSize.width
                let y = yForDB(totalDB, height: canvasSize.height)
                curvePoints.append(CGPoint(x: x, y: y))
            }

            guard let first = curvePoints.first else { return }

            // Fill under curve with chromatic liquid gradient
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: 0, y: yForDB(0, height: canvasSize.height)))
            fillPath.addLine(to: first)
            for pt in curvePoints.dropFirst() {
                fillPath.addLine(to: pt)
            }
            fillPath.addLine(to: CGPoint(x: canvasSize.width, y: yForDB(0, height: canvasSize.height)))
            fillPath.closeSubpath()

            let fillGradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    Theme.LiquidGlass.cyanGlow.opacity(0.38),
                    Theme.LiquidGlass.violetGlow.opacity(0.20),
                    Color.clear
                ]),
                startPoint: CGPoint(x: canvasSize.width / 2, y: 0),
                endPoint: CGPoint(x: canvasSize.width / 2, y: canvasSize.height)
            )
            context.fill(fillPath, with: fillGradient)

            // Outline curve stroke with glowing neon gradient
            var strokePath = Path()
            strokePath.move(to: first)
            for pt in curvePoints.dropFirst() {
                strokePath.addLine(to: pt)
            }

            let strokeGradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    Theme.LiquidGlass.cyanGlow,
                    Color(red: 0.2, green: 0.8, blue: 0.95),
                    Theme.LiquidGlass.violetGlow,
                    Theme.LiquidGlass.magentaGlow
                ]),
                startPoint: CGPoint(x: 0, y: canvasSize.height / 2),
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height / 2)
            )
            context.stroke(
                strokePath,
                with: strokeGradient,
                style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Interactive Filter Nodes

    private func filterNodesOverlay(size: CGSize) -> some View {
        let bands = equalizer.activeProfile.bands

        return ZStack {
            ForEach(bands) { band in
                let x = xForFreq(band.frequency, width: size.width)
                let y = yForDB(band.gain, height: size.height)
                let isSelected = selectedBandID == band.id
                let isHovered = hoveredBandID == band.id

                ZStack {
                    // Outer neon pulse ring when selected
                    if isSelected {
                        Circle()
                            .stroke(Theme.LiquidGlass.cyanGlow.opacity(0.85), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(Theme.LiquidGlass.cyanGlow.opacity(0.25))
                            )
                            .shadow(color: Theme.LiquidGlass.cyanGlow.opacity(0.8), radius: 8)
                            .animation(.liquidSpring, value: isSelected)
                    }

                    // Node body with specular reflection
                    Circle()
                        .fill(
                            band.isEnabled
                                ? LinearGradient(colors: [Theme.LiquidGlass.cyanGlow, Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.secondary.opacity(0.6), Color.secondary.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: isSelected || isHovered ? 18 : 14, height: isSelected || isHovered ? 18 : 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)

                    // Band number
                    if let index = bands.firstIndex(where: { $0.id == band.id }) {
                        Text("\(index + 1)")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }

                    // Floating Live Tooltip badge when selected or hovered
                    if isSelected || isHovered {
                        VStack(spacing: 1) {
                            Text("\(Int(band.frequency)) Hz")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            Text(String(format: "%+.1f dB", band.gain))
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.black.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(Theme.LiquidGlass.cyanGlow.opacity(0.6), lineWidth: 0.75)
                                )
                        )
                        .offset(y: -28)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .position(x: x, y: y)
                .onHover { hovering in
                    hoveredBandID = hovering ? band.id : nil
                }
                .gesture(
                    TapGesture()
                        .onEnded {
                            selectedBandID = band.id
                        }
                )
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if selectedBandID != band.id {
                                selectedBandID = band.id
                                initialBandFrequency = band.frequency
                                initialBandGain = band.gain
                            }
                            let newX = min(max(value.location.x, 0), size.width)
                            let newY = min(max(value.location.y, 0), size.height)

                            let newFreq = freqForX(newX, width: size.width)
                            let newGain = dbForY(newY, height: size.height)

                            equalizer.updateBand(id: band.id) { b in
                                b.frequency = newFreq
                                if b.type.hasGain {
                                    b.gain = newGain
                                }
                            }
                        }
                )
            }
        }
    }

    // MARK: - Coordinate Math

    private func xForFreq(_ freq: Double, width: CGFloat) -> CGFloat {
        let f = min(max(freq, minFreq), maxFreq)
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let fraction = (log10(f) - logMin) / (logMax - logMin)
        return CGFloat(fraction) * width
    }

    private func freqForX(_ x: CGFloat, width: CGFloat) -> Double {
        let fraction = min(max(Double(x / width), 0.0), 1.0)
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        return pow(10.0, logMin + fraction * (logMax - logMin))
    }

    private func yForDB(_ db: Double, height: CGFloat) -> CGFloat {
        let clamped = min(max(db, minDB), maxDB)
        let fraction = (maxDB - clamped) / (maxDB - minDB)
        return CGFloat(fraction) * (height - 30) + 15
    }

    private func dbForY(_ y: CGFloat, height: CGFloat) -> Double {
        let contentHeight = max(height - 30, 1)
        let fraction = min(max(Double((y - 15) / contentHeight), 0.0), 1.0)
        return maxDB - fraction * (maxDB - minDB)
    }
}
