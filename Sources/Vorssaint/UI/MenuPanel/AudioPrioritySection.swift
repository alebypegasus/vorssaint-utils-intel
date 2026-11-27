// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Audio priority disclosure shown inside the shared audio device card.
/// Contains independent Output and Microphone priority subsections. Each one
/// is a complete ordered list of discovered devices, and its position is the
/// priority used by automatic selection.
struct AudioPriorityDisclosure: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var priority = AudioPriorityService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    private let showsHeader: Bool
    @State private var expanded: Bool

    init(initiallyExpanded: Bool = false, showsHeader: Bool = true) {
        self.showsHeader = showsHeader
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "list.number")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(l10n.s.audioPrioritySection)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n.s.audioPriorityCaption)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    outputPrioritySubsection
                    Divider()
                    inputPrioritySubsection
                }
                .padding(.leading, showsHeader ? 19 : 0)
            }
        }
    }

    // MARK: - Output priority

    private var outputPrioritySubsection: some View {
        VStack(alignment: .leading, spacing: 5) {
            priorityHeader(title: l10n.s.audioPriorityOutputList,
                           systemImage: "speaker.wave.2.fill",
                           enabled: outputPriorityEnabledBinding,
                           help: l10n.s.audioPriorityOutputEnable)
            PriorityDeviceList(
                priorityUIDs: priority.outputPriorityUIDs,
                isAvailable: priority.isOutputAvailable,
                displayName: priority.displayName,
                currentUID: mixer.currentOutputDeviceUID,
                emptyText: l10n.s.mixerSystemOutputNoDevices,
                onMove: { priority.setOutputPriorityUIDs($0) },
                onRemove: { priority.removeOutputPriorityUID($0) },
                latestPriorityUIDs: { priority.outputPriorityUIDs })
        }
    }

    private func priorityHeader(title: String,
                                systemImage: String,
                                enabled: Binding<Bool>,
                                help: String) -> some View {
        HStack(spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Toggle(help, isOn: enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help(help)
                .accessibilityLabel(help)
        }
    }

    // MARK: - Input priority

    private var inputPrioritySubsection: some View {
        VStack(alignment: .leading, spacing: 5) {
            priorityHeader(title: l10n.s.audioPriorityInputList,
                           systemImage: "mic.fill",
                           enabled: inputPriorityEnabledBinding,
                           help: l10n.s.audioPriorityInputEnable)
            PriorityDeviceList(
                priorityUIDs: priority.inputPriorityUIDs,
                isAvailable: priority.isInputAvailable,
                displayName: priority.displayName,
                currentUID: inputManager.currentInputDeviceUID,
                emptyText: l10n.s.mixerInputNoDevices,
                onMove: { priority.setInputPriorityUIDs($0) },
                onRemove: { priority.removeInputPriorityUID($0) },
                latestPriorityUIDs: { priority.inputPriorityUIDs })
        }
    }

    // MARK: - Bindings

    private var outputPriorityEnabledBinding: Binding<Bool> {
        Binding(
            get: { priority.outputPriorityEnabled },
            set: { priority.setOutputPriorityEnabled($0) }
        )
    }

    private var inputPriorityEnabledBinding: Binding<Bool> {
        Binding(
            get: { priority.inputPriorityEnabled },
            set: { priority.setInputPriorityEnabled($0) }
        )
    }
}

private struct PriorityRowHeightsKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// A selected-device priority list. Rows reorder in place using DragGesture
/// rather than a system text drag, so reordering never triggers the Shelf or
/// Dynamic Island drop targets. Disconnected entries remain in their stored
/// position with a remove button; VoiceOver gets matching move actions.
private struct PriorityDeviceList: View {
    @ObservedObject private var l10n = L10n.shared
    let priorityUIDs: [String]
    let isAvailable: (String) -> Bool
    let displayName: (String) -> String?
    let currentUID: String?
    /// A list is only empty while the Mac has no such device.
    let emptyText: String
    let onMove: ([String]) -> Void
    let onRemove: (String) -> Void
    var latestPriorityUIDs: (() -> [String])? = nil

    @State private var draggingUID: String?
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var settling = false
    @State private var livePriorityUIDs: [String]?
    @GestureState private var gestureActive = false
    @State private var rowHeights: [String: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let rowSpacing: CGFloat = 2
    private static let space = "audioPriorityList"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if priorityUIDs.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            } else {
                let uids = priorityUIDs
                let target = proposedIndex(in: uids)
                VStack(spacing: Self.rowSpacing) {
                    ForEach(Array(uids.enumerated()), id: \.element) { index, uid in
                        let isDragged = draggingUID == uid
                        priorityRow(uid: uid, index: index, isDragged: isDragged)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(key: PriorityRowHeightsKey.self,
                                                           value: [uid: proxy.size.height])
                                }
                            )
                            .offset(y: isDragged ? dragTranslation : shift(for: index, target: target, in: uids))
                            .animation(isDragged || reduceMotion ? nil : .easeInOut(duration: 0.15), value: target)
                            .zIndex(isDragged ? 1 : 0)
                            .gesture(reorderGesture(for: uid, index: index, in: uids))
                    }
                }
                .padding(.horizontal, 1)
                .coordinateSpace(name: Self.space)
                .onPreferenceChange(PriorityRowHeightsKey.self) { heights in
                    rowHeights.merge(heights, uniquingKeysWith: { _, new in new })
                }
            }
        }
        .onAppear {
            livePriorityUIDs = priorityUIDs
        }
        .onChange(of: priorityUIDs) { _, updated in
            livePriorityUIDs = updated
        }
        .onChange(of: gestureActive) { _, active in
            guard !active else { return }
            DispatchQueue.main.async {
                if !settling && draggingUID != nil {
                    draggingUID = nil
                    dragTranslation = 0
                }
            }
        }
    }

    private func priorityRow(uid: String, index: Int, isDragged: Bool) -> some View {
        let available = isAvailable(uid)
        let name = displayName(uid) ?? uid
        let isCurrent = uid == currentUID

        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 10.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(available ? .primary : .secondary)
                    if isCurrent {
                        Text(l10n.s.audioPriorityCurrent)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .fixedSize()
                    }
                }
                if !available {
                    Text(l10n.s.audioPriorityUnavailable)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !available {
                Button {
                    onRemove(uid)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(l10n.s.audioPriorityRemove)
                .accessibilityLabel(l10n.s.audioPriorityRemove)
                .accessibilityValue(name)
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .font(.system(size: 9, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            if isDragged {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            }
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isCurrent ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityAction(named: Text(l10n.s.audioPriorityMoveUp)) {
            move(uid, by: -1)
        }
        .accessibilityAction(named: Text(l10n.s.audioPriorityMoveDown)) {
            move(uid, by: 1)
        }
        .contextMenu {
            if !available {
                Button(l10n.s.audioPriorityRemove) { onRemove(uid) }
            }
        }
    }

    // MARK: - In-Place Reorder Dragging

    private func height(of uid: String) -> CGFloat { rowHeights[uid] ?? 34 }

    private func proposedIndex(in uids: [String]) -> Int? {
        guard let draggingUID, uids.indices.contains(dragStartIndex),
              uids[dragStartIndex] == draggingUID else { return nil }
        var target = dragStartIndex
        if dragTranslation > 0 {
            var travelled: CGFloat = 0
            for index in uids.indices where index > dragStartIndex {
                let row = height(of: uids[index])
                guard dragTranslation > travelled + Self.rowSpacing + row / 2 else { break }
                travelled += Self.rowSpacing + row
                target = index
            }
        } else if dragTranslation < 0 {
            var travelled: CGFloat = 0
            for index in uids.indices.reversed() where index < dragStartIndex {
                let row = height(of: uids[index])
                guard -dragTranslation > travelled + Self.rowSpacing + row / 2 else { break }
                travelled += Self.rowSpacing + row
                target = index
            }
        }
        return target
    }

    private func shift(for index: Int, target: Int?, in uids: [String]) -> CGFloat {
        guard let target, let draggingUID, index != dragStartIndex else { return 0 }
        let step = height(of: draggingUID) + Self.rowSpacing
        if dragStartIndex < target, (dragStartIndex + 1...target).contains(index) { return -step }
        if target < dragStartIndex, (target...dragStartIndex - 1).contains(index) { return step }
        return 0
    }

    private func settleOffset(to target: Int, in uids: [String]) -> CGFloat {
        if target > dragStartIndex {
            return uids[(dragStartIndex + 1)...target].reduce(0) { $0 + height(of: $1) + Self.rowSpacing }
        }
        if target < dragStartIndex {
            return -uids[target..<dragStartIndex].reduce(0) { $0 + height(of: $1) + Self.rowSpacing }
        }
        return 0
    }

    private func reorderGesture(for uid: String, index: Int, in uids: [String]) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .updating($gestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard !settling else { return }
                if draggingUID != uid {
                    draggingUID = uid
                    dragStartIndex = index
                }
                dragTranslation = value.translation.height
            }
            .onEnded { _ in
                guard !settling, draggingUID == uid, let target = proposedIndex(in: uids) else { return }
                settling = true
                let start = dragStartIndex
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                    dragTranslation = settleOffset(to: target, in: uids)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        let currentAll = latestPriorityUIDs?() ?? livePriorityUIDs ?? priorityUIDs
                        if target != start, currentAll == uids {
                            var reordered = uids
                            reordered.move(fromOffsets: IndexSet(integer: start),
                                           toOffset: target > start ? target + 1 : target)
                            onMove(reordered)
                        }
                        if draggingUID == uid {
                            draggingUID = nil
                            dragTranslation = 0
                        }
                        settling = false
                    }
                }
            }
    }

    private func move(_ uid: String, by offset: Int) {
        let currentAll = latestPriorityUIDs?() ?? livePriorityUIDs ?? priorityUIDs
        guard let index = currentAll.firstIndex(of: uid) else { return }
        let destination = index + offset
        guard currentAll.indices.contains(destination) else { return }
        var reordered = currentAll
        reordered.swapAt(index, destination)
        onMove(reordered)
    }
}

/// A compact panel section shown when Audio device priority is installed but
/// Volume mixer is not. The complete ordered lists are the control surface;
/// manual Output/Microphone pickers remain part of Volume mixer.
struct AudioPrioritySection: View {
    @ObservedObject private var l10n = L10n.shared
    var collapsible = true

    var body: some View {
        PanelSection(.mixer, title: l10n.s.audioPrioritySection, collapsible: collapsible) {
            AudioPriorityDisclosure(initiallyExpanded: true, showsHeader: false)
                .panelCard()
        }
    }
}
