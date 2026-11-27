// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum NotchClaudeStyle {
    static let accent = Color(red: 0.85, green: 0.47, blue: 0.34)

    static func color(_ status: ClaudeLiveSession.Status) -> Color {
        switch status {
        case .working: return Color(red: 0.45, green: 0.86, blue: 0.62)
        case .waiting: return .orange
        case .idle: return .white.opacity(0.35)
        case .done: return Color(red: 0.49, green: 0.72, blue: 1)
        }
    }
}

private struct NotchClaudeBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(NotchClaudeStyle.accent.opacity(0.28), in: Capsule())
            .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.68))
            .lineLimit(1)
    }
}

/// Interactive card rendered inside the expanded Dynamic Island when Claude Code
/// requests tool permission, presents a plan for approval, or asks a multiple-choice question.
struct NotchClaudeAskOverlay: View {
    let ask: ClaudeLiveAsk
    let close: () -> Void
    @ObservedObject private var live = ClaudeLiveService.shared

    var body: some View {
        Group {
            if ask.answerable, let plan = ask.plan {
                planCard(plan: plan)
            } else if ask.answerable, !ask.questions.isEmpty {
                NotchClaudeQuestionCard(ask: ask, close: close)
            } else {
                permissionCard
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(symbol: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NotchClaudeStyle.accent)
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(1)
            NotchClaudeBadge(text: ask.account)
            Spacer(minLength: 4)
            Text(ask.project)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    private func planCard(plan: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            header(symbol: "list.bullet.clipboard", title: "Claude’s plan")
            ScrollView {
                Text(Self.planText(plan))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 8) {
                actionChip("Open", symbol: "arrow.up.forward.app") {
                    live.focus(ask.sessionID)
                    close()
                }
                Spacer()
                actionChip("Keep planning", symbol: "arrow.uturn.backward") {
                    live.approvePlan(ask.id, false)
                }
                actionChip("Approve", symbol: "checkmark", prominent: true) {
                    live.approvePlan(ask.id, true)
                }
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(symbol: "hand.raised.fill",
                   title: ask.answerable ? "Claude wants to use \(ask.tool)" : "Claude needs you")
            Text(ask.summary)
                .font(.system(size: 12, design: ask.tool == "Bash" ? .monospaced : .default))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                actionChip("Open", symbol: "arrow.up.forward.app") {
                    live.focus(ask.sessionID)
                    close()
                }
                Spacer()
                if ask.answerable {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(ClaudeLiveConstants.askHold - context.date.timeIntervalSince(ask.created)))
                        Text("\(left)s")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    actionChip("Deny", symbol: "xmark") {
                        live.answer(ask.id, allow: false)
                    }
                    actionChip("Allow", symbol: "checkmark", prominent: true) {
                        live.answer(ask.id, allow: true)
                    }
                } else {
                    actionChip("Dismiss", symbol: "xmark") {
                        live.dismiss(ask.id)
                        close()
                    }
                }
            }
        }
    }

    private func actionChip(_ title: String, symbol: String, prominent: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(prominent ? NotchClaudeStyle.accent.opacity(0.85) : .white.opacity(0.12), in: Capsule())
                .foregroundStyle(.white)
                .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 14))
    }

    static func planText(_ plan: String) -> AttributedString {
        var result = AttributedString()
        for (index, raw) in plan.components(separatedBy: "\n").enumerated() {
            var line = raw
            var heading = false
            while line.hasPrefix("#") {
                line.removeFirst()
                heading = true
            }
            if heading {
                line = line.trimmingCharacters(in: .whitespaces)
            }
            var piece = (try? AttributedString(markdown: line,
                                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                ?? AttributedString(line)
            if heading {
                piece.font = .system(size: 12.5, weight: .bold)
            }
            if index > 0 { result += AttributedString("\n") }
            result += piece
        }
        return result
    }
}

private struct NotchClaudeQuestionCard: View {
    let ask: ClaudeLiveAsk
    let close: () -> Void
    @ObservedObject private var live = ClaudeLiveService.shared
    @State private var page = 0
    @State private var picked: [Int: Set<String>] = [:]

    var body: some View {
        let question = ask.questions[min(page, ask.questions.count - 1)]
        let chosen = picked[page] ?? []
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(NotchClaudeStyle.accent)
                Text(question.header.isEmpty ? "Claude asks" : question.header)
                    .font(.system(size: 13, weight: .semibold))
                NotchClaudeBadge(text: ask.account)
                Spacer()
                if ask.questions.count > 1 {
                    Text("\(page + 1)/\(ask.questions.count)")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Text(question.question)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(question.options, id: \.self) { option in
                        let on = chosen.contains(option)
                        Button {
                            var set = chosen
                            if question.multiSelect {
                                if on { set.remove(option) } else { set.insert(option) }
                            } else {
                                set = [option]
                            }
                            picked[page] = set
                            if !question.multiSelect { advance() }
                        } label: {
                            Text(option)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(on ? NotchClaudeStyle.accent.opacity(0.85) : .white.opacity(0.12), in: Capsule())
                                .foregroundStyle(.white)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(NotchButtonStyle(cornerRadius: 14))
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Answer in Claude instead") {
                    live.answer(ask.id, allow: nil)
                    live.focus(ask.sessionID)
                    close()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if question.multiSelect {
                    Button("Next") { advance() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .disabled(chosen.isEmpty)
                }
            }
        }
    }

    private func advance() {
        if page + 1 < ask.questions.count {
            withAnimation(.smooth(duration: 0.25)) { page += 1 }
            return
        }
        var answers: [String: String] = [:]
        for (index, question) in ask.questions.enumerated() {
            let set = picked[index] ?? []
            answers[question.question] = question.options.filter(set.contains).joined(separator: ", ")
        }
        live.answer(ask.id, choices: answers)
    }
}

/// Live Claude Code sessions strip embedded in the AI Agents Dynamic Island page.
struct NotchClaudeLiveSection: View {
    @ObservedObject private var live = ClaudeLiveService.shared

    var body: some View {
        if !live.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchClaudeStyle.accent)
                    Text("Claude Code Live")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
                ForEach(live.sessions.sorted { $0.lastEvent > $1.lastEvent }.prefix(3)) { session in
                    row(session)
                }
            }
            .padding(8)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func row(_ session: ClaudeLiveSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NotchClaudeStyle.color(session.status))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(session.project)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    NotchClaudeBadge(text: session.account)
                }
                HStack(spacing: 4) {
                    Image(systemName: session.status == .waiting ? "hand.raised" : session.stepSymbol)
                        .font(.system(size: 9.5))
                    Text(session.status == .waiting ? "Waiting for you"
                         : session.status == .done ? (session.lastMessage ?? "Done")
                         : (session.currentTodo ?? session.step))
                        .font(.system(size: 10.5))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.65))
                if session.todosTotal > 0 {
                    GeometryReader { proxy in
                        Capsule().fill(.white.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Capsule().fill(NotchClaudeStyle.accent)
                                    .frame(width: proxy.size.width * CGFloat(session.todosDone) / CGFloat(max(1, session.todosTotal)))
                            }
                    }
                    .frame(height: 3)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if session.todosTotal > 0 {
                    Text("\(session.todosDone)/\(session.todosTotal)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                }
                if let elapsed = session.elapsed, session.status == .working {
                    Text(ClaudeLiveFormatter.duration(elapsed))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Button { live.focus(session.id) } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10.5, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 12))
            .help("Bring window forward")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contextMenu {
            Button("Bring window forward") { live.focus(session.id) }
            if !session.cwd.isEmpty {
                Button("Show project in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: session.cwd)])
                }
                if let code = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
                    Button("Open project in VS Code") {
                        NSWorkspace.shared.open([URL(fileURLWithPath: session.cwd)], withApplicationAt: code,
                                                configuration: NSWorkspace.OpenConfiguration())
                    }
                }
                Button("Copy project path") { copy(session.cwd) }
            }
            if let message = session.lastMessage {
                Button("Copy Claude’s last message") { copy(message) }
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
