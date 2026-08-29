// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Shared look & feel: brand colors, card styling and the brand mark.
/// Shared look & feel: brand colors, card styling, Liquid Glass tokens and the brand mark.
enum Theme {
    /// Near-black background behind the brand mark. Neutral greys into black, no
    /// colour cast, with just a hint of depth so the badge does not read as flat.
    static let spaceGradient = LinearGradient(
        colors: [Color(white: 0.10),
                 Color(white: 0.04),
                 Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Liquid Glass macOS Tahoe 26 Palettes
    enum LiquidGlass {
        static let cyanGlow = Color(red: 0.0, green: 0.85, blue: 1.0)
        static let violetGlow = Color(red: 0.65, green: 0.35, blue: 1.0)
        static let magentaGlow = Color(red: 1.0, green: 0.25, blue: 0.75)
        static let emeraldGlow = Color(red: 0.15, green: 0.90, blue: 0.55)
        static let amberGlow = Color(red: 1.0, green: 0.65, blue: 0.15)

        static func specularGradient(for scheme: ColorScheme) -> LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(scheme == .dark ? 0.28 : 0.45), location: 0.0),
                    .init(color: Color.white.opacity(scheme == .dark ? 0.06 : 0.12), location: 0.35),
                    .init(color: Color.clear, location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func borderGradient(for scheme: ColorScheme, glow: Color? = nil) -> LinearGradient {
            let topColor = glow?.opacity(0.6) ?? (scheme == .dark ? Color.white.opacity(0.24) : Color.white.opacity(0.7))
            let bottomColor = glow?.opacity(0.15) ?? (scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08))
            return LinearGradient(
                colors: [topColor, bottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func refractionGradient(for scheme: ColorScheme) -> LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: (scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.6)), location: 0.0),
                    .init(color: (scheme == .dark ? Color.white.opacity(0.02) : Color.white.opacity(0.25)), location: 0.5),
                    .init(color: (scheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.03)), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Fluid Spring Animations
extension Animation {
    /// Quick, highly responsive spring for interactive hover and micro-transitions.
    static var liquidSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0.1)
    }

    /// Smooth, natural spring for panel expansion, view transitions and modal presentation.
    static var liquidSmooth: Animation {
        .spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.15)
    }

    /// Bouncy spring for toggles, pills, and tactile controls.
    static var liquidBouncy: Animation {
        .spring(response: 0.35, dampingFraction: 0.62, blendDuration: 0.1)
    }
}

enum PanelMetricColor {
    static func green(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.44, blue: 0.18) : .green
    }

    static func cyan(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.43, blue: 0.54) : .cyan
    }

    static func mint(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.44, blue: 0.40) : .mint
    }

    static func yellow(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.56, green: 0.36, blue: 0.00) : .yellow
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.08, blue: 0.10) : .red
    }

    static func orange(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.30, blue: 0.00) : .orange
    }

    static func pink(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.06, blue: 0.34) : .pink
    }
}

enum PanelSurface {
    static func baseFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.68) : Color.black.opacity(0.42)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white.opacity(0.42) : Color.white.opacity(0.08)
    }

    static func controlFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.055) : Color.white.opacity(0.085)
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.09) : Color.white.opacity(0.11)
    }
}

func sectionTitle(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 10, weight: .semibold))
        .kerning(0.6)
        .foregroundStyle(.secondary)
}

extension View {
    /// The rounded card background used by panel sections and tool cards.
    func panelCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(PanelCardModifier(cornerRadius: cornerRadius))
    }

    /// Liquid Glass Tahoe 26 Card Surface.
    func liquidGlassCard(cornerRadius: CGFloat = 12, glow: Color? = nil, isHovered: Bool = false) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, glow: glow, isHovered: isHovered))
    }

    /// Liquid Glass Capsule Pill.
    func liquidGlassCapsule(glow: Color? = nil, isSelected: Bool = false) -> some View {
        modifier(LiquidGlassCapsuleModifier(glow: glow, isSelected: isSelected))
    }

    /// A restrained glass base for the menu panel: translucent with stable tint.
    func panelGlassSurface(cornerRadius: CGFloat = 18) -> some View {
        background(PanelGlassSurface(cornerRadius: cornerRadius))
    }
}

private struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(11)
            .background(
                ZStack {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.14) : Color(white: 0.94))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.LiquidGlass.refractionGradient(for: colorScheme))
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.LiquidGlass.specularGradient(for: colorScheme))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 8, x: 0, y: 4)
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 12
    var glow: Color? = nil
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.92))
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.LiquidGlass.refractionGradient(for: colorScheme))
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.LiquidGlass.specularGradient(for: colorScheme))
                    }

                    if let glow = glow, isHovered {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(glow.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme, glow: isHovered ? glow : nil), lineWidth: 0.8)
            )
            .shadow(color: (glow ?? Color.black).opacity(isHovered ? 0.25 : (colorScheme == .dark ? 0.20 : 0.05)),
                    radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.liquidSpring, value: isHovered)
    }
}

private struct LiquidGlassCapsuleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var glow: Color? = nil
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(isSelected ? (glow?.opacity(0.22) ?? Color.accentColor.opacity(0.2)) : Color.primary.opacity(0.06))
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.7))
                    }
                }
            )
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Theme.LiquidGlass.borderGradient(for: colorScheme, glow: isSelected ? (glow ?? Color.accentColor) : nil),
                        lineWidth: isSelected ? 1.0 : 0.65
                    )
            )
            .shadow(color: isSelected ? (glow ?? Color.accentColor).opacity(0.3) : Color.clear, radius: 6, x: 0, y: 2)
    }
}

private struct PanelGlassSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = true
    let cornerRadius: CGFloat

    var body: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), liquidGlassEnabled, !reduceTransparency {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.LiquidGlass.refractionGradient(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.LiquidGlass.specularGradient(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.8)
                )
        } else {
            standardSurface
        }
#else
        standardSurface
#endif
    }

    @ViewBuilder
    private var standardSurface: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.LiquidGlass.refractionGradient(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.LiquidGlass.specularGradient(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 16, x: 0, y: 8)
    }
}

func appDelegate() -> AppDelegate? {
    NSApp.delegate as? AppDelegate
}

/// The official mark (Resources/Brand/logo.png, trimmed at build time),
/// tintable for light or dark surfaces.
struct BrandMark: View {
    var width: CGFloat
    var tint: Color = .white

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .renderingMode(.template)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: width)
        } else {
            Image(systemName: "circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: width * 0.5)
        }
    }
}

struct DiscordMark: View {
    var width: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "discord-symbol",
                                        withExtension: "svg",
                                        subdirectory: "Images") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        }
    }
}

/// Squircle badge with the mark on the space gradient — the app's face in the
/// About tab and onboarding.
struct BrandBadge: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Theme.spaceGradient)
            BrandMark(width: size * 0.8)
        }
        .frame(width: size, height: size)
    }
}
