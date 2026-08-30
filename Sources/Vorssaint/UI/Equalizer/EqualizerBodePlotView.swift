// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Pro studio interactive Bode plot with real-time FFT spectrum analyzer and draggable filter nodes.
struct EqualizerBodePlotView: View {
    @ObservedObject var equalizer: AudioEqualizerService
    @ObservedObject var spectrum: SpectrumAnalyzerDSP = .shared
    @Binding var selectedBandID: UUID?

    @State private var hoveredBandID: UUID?
    @State private var isDragging = false

    private let minFreq = 20.0
    private let maxFreq = 20000.0
    private let minDB = -24.0
    private let maxDB = 24.0

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
                // Dark Obsidian Glass Canvas Background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.07, blue: 0.11),
                                Color(red: 0.07, green: 0.09, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark), lineWidth: 0.85)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 6)

                // High-Contrast Grid lines & labels
                gridBackground(size: size)
                gridLabels(size: size)

                // Real-Time Neon FFT Spectrum Visualizer
                if equalizer.isEnabled && !equalizer.isBypassed {
                    spectrumVisualizer(size: size)
                }

                // Individual filter curves (subtle dashed traces in parametric mode)
                individualFilterCurves(size: size)

                // Master Composite Frequency Response Curve with liquid gradient & fill
                compositeResponseCurve(size: size)

                // Interactive Draggable Filter Nodes (Parametric mode)
                if equalizer.activeProfile.mode == .parametric {
                    filterNodesOverlay(size: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Grid Background

    private func gridBackground(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let padL: CGFloat = 34
            let padR: CGFloat = 16
            let padT: CGFloat = 18
            let padB: CGFloat = 22
            let contentW = w - padL - padR
            let contentH = h - padT - padB

            // Horizontal dB grid lines
            for db in gridDecibels {
                let y = padT + CGFloat((maxDB - db) / (maxDB - minDB)) * contentH
                var path = Path()
                path.move(to: CGPoint(x: padL, y: y))
                path.addLine(to: CGPoint(x: w - padR, y: y))

                if abs(db) < 0.01 {
                    // 0 dB center reference line
                    context.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1.2)
                } else {
                    context.stroke(path, with: .color(Color.white.opacity(0.08)), style: StrokeStyle(lineWidth: 0.65, dash: [4, 4]))
                }
            }

            // Vertical Frequency grid lines
            for (freq, _) in gridFrequencies {
                let logMin = log10(minFreq)
                let logMax = log10(maxFreq)
                let fraction = CGFloat((log10(freq) - logMin) / (logMax - logMin))
                let x = padL + fraction * contentW

                var path = Path()
                path.move(to: CGPoint(x: x, y: padT))
                path.addLine(to: CGPoint(x: x, y: h - padB))

                context.stroke(path, with: .color(Color.white.opacity(0.08)), style: StrokeStyle(lineWidth: 0.65, dash: [3, 4]))
            }
        }
    }

    // MARK: - Grid Labels

    private func gridLabels(size: CGSize) -> some View {
        let padL: CGFloat = 34
        let padR: CGFloat = 16
        let padT: CGFloat = 18
        let padB: CGFloat = 22
        let contentW = size.width - padL - padR
        let contentH = size.height - padT - padB

        return ZStack(alignment: .topLeading) {
            // Decibel labels on left edge
            ForEach(gridDecibels, id: \.self) { db in
                let y = padT + CGFloat((maxDB - db) / (maxDB - minDB)) * contentH
                Text(String(format: "%+.0f", db))
                    .font(.system(size: 9, weight: abs(db) < 0.01 ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(abs(db) < 0.01 ? Theme.LiquidGlass.cyanGlow : Color.white.opacity(0.45))
                    .frame(width: 28, alignment: .trailing)
                    .position(x: 16, y: y)
            }

            // Frequency labels along bottom edge
            ForEach(gridFrequencies, id: \.0) { freq, label in
                let logMin = log10(minFreq)
                let logMax = log10(maxFreq)
                let fraction = CGFloat((log10(freq) - logMin) / (logMax - logMin))
                let x = padL + fraction * contentW
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .position(x: x, y: size.height - 10)
            }
        }
    }

    // MARK: - Real-Time Neon FFT Spectrum Visualizer

    private func spectrumVisualizer(size: CGSize) -> some View {
        let bins = spectrum.spectrumMagnitudes
        let binCount = bins.count
        guard binCount > 1 else { return AnyView(EmptyView()) }

        let padL: CGFloat = 34
        let padR: CGFloat = 16
        let padT: CGFloat = 18
        let padB: CGFloat = 22
        let contentW = size.width - padL - padR
        let contentH = size.height - padT - padB

        return AnyView(
            Canvas { context, _ in
                var path = Path()
                var firstPoint = true

                for b in 0..<binCount {
                    let fraction = CGFloat(b) / CGFloat(binCount - 1)
                    let x = padL + fraction * contentW
                    let mag = CGFloat(bins[b]) // 0.0 ... 1.0
                    // Map magnitude to dB range: 0.0 = -60dB, 1.0 = +12dB
                    let dbValue = Double(mag * 40.0 - 24.0)
                    let y = padT + CGFloat((maxDB - dbValue) / (maxDB - minDB)) * contentH
                    let clampedY = max(padT, min(size.height - padB, y))

                    if firstPoint {
                        path.move(to: CGPoint(x: x, y: clampedY))
                        firstPoint = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: clampedY))
                    }
                }

                // Closed area fill under the FFT spectrum
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: padL + contentW, y: size.height - padB))
                fillPath.addLine(to: CGPoint(x: padL, y: size.height - padB))
                fillPath.closeSubpath()

                let spectrumGradient = Gradient(colors: [
                    Theme.LiquidGlass.cyanGlow.opacity(0.22),
                    Theme.LiquidGlass.violetGlow.opacity(0.18),
                    Theme.LiquidGlass.magentaGlow.opacity(0.08),
                    Color.clear
                ])

                context.fill(
                    fillPath,
                    with: .linearGradient(
                        spectrumGradient,
                        startPoint: CGPoint(x: padL, y: padT),
                        endPoint: CGPoint(x: padL, y: size.height - padB)
                    )
                )

                // Top neon line
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Theme.LiquidGlass.cyanGlow.opacity(0.8),
                            Theme.LiquidGlass.violetGlow.opacity(0.7),
                            Theme.LiquidGlass.magentaGlow.opacity(0.6)
                        ]),
                        startPoint: CGPoint(x: padL, y: 0),
                        endPoint: CGPoint(x: padL + contentW, y: 0)
                    ),
                    lineWidth: 1.5
                )
            }
        )
    }

    // MARK: - Individual Filter Curves

    private func individualFilterCurves(size: CGSize) -> some View {
        Canvas { context, _ in
            guard equalizer.activeProfile.mode == .parametric else { return }

            let padL: CGFloat = 34
            let padR: CGFloat = 16
            let padT: CGFloat = 18
            let padB: CGFloat = 22
            let contentW = size.width - padL - padR
            let contentH = size.height - padT - padB

            let samplePoints = 120
            let logMin = log10(minFreq)
            let logMax = log10(maxFreq)

            for band in equalizer.activeProfile.bands where band.isEnabled {
                let isSelected = selectedBandID == band.id
                var path = Path()
                var first = true

                for i in 0...samplePoints {
                    let fraction = Double(i) / Double(samplePoints)
                    let freq = pow(10.0, logMin + fraction * (logMax - logMin))
                    let gain = band.magnitudeResponse(atFrequency: freq, sampleRate: 48000.0)

                    let x = padL + CGFloat(fraction) * contentW
                    let y = padT + CGFloat((maxDB - gain) / (maxDB - minDB)) * contentH
                    let clampedY = max(padT, min(size.height - padB, y))

                    if first {
                        path.move(to: CGPoint(x: x, y: clampedY))
                        first = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: clampedY))
                    }
                }

                let color = colorForFilterType(band.type)
                context.stroke(
                    path,
                    with: .color(color.opacity(isSelected ? 0.6 : 0.22)),
                    style: StrokeStyle(lineWidth: isSelected ? 1.5 : 0.8, dash: [4, 3])
                )
            }
        }
    }

    // MARK: - Composite Frequency Response Curve

    private func compositeResponseCurve(size: CGSize) -> some View {
        let profile = equalizer.activeProfile
        let isBypassed = !equalizer.isEnabled || equalizer.isBypassed

        let padL: CGFloat = 34
        let padR: CGFloat = 16
        let padT: CGFloat = 18
        let padB: CGFloat = 22
        let contentW = size.width - padL - padR
        let contentH = size.height - padT - padB
        let zeroY = padT + CGFloat((maxDB - 0.0) / (maxDB - minDB)) * contentH

        let samplePoints = 240
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)

        return Canvas { context, _ in
            var path = Path()
            var first = true

            for i in 0...samplePoints {
                let fraction = Double(i) / Double(samplePoints)
                let freq = pow(10.0, logMin + fraction * (logMax - logMin))

                let totalGain: Double
                if isBypassed {
                    totalGain = 0.0
                } else {
                    totalGain = profile.preamp + profile.compositeMagnitudeResponse(atFrequency: freq, sampleRate: 48000.0)
                }

                let x = padL + CGFloat(fraction) * contentW
                let y = padT + CGFloat((maxDB - totalGain) / (maxDB - minDB)) * contentH
                let clampedY = max(padT, min(size.height - padB, y))

                if first {
                    path.move(to: CGPoint(x: x, y: clampedY))
                    first = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: clampedY))
                }
            }

            // Fill area between curve and 0 dB line
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: padL + contentW, y: zeroY))
            fillPath.addLine(to: CGPoint(x: padL, y: zeroY))
            fillPath.closeSubpath()

            let fillGradient = Gradient(colors: [
                (isBypassed ? Color.gray : Theme.LiquidGlass.cyanGlow).opacity(0.18),
                (isBypassed ? Color.gray : Theme.LiquidGlass.violetGlow).opacity(0.10),
                Color.clear
            ])

            context.fill(
                fillPath,
                with: .linearGradient(
                    fillGradient,
                    startPoint: CGPoint(x: padL, y: padT),
                    endPoint: CGPoint(x: padL, y: size.height - padB)
                )
            )

            // Dynamic Chromatic Neon Stroke
            let strokeGradient = Gradient(colors: isBypassed
                ? [Color.orange.opacity(0.7), Color.orange.opacity(0.7)]
                : [
                    Theme.LiquidGlass.cyanGlow,
                    Theme.LiquidGlass.cyanGlow,
                    Theme.LiquidGlass.violetGlow,
                    Theme.LiquidGlass.magentaGlow
                ]
            )

            context.stroke(
                path,
                with: .linearGradient(
                    strokeGradient,
                    startPoint: CGPoint(x: padL, y: 0),
                    endPoint: CGPoint(x: padL + contentW, y: 0)
                ),
                lineWidth: 2.8
            )
        }
    }

    // MARK: - Interactive Filter Nodes Overlay

    private func filterNodesOverlay(size: CGSize) -> some View {
        let bands = equalizer.activeProfile.bands

        let padL: CGFloat = 34
        let padR: CGFloat = 16
        let padT: CGFloat = 18
        let padB: CGFloat = 22
        let contentW = size.width - padL - padR
        let contentH = size.height - padT - padB

        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)

        return ZStack {
            ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                let fractionX = CGFloat((log10(band.frequency) - logMin) / (logMax - logMin))
                let fractionY = CGFloat((maxDB - band.gain) / (maxDB - minDB))

                let nodeX = padL + fractionX * contentW
                let nodeY = padT + fractionY * contentH

                let isSelected = selectedBandID == band.id
                let isHovered = hoveredBandID == band.id
                let color = colorForFilterType(band.type)

                ZStack {
                    // Floating HUD Tooltip when selected or hovered
                    if isSelected || isHovered {
                        VStack(spacing: 2) {
                            HStack(spacing: 5) {
                                Text(band.type.shortCode)
                                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                    .foregroundStyle(color)
                                Text("•")
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Text("\(Int(band.frequency)) Hz")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white)
                                if band.type.hasGain {
                                    Text("•")
                                        .foregroundStyle(Color.white.opacity(0.4))
                                    Text(String(format: "%+.1f dB", band.gain))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(band.gain > 0.01 ? Theme.LiquidGlass.amberGlow : (band.gain < -0.01 ? Theme.LiquidGlass.cyanGlow : Color.white))
                                }
                                Text("•")
                                    .foregroundStyle(Color.white.opacity(0.4))
                                Text(String(format: "Q:%.2f", band.q))
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.black.opacity(0.85))
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Theme.LiquidGlass.specularGradient(for: .dark).opacity(0.4))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Theme.LiquidGlass.borderGradient(for: .dark, glow: color), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
                        .offset(y: -30)
                    }

                    // Pulsing Ring for active node
                    if isSelected {
                        Circle()
                            .strokeBorder(color.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                            .shadow(color: color.opacity(0.8), radius: 6)
                    }

                    // Glass Handle Body
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(0.9),
                                    color.opacity(0.4),
                                    Color.black.opacity(0.8)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 10
                            )
                        )
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.2)
                        )
                        .shadow(color: color.opacity(0.7), radius: 5)

                    // Band Number
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
                .position(x: nodeX, y: nodeY)
                .contentShape(Circle().size(width: 32, height: 32))
                .onHover { over in
                    withAnimation(.liquidSmooth) {
                        hoveredBandID = over ? band.id : nil
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if selectedBandID != band.id {
                                selectedBandID = band.id
                            }
                            isDragging = true

                            // Calculate new frequency from X
                            let clampedX = max(padL, min(size.width - padR, gesture.location.x))
                            let newFractionX = Double((clampedX - padL) / contentW)
                            let newFreq = pow(10.0, logMin + newFractionX * (logMax - logMin))

                            // Calculate new gain from Y
                            let clampedY = max(padT, min(size.height - padB, gesture.location.y))
                            let newFractionY = Double((clampedY - padT) / contentH)
                            let newGain = maxDB - newFractionY * (maxDB - minDB)

                            equalizer.updateBand(id: band.id) { b in
                                b.frequency = min(maxFreq, max(minFreq, newFreq))
                                if b.type.hasGain {
                                    b.gain = min(maxDB, max(minDB, round(newGain * 10) / 10))
                                }
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
        }
    }

    private func colorForFilterType(_ type: EqualizerFilterType) -> Color {
        switch type {
        case .peaking: return Theme.LiquidGlass.cyanGlow
        case .lowShelf: return Theme.LiquidGlass.amberGlow
        case .highShelf: return Theme.LiquidGlass.violetGlow
        case .highPass: return Theme.LiquidGlass.emeraldGlow
        case .lowPass: return Theme.LiquidGlass.magentaGlow
        case .bandPass: return Color.blue
        case .notch: return Color.red
        case .allPass: return Color.purple
        }
    }
}
