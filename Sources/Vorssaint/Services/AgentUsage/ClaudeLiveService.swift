// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation
import Network

/// Local-only HTTP hook receiver (`127.0.0.1:47615/vorssaint-hook`) for Claude Code.
/// Streams live tool steps, todo progress, permission/plan prompts and completion
/// summaries directly into the Dynamic Island without leaving the Mac.
final class ClaudeLiveService: ObservableObject {
    static let shared = ClaudeLiveService()

    @Published private(set) var sessions: [ClaudeLiveSession] = []
    @Published private(set) var asks: [ClaudeLiveAsk] = []
    @Published private(set) var listening = false
    @Published private(set) var lastSummary: (sessionID: String, text: String)?

    private var listener: NWListener?
    private var waiting: [String: (Data) -> Void] = [:]
    private var pruneTimer: Timer?

    static var answersInNotch: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.claudeLiveAnswerInNotch) as? Bool ?? true
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.claudeLiveEnabled)
    }

    func syncWithPreferences() {
        if NotchSupport.isEnabled() && NotchAgentSupport.isEnabled() && isEnabled {
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard listener == nil, isEnabled else { return }
        guard let port = NWEndpoint.Port(rawValue: ClaudeLiveConstants.defaultPort) else { return }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)
        parameters.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: parameters) else { return }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.listening = true
                case .failed, .cancelled:
                    self.listening = false
                    self.listener = nil
                default:
                    break
                }
            }
        }
        listener.start(queue: .main)
        self.listener = listener
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.prune()
        }
        RunLoop.main.add(timer, forMode: .common)
        pruneTimer = timer
    }

    func stop() {
        listener?.cancel()
        listener = nil
        pruneTimer?.invalidate()
        pruneTimer = nil
        for (_, reply) in waiting {
            reply(Data("{}".utf8))
        }
        waiting.removeAll()
        asks.removeAll()
        listening = false
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var next = buffer
            if let data { next.append(data) }
            guard next.count < (4 << 20) else { connection.cancel(); return }
            if let request = ClaudeLiveHTTPRequest(next) {
                self.handle(request, connection: connection)
            } else if complete || error != nil {
                connection.cancel()
            } else {
                self.receive(connection, buffer: next)
            }
        }
    }

    private func respond(_ connection: NWConnection, status: String = "200 OK", body: Data = Data("{}".utf8)) {
        let head: String
        if body.isEmpty {
            head = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        } else {
            head = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        }
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private struct Context {
        let configDir: String
        let bundleID: String
        let term: String
    }

    private func handle(_ request: ClaudeLiveHTTPRequest, connection: NWConnection) {
        guard request.method == "POST", request.path.hasPrefix(ClaudeLiveConstants.hookPath) else {
            respond(connection, status: "404 Not Found", body: Data())
            return
        }
        guard request.headers["x-vorssaint-token"] == ClaudeLiveConstants.token() else {
            respond(connection, status: "403 Forbidden", body: Data())
            return
        }
        guard let json = (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any],
              let event = json["hook_event_name"] as? String else {
            respond(connection)
            return
        }
        let context = Context(
            configDir: request.headers["x-claude-config"] ?? "",
            bundleID: request.headers["x-bundle"] ?? "",
            term: request.headers["x-term"] ?? ""
        )
        if event == "PermissionRequest", let ask = record(permission: json, context: context) {
            waiting[ask.id] = { [weak self] body in
                self?.respond(connection, body: body)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + ClaudeLiveConstants.askHold) { [weak self] in
                self?.answer(ask.id, allow: nil)
            }
            return
        }
        apply(event: event, json: json, context: context)
        respond(connection)
    }

    private func sessionIndex(for json: [String: Any], context: Context) -> Int {
        let id = json["session_id"] as? String ?? "unknown"
        let cwd = json["cwd"] as? String ?? ""
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].lastEvent = Date()
            if !cwd.isEmpty {
                sessions[index].cwd = cwd
                sessions[index].project = URL(fileURLWithPath: cwd).lastPathComponent
            }
            if !context.bundleID.isEmpty { sessions[index].bundleID = context.bundleID }
            if !context.term.isEmpty { sessions[index].termProgram = context.term }
            return index
        }
        let project = cwd.isEmpty ? "Claude" : URL(fileURLWithPath: cwd).lastPathComponent
        sessions.append(ClaudeLiveSession(
            id: id,
            project: project,
            cwd: cwd,
            account: ClaudeLiveFormatter.accountName(context.configDir),
            bundleID: context.bundleID.isEmpty ? nil : context.bundleID,
            termProgram: context.term.isEmpty ? nil : context.term
        ))
        return sessions.count - 1
    }

    private func apply(event: String, json: [String: Any], context: Context) {
        let index = sessionIndex(for: json, context: context)
        var session = sessions[index]
        switch event {
        case "SessionStart":
            session.status = .idle
        case "UserPromptSubmit":
            session.status = .working
            session.promptStarted = Date()
            session.edits = 0
            session.commands = 0
            session.step = "Thinking"
            session.stepSymbol = "brain"
        case "PreToolUse":
            session.status = .working
            if session.promptStarted == nil { session.promptStarted = Date() }
            let toolName = json["tool_name"] as? String ?? ""
            let (step, symbol) = ClaudeLiveFormatter.describe(tool: toolName, input: json["tool_input"] as? [String: Any] ?? [:])
            session.step = step
            session.stepSymbol = symbol
            switch toolName {
            case "Edit", "Write", "MultiEdit", "NotebookEdit": session.edits += 1
            case "Bash": session.commands += 1
            default: break
            }
        case "PostToolUse":
            if json["tool_name"] as? String == "TodoWrite",
               let todos = (json["tool_input"] as? [String: Any])?["todos"] as? [[String: Any]] {
                session.todosTotal = todos.count
                session.todosDone = todos.filter { $0["status"] as? String == "completed" }.count
                session.currentTodo = (todos.first { $0["status"] as? String == "in_progress" }?["activeForm"] as? String)
                    ?? (todos.first { $0["status"] as? String == "in_progress" }?["content"] as? String)
            }
        case "Notification":
            let type = json["notification_type"] as? String ?? ""
            let inputTypes = ["permission_prompt", "idle_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input"]
            if inputTypes.contains(type) {
                let wasWaiting = session.status == .waiting
                session.status = .waiting
                let shown = asks.contains { $0.sessionID == session.id }
                if !shown, !wasWaiting {
                    let message = json["message"] as? String ?? "Claude needs your input"
                    sessions[index] = session
                    present(ClaudeLiveAsk(
                        id: "note." + UUID().uuidString,
                        sessionID: session.id,
                        tool: type == "idle_prompt" ? "Waiting" : "Input",
                        summary: message,
                        project: session.project,
                        account: session.account,
                        created: Date(),
                        answerable: false
                    ))
                    return
                }
            }
        case "Stop":
            session.status = .done
            session.lastMessage = (json["last_assistant_message"] as? String).map(ClaudeLiveFormatter.firstLine)
            let summary = ClaudeLiveFormatter.summary(session)
            sessions[index] = session
            lastSummary = (session.id, summary)
            asks.removeAll { $0.sessionID == session.id && !$0.answerable }
            NotchService.shared.presentClaudeLiveFinished(
                project: session.project,
                summary: summary.isEmpty ? (session.lastMessage ?? "Done") : summary
            )
            return
        case "SessionEnd":
            sessions.remove(at: index)
            asks.removeAll { $0.sessionID == session.id && !$0.answerable }
            return
        default:
            break
        }
        sessions[index] = session
    }

    private func record(permission json: [String: Any], context: Context) -> ClaudeLiveAsk? {
        let index = sessionIndex(for: json, context: context)
        sessions[index].status = .waiting
        let tool = json["tool_name"] as? String ?? "Tool"
        let input = json["tool_input"] as? [String: Any] ?? [:]
        var ask = ClaudeLiveAsk(
            id: UUID().uuidString,
            sessionID: sessions[index].id,
            tool: tool,
            summary: ClaudeLiveFormatter.describe(tool: tool, input: input, long: true).0,
            project: sessions[index].project,
            account: sessions[index].account,
            created: Date(),
            answerable: Self.answersInNotch
        )
        ask.input = (try? JSONSerialization.data(withJSONObject: input)) ?? Data()
        if tool == "AskUserQuestion" {
            ask.questions = (input["questions"] as? [[String: Any]] ?? []).prefix(4).map { question in
                ClaudeLiveQuestion(
                    question: question["question"] as? String ?? "",
                    header: question["header"] as? String ?? "",
                    options: (question["options"] as? [[String: Any]] ?? []).compactMap { $0["label"] as? String },
                    multiSelect: question["multiSelect"] as? Bool ?? false
                )
            }
        }
        if tool == "ExitPlanMode" {
            ask.plan = input["plan"] as? String ?? ""
        }
        present(ask)
        return ask.answerable ? ask : nil
    }

    private func present(_ ask: ClaudeLiveAsk) {
        asks.append(ask)
        NotchService.shared.presentClaudeLiveAsk(ask)
    }

    func answer(_ id: String, choices: [String: String]) {
        guard let ask = asks.first(where: { $0.id == id }) else { return }
        var input = (try? JSONSerialization.jsonObject(with: ask.input)) as? [String: Any] ?? [:]
        input["answers"] = choices
        answer(id, allow: true, updatedInput: input)
    }

    func approvePlan(_ id: String, _ approve: Bool) {
        guard let ask = asks.first(where: { $0.id == id }) else { return }
        let input = (try? JSONSerialization.jsonObject(with: ask.input)) as? [String: Any] ?? [:]
        if approve {
            answer(id, allow: true, updatedInput: input)
        } else {
            answer(id, allow: false, message: "Not approved yet: keep planning and refine the plan.")
        }
    }

    func answer(_ id: String, allow: Bool?, updatedInput: [String: Any]? = nil, message: String? = nil) {
        if let ask = asks.first(where: { $0.id == id }),
           let index = sessions.firstIndex(where: { $0.id == ask.sessionID }) {
            sessions[index].status = allow == nil ? .waiting : .working
        }
        asks.removeAll { $0.id == id }
        if let reply = waiting.removeValue(forKey: id) {
            if let allow {
                var decision: [String: Any] = ["behavior": allow ? "allow" : "deny"]
                if !allow { decision["message"] = message ?? "Denied from Dynamic Island." }
                if allow, let updatedInput { decision["updatedInput"] = updatedInput }
                let body: [String: Any] = [
                    "hookSpecificOutput": [
                        "hookEventName": "PermissionRequest",
                        "decision": decision,
                    ],
                ]
                reply((try? JSONSerialization.data(withJSONObject: body)) ?? Data("{}".utf8))
            } else {
                reply(Data("{}".utf8))
            }
        }
        NotchService.shared.claudeLiveAskResolved(id, next: asks.first)
    }

    func dismiss(_ id: String) {
        if waiting[id] != nil {
            answer(id, allow: nil)
        } else {
            asks.removeAll { $0.id == id }
            NotchService.shared.claudeLiveAskResolved(id, next: asks.first)
        }
    }

    func focus(_ sessionID: String) {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return }
        var bundle = session.bundleID
        if bundle == nil {
            switch session.termProgram {
            case "vscode": bundle = "com.microsoft.VSCode"
            case "iTerm.app": bundle = "com.googlecode.iterm2"
            case "Apple_Terminal": bundle = "com.apple.Terminal"
            case "WarpTerminal": bundle = "dev.warp.Warp-Stable"
            case "ghostty": bundle = "com.mitchellh.ghostty"
            default: break
            }
        }
        guard let bundle,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { return }
        app.activate()
    }

    private func prune() {
        let now = Date()
        sessions.removeAll { now.timeIntervalSince($0.lastEvent) > ($0.status == .working ? 3600 : 1800) }
    }
}
