// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Ultra-premium Liquid Glass Radial Menu for macOS with dynamic illumination,
/// tactile 3D glass chips, precision HUD sectors, and responsive spring physics.
struct RadialMenuView: View {
    @ObservedObject private var service = RadialMenuService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = true

    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var items: [RadialMenuItem] { service.stack.last ?? [] }
    private var profileColor: Color {
        service.activeProfile?.color.color(for: colorScheme) ?? Theme.LiquidGlass.cyanGlow
    }

    var body: some View {
        ZStack {
            // 1. Ambient Outer Aura
            Circle()
                .fill(profileColor.opacity(colorScheme == .light ? 0.12 : 0.22))
                .frame(width: RadialMenuLayout.wheelDiameter + 30, height: RadialMenuLayout.wheelDiameter + 30)
                .blur(radius: 20)

            // 2. Liquid Glass Multi-Layer Backplate Disc
            backplate

            // 3. Spoke Sector Divider Lines
            spokeDividers

            // 4. Luminous Highlighted Wedge
            if let index = service.highlightedIndex, items.indices.contains(index) {
                highlightedWedge(for: index)
            }

            // 5. Action Chips Ring
            ring.id(service.stack.count)

            // 6. Floating Crystal Core Hub
            hub
        }
        .frame(width: RadialMenuLayout.panelSize, height: RadialMenuLayout.panelSize)
        .contentShape(Rectangle())
        .onTapGesture { service.activatePointer() }
        .scaleEffect(service.visible ? 1 : (reduceMotion ? 1 : 0.85))
        .opacity(service.visible ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.24, dampingFraction: 0.78),
                   value: service.visible)
        .accessibilityLabel(text.pageTitle)
    }

    // MARK: - Liquid Glass Backplate

    @ViewBuilder
    private var backplate: some View {
        let isLight = colorScheme == .light

        ZStack {
            // Base Frosted Backdrop
            HUDBackdrop(cornerRadius: RadialMenuLayout.wheelDiameter / 2, contrast: isLight ? .standard : .high)
                .frame(width: RadialMenuLayout.wheelDiameter, height: RadialMenuLayout.wheelDiameter)
                .clipShape(Circle())

            // Surface Tint
            Circle()
                .fill(
                    RadialGradient(
                        colors: isLight ? [
                            Color.white.opacity(0.65),
                            Color(red: 0.94, green: 0.96, blue: 0.99).opacity(0.75)
                        ] : [
                            Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.85),
                            Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0.92)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: RadialMenuLayout.wheelDiameter / 2
                    )
                )
                .frame(width: RadialMenuLayout.wheelDiameter, height: RadialMenuLayout.wheelDiameter)

            // Outer Specular Top Sheen
            Circle()
                .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.45))
                .frame(width: RadialMenuLayout.wheelDiameter, height: RadialMenuLayout.wheelDiameter)

            // Inner Ring Accent Track
            Circle()
                .strokeBorder(
                    Color.primary.opacity(0.06),
                    lineWidth: 1
                )
                .frame(width: RadialMenuLayout.ringRadius * 2, height: RadialMenuLayout.ringRadius * 2)

            // Dual Perimeter Glass Bevel Borders
            Circle()
                .strokeBorder(Theme.LiquidGlass.borderGradient(for: colorScheme, glow: profileColor.opacity(0.5)), lineWidth: 1.2)
                .frame(width: RadialMenuLayout.wheelDiameter, height: RadialMenuLayout.wheelDiameter)

            Circle()
                .strokeBorder(Color.white.opacity(isLight ? 0.6 : 0.15), lineWidth: 0.7)
                .frame(width: RadialMenuLayout.wheelDiameter - 3, height: RadialMenuLayout.wheelDiameter - 3)
        }
        .shadow(color: Color.black.opacity(isLight ? 0.16 : 0.55), radius: 24, y: 8)
    }

    // MARK: - Sector Spoke Dividers

    private var spokeDividers: some View {
        Canvas { context, size in
            let count = items.count
            guard count > 1 else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let innerR = RadialMenuLayout.deadZoneRadius + 6
            let outerR = RadialMenuLayout.wheelDiameter / 2 - 6
            let step = 2.0 * .pi / Double(count)

            let strokeColor = (colorScheme == .light ? Color.black : Color.white).opacity(0.08)

            for i in 0..<count {
                let angle = Double(i) * step - .pi / 2 + (step / 2)
                let p1 = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * innerR,
                    y: center.y + CGFloat(sin(angle)) * innerR
                )
                let p2 = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * outerR,
                    y: center.y + CGFloat(sin(angle)) * outerR
                )

                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)

                context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .frame(width: RadialMenuLayout.panelSize, height: RadialMenuLayout.panelSize)
    }

    // MARK: - Highlighted Wedge

    private func highlightedWedge(for index: Int) -> some View {
        let count = items.count
        let centerAngle = 2 * .pi * Double(index) / Double(count)
        let sliceAngle = 2 * .pi / Double(count)
        let innerR = RadialMenuLayout.deadZoneRadius + 2
        let outerR = RadialMenuLayout.wheelDiameter / 2 - 2

        return ZStack {
            // 1. Radial Glow Fill
            RadialWedgeShape(
                centerAngle: centerAngle,
                sliceAngle: sliceAngle,
                innerRadius: innerR,
                outerRadius: outerR
            )
            .fill(
                RadialGradient(
                    colors: [
                        profileColor.opacity(colorScheme == .light ? 0.35 : 0.42),
                        profileColor.opacity(colorScheme == .light ? 0.15 : 0.22),
                        profileColor.opacity(0.02)
                    ],
                    center: .center,
                    startRadius: innerR,
                    endRadius: outerR
                )
            )

            // 2. Glowing Outer Arc Rim
            RadialArcRimShape(
                centerAngle: centerAngle,
                sliceAngle: sliceAngle,
                radius: outerR - 1
            )
            .stroke(
                LinearGradient(
                    colors: [
                        profileColor.opacity(0.2),
                        profileColor,
                        profileColor.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
            .shadow(color: profileColor.opacity(0.85), radius: 6)
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: index)
    }

    // MARK: - Action Chips Ring

    private var ring: some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            let unit = RadialMenuGeometry.unitPosition(index: index, itemCount: items.count)
            RadialChipView(
                item: item,
                name: item.displayName(text, nowPlayingState: service.nowPlayingState),
                nowPlayingState: service.nowPlayingState,
                highlighted: service.highlightedIndex == index,
                reduceMotion: reduceMotion,
                profileColor: profileColor
            )
            .offset(x: unit.dx * RadialMenuLayout.ringRadius,
                    y: -unit.dyUp * RadialMenuLayout.ringRadius)
            .accessibilityLabel(item.displayName(text, nowPlayingState: service.nowPlayingState))
        }
    }

    // MARK: - Floating Crystal Core Hub

    private var hub: some View {
        let isLight = colorScheme == .light

        return ZStack {
            // Core Lens Glass Disc
            Circle()
                .fill(
                    isLight
                        ? Color.white.opacity(0.85)
                        : Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
                )
                .overlay(
                    Circle()
                        .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(0.5))
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            service.highlightedIndex != nil
                                ? Theme.LiquidGlass.borderGradient(for: colorScheme, glow: profileColor)
                                : Theme.LiquidGlass.borderGradient(for: colorScheme),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(isLight ? 0.12 : 0.4), radius: 10, y: 3)

            // Core Content
            if let index = service.highlightedIndex, items.indices.contains(index) {
                let item = items[index]
                VStack(spacing: 2) {
                    // Category Badge
                    Text(itemCategoryBadge(item))
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(profileColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(profileColor.opacity(0.15))
                        .clipShape(Capsule())

                    // Action Name
                    Text(item.displayName(text, nowPlayingState: service.nowPlayingState))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isLight ? Color.primary : Color.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let parent = service.trail.last {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.backward.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(profileColor)
                    Text(parent.isEmpty ? text.kindSubmenu : parent)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
                .accessibilityLabel(text.backButton)
            } else {
                // Idle Brand Orb
                ZStack {
                    Circle()
                        .fill(profileColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .blur(radius: 6)
                    BrandMark(width: 32, tint: isLight ? Color(red: 0.1, green: 0.12, blue: 0.18) : Color.white)
                }
            }
        }
        .frame(width: RadialMenuLayout.hubDiameter + 6, height: RadialMenuLayout.hubDiameter + 6)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: service.highlightedIndex)
    }

    private func itemCategoryBadge(_ item: RadialMenuItem) -> String {
        switch item.kind {
        case .app: return "APP"
        case .file: return "FILE"
        case .url: return "WEB"
        case .shortcut: return "HOTKEY"
        case .tool: return "TOOL"
        case .quickToggle: return "TOGGLE"
        case .windowLayout: return "LAYOUT"
        case .media: return "MEDIA"
        case .submenu: return "MENU"
        }
    }
}

// MARK: - Tactile Liquid Glass Action Chip

private struct RadialChipView: View {
    let item: RadialMenuItem
    let name: String
    let nowPlayingState: RadialNowPlayingState
    let highlighted: Bool
    let reduceMotion: Bool
    let profileColor: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isLight = colorScheme == .light

        ZStack {
            // Chip Glass Orb Body
            Circle()
                .fill(
                    highlighted
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    profileColor,
                                    profileColor.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(
                            isLight
                                ? Color.white.opacity(0.85)
                                : Color(red: 0.12, green: 0.15, blue: 0.22).opacity(0.85)
                        )
                )
                .overlay(
                    Circle()
                        .fill(Theme.LiquidGlass.specularGradient(for: colorScheme).opacity(highlighted ? 0.6 : 0.35))
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            highlighted
                                ? Color.white.opacity(0.9)
                                : Color.white.opacity(isLight ? 0.7 : 0.15),
                            lineWidth: highlighted ? 1.5 : 0.85
                        )
                )
                .shadow(
                    color: highlighted ? profileColor.opacity(0.85) : Color.black.opacity(isLight ? 0.12 : 0.35),
                    radius: highlighted ? 10 : 5,
                    y: highlighted ? 0 : 2
                )

            // High-Resolution Icon Content
            icon
        }
        .frame(width: RadialMenuLayout.chipSize, height: RadialMenuLayout.chipSize)
        .scaleEffect(highlighted && !reduceMotion ? 1.18 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: highlighted)
    }

    @ViewBuilder
    private var icon: some View {
        if item.mediaKey == .nowPlaying {
            if case let .playing(snapshot) = nowPlayingState,
               let icon = RadialNowPlayingApplication.icon(for: snapshot) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(highlighted ? Color.white : profileColor)
            }
        } else if item.symbolName.isEmpty, let customImage = RadialMenuIconStore.customIcon(for: item) {
            Image(nsImage: customImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else if item.usesFileIcon {
            Image(nsImage: RadialMenuIconStore.fileIcon(for: item.payload))
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
        } else {
            Image(systemName: item.effectiveSymbolName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    highlighted
                        ? AnyShapeStyle(Color.white)
                        : (colorScheme == .light ? AnyShapeStyle(Color(red: 0.1, green: 0.14, blue: 0.22)) : AnyShapeStyle(Color.white.opacity(0.9)))
                )
                .shadow(color: highlighted ? Color.black.opacity(0.3) : Color.clear, radius: 2)
        }
    }
}

// MARK: - Radial Geometric Shapes

/// A slice-shaped highlight between the hub and the wheel border.
struct RadialWedgeShape: Shape {
    let centerAngle: Double
    let sliceAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Angle(radians: centerAngle - sliceAngle / 2 - .pi / 2)
        let end = Angle(radians: centerAngle + sliceAngle / 2 - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: innerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: outerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// An outer glowing arc rim for the active slice.
struct RadialArcRimShape: Shape {
    let centerAngle: Double
    let sliceAngle: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Angle(radians: centerAngle - sliceAngle / 2 - .pi / 2)
        let end = Angle(radians: centerAngle + sliceAngle / 2 - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }
}

/// Real icons and display names for slices that point at the disk.
enum RadialMenuIconStore {
    private static var icons: [String: NSImage] = [:]
    private static var names: [String: String] = [:]
    private static var customIcons: [UUID: NSImage] = [:]

    static func fileIcon(for payload: String) -> NSImage {
        if let cached = icons[payload] { return cached }
        let path = (payload as NSString).expandingTildeInPath
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        icons[payload] = icon
        return icon
    }

    static func customIcon(for item: RadialMenuItem) -> NSImage? {
        guard let data = item.customIconData else { return nil }
        if let cached = customIcons[item.id] { return cached }
        guard let image = NSImage(data: data) else { return nil }
        image.size = NSSize(width: 32, height: 32)
        customIcons[item.id] = image
        return image
    }

    static func fileName(for payload: String) -> String {
        if let cached = names[payload] { return cached }
        let path = (payload as NSString).expandingTildeInPath
        let name = FileManager.default.displayName(atPath: path)
        names[payload] = name
        return name
    }

    static func invalidate(_ payload: String) {
        icons.removeValue(forKey: payload)
        names.removeValue(forKey: payload)
    }

    static func invalidate(item: RadialMenuItem) {
        icons.removeValue(forKey: item.payload)
        names.removeValue(forKey: item.payload)
        customIcons.removeValue(forKey: item.id)
    }
}

/// Name resolution shared by the wheel and the Settings editor.
extension RadialMenuItem {
    func displayName(_ text: RadialMenuFeatureStrings,
                     nowPlayingState: RadialNowPlayingState? = nil) -> String {
        if !name.isEmpty { return name }
        switch kind {
        case .app, .file:
            return RadialMenuIconStore.fileName(for: payload)
        case .url:
            let normalized = RadialMenuSupport.normalizedURL(payload) ?? payload
            return URL(string: normalized)?.host ?? payload
        case .shortcut:
            return GlobalShortcut(storageValue: payload)?.displayString ?? text.kindShortcut
        case .tool:
            guard let tool else { return text.kindTool }
            return tool.feature.hubTitle(L10n.shared.s, hub: FeatureStrings.hub(L10n.shared.language))
        case .quickToggle:
            return quickToggle?.radialTitle ?? FeatureStrings.quickToggles(L10n.shared.language).pageTitle
        case .windowLayout:
            guard let windowLayoutAction else {
                return FeatureStrings.windowLayout(L10n.shared.language).title
            }
            return windowLayoutAction.title(FeatureStrings.windowLayout(L10n.shared.language))
        case .media:
            switch mediaKey {
            case .playPause: return text.mediaPlayPause
            case .previousTrack: return text.mediaPrevious
            case .nextTrack: return text.mediaNext
            case .nowPlaying:
                switch nowPlayingState {
                case let .some(.playing(snapshot)): return snapshot.radialLabel ?? text.mediaNowPlaying
                case .some(.nothingPlaying): return text.mediaNothingPlaying
                case .some(.loading), .none: return text.mediaNowPlaying
                }
            case nil: return text.kindMedia
            }
        case .submenu:
            return text.kindSubmenu
        }
    }

    var usesFileIcon: Bool {
        (kind == .app || kind == .file) && symbolName.isEmpty
    }
}

extension RadialMenuQuickToggle {
    var radialTitle: String {
        let strings = FeatureStrings.quickToggles(L10n.shared.language)
        let toggles = QuickTogglesService.shared
        switch self {
        case .darkMode:
            return toggles.systemAppearanceIsDark == true ? strings.darkModeToLight : strings.darkModeToDark
        case .emptyTrash: return strings.emptyTrashTitle
        case .ejectDisks: return strings.ejectTitle
        case .hiddenFiles: return toggles.hiddenFilesShown ? strings.hiddenFilesHide : strings.hiddenFilesShow
        case .desktopIcons: return toggles.desktopIconsShown ? strings.desktopIconsHide : strings.desktopIconsShow
        case .lockScreen: return strings.lockScreenTitle
        case .displayOff: return strings.displayOffTitle
        case .screenSaver: return strings.screenSaverTitle
        }
    }
}
