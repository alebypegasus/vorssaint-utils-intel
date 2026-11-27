// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Models, HTTP parser, tool formatter, and settings.json hook installer for
/// Claude Code's local HTTP hooks. Pure Foundation so tests exercise every contract
/// without opening sockets.
struct ClaudeLiveSession: Identifiable, Equatable {
    enum Status: Equatable { case working, waiting, idle, done }

    let id: String
    var project: String
    var cwd: String
    var account: String
    var status: Status = .idle
    var step = ""
    var stepSymbol = "sparkles"
    var todosDone = 0
    var todosTotal = 0
    var currentTodo: String?
    var promptStarted: Date?
    var lastEvent = Date()
    var edits = 0
    var commands = 0
    var lastMessage: String?
    /// The app the session runs in, to bring it forward.
    var bundleID: String?
    var termProgram: String?

    var elapsed: TimeInterval? { promptStarted.map { Date().timeIntervalSince($0) } }
}

struct ClaudeLiveQuestion: Equatable {
    let question: String
    let header: String
    let options: [String]
    let multiSelect: Bool
}

struct ClaudeLiveAsk: Identifiable, Equatable {
    let id: String
    let sessionID: String
    let tool: String
    let summary: String
    let project: String
    let account: String
    let created: Date
    /// Whether the session waits for the island's answer; a notice only otherwise.
    let answerable: Bool
    /// Claude asking the user to choose (`AskUserQuestion`).
    var questions: [ClaudeLiveQuestion] = []
    /// A plan waiting for approval (`ExitPlanMode`).
    var plan: String?
    /// The tool's input payload as sent, for answers that return `updatedInput`.
    var input: Data = Data()
}

/// Minimal HTTP/1.1 request parser for local Claude Code hook POSTs.
struct ClaudeLiveHTTPRequest: Equatable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    init?(_ data: Data) {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<end.lowerBound], encoding: .utf8) else { return nil }
        var lines = head.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let first = lines.removeFirst().split(separator: " ")
        guard first.count >= 2 else { return nil }
        method = String(first[0])
        path = String(first[1])
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        self.headers = headers
        let length = max(0, Int(headers["content-length"] ?? "0") ?? 0)
        let bodyStart = end.upperBound
        guard data.count - bodyStart >= length else { return nil }
        body = data.subdata(in: bodyStart..<(bodyStart + length))
    }
}

enum ClaudeLiveConstants {
    static let defaultPort: UInt16 = 47615
    static let hookPath = "/vorssaint-hook"
    /// How long a permission prompt waits for the island before falling back to Claude Code.
    static let askHold: TimeInterval = 25

    /// A per-Mac secret sent by the hooks so unrelated local processes cannot spoof events.
    static func token(in defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: DefaultsKey.claudeLiveToken), saved.count >= 32 {
            return saved
        }
        let fresh = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
        defaults.set(fresh, forKey: DefaultsKey.claudeLiveToken)
        return fresh
    }
}

enum ClaudeLiveFormatter {
    static func accountName(_ configDir: String) -> String {
        let trimmed = configDir.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "main" }
        let name = URL(fileURLWithPath: trimmed).lastPathComponent
        if name.hasPrefix(".claude-") { return String(name.dropFirst(8)) }
        return name == ".claude" ? "main" : name
    }

    static func firstLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return String(line.prefix(140))
    }

    static func summary(_ session: ClaudeLiveSession) -> String {
        var parts: [String] = []
        if let elapsed = session.elapsed { parts.append(duration(elapsed)) }
        if session.edits > 0 { parts.append("\(session.edits) edit\(session.edits == 1 ? "" : "s")") }
        if session.commands > 0 { parts.append("\(session.commands) command\(session.commands == 1 ? "" : "s")") }
        if session.todosTotal > 0 { parts.append("\(session.todosDone)/\(session.todosTotal) todos") }
        return parts.joined(separator: " · ")
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \(s / 60 % 60)m"
    }

    static func describe(tool: String, input: [String: Any], long: Bool = false) -> (String, String) {
        func file(_ key: String) -> String {
            let path = input[key] as? String ?? ""
            return long ? path : URL(fileURLWithPath: path).lastPathComponent
        }
        func clip(_ text: String, _ limit: Int) -> String {
            let line = text.replacingOccurrences(of: "\n", with: " ")
            return line.count > limit ? String(line.prefix(max(1, limit - 1))) + "…" : line
        }
        switch tool {
        case "Edit", "MultiEdit": return ("Editing " + file("file_path"), "pencil")
        case "Write": return ("Writing " + file("file_path"), "doc.badge.plus")
        case "NotebookEdit": return ("Editing " + file("notebook_path"), "pencil")
        case "Read": return ("Reading " + file("file_path"), "doc.text.magnifyingglass")
        case "Bash":
            let command = input["command"] as? String ?? ""
            let description = input["description"] as? String
            return (long ? clip(command, 220) : clip(description ?? command, 46), "terminal")
        case "Grep": return ("Searching “\(clip(input["pattern"] as? String ?? "", 30))”", "magnifyingglass")
        case "Glob": return ("Finding files", "folder")
        case "WebFetch":
            let host = (input["url"] as? String).flatMap { URL(string: $0)?.host } ?? "the web"
            return ("Reading " + clip(host, 40), "globe")
        case "WebSearch": return ("Searching the web", "globe")
        case "TodoWrite": return ("Updating the plan", "checklist")
        case "Task", "Agent": return ("Running an agent", "person.2")
        default:
            if tool.hasPrefix("mcp__") {
                let parts = tool.split(separator: "_").filter { !$0.isEmpty }
                return ("Using " + (parts.dropFirst().first.map(String.init) ?? "a tool"), "puzzlepiece")
            }
            return (tool.isEmpty ? "Working" : "Using " + tool, "hammer")
        }
    }
}

/// Adds or removes HTTP hooks in a Claude Code account's `settings.json`,
/// preserving a one-time `settings.json.vorssaint-backup` copy before first edit.
enum ClaudeLiveInstaller {
    static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "Notification", "PermissionRequest", "Stop", "SessionEnd",
    ]

    static func settingsURL(for profile: ClaudeAccountProfile,
                            home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        profile.configurationURL(home: home).appending(path: "settings.json")
    }

    static func isConnected(_ profile: ClaudeAccountProfile,
                            home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        guard let data = try? Data(contentsOf: settingsURL(for: profile, home: home)),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains(ClaudeLiveConstants.hookPath)
    }

    private static func isOurs(_ entry: Any) -> Bool {
        guard let entry = entry as? [String: Any], let hooks = entry["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { ($0["url"] as? String)?.contains(ClaudeLiveConstants.hookPath) == true }
    }

    @discardableResult
    static func connect(_ profile: ClaudeAccountProfile, _ on: Bool,
                        home: URL = FileManager.default.homeDirectoryForCurrentUser,
                        defaults: UserDefaults = .standard) -> Bool {
        let url = settingsURL(for: profile, home: home)
        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            guard let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
            settings = parsed
            let backup = url.deletingLastPathComponent().appending(path: "settings.json.vorssaint-backup")
            if !FileManager.default.fileExists(atPath: backup.path) {
                try? data.write(to: backup)
            }
        }
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        let token = ClaudeLiveConstants.token(in: defaults)
        for event in events {
            var entries = (hooks[event] as? [Any] ?? []).filter { !isOurs($0) }
            if on {
                let hook: [String: Any] = [
                    "type": "http",
                    "url": "http://127.0.0.1:\(ClaudeLiveConstants.defaultPort)\(ClaudeLiveConstants.hookPath)",
                    "timeout": event == "PermissionRequest" ? Int(ClaudeLiveConstants.askHold) + 5 : 3,
                    "headers": [
                        "X-Vorssaint-Token": token,
                        "X-Claude-Config": "$CLAUDE_CONFIG_DIR",
                        "X-Bundle": "$__CFBundleIdentifier",
                        "X-Term": "$TERM_PROGRAM",
                    ],
                    "allowedEnvVars": ["CLAUDE_CONFIG_DIR", "__CFBundleIdentifier", "TERM_PROGRAM"],
                ]
                entries.append(["hooks": [hook]])
            }
            if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
        }
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        guard let data = try? JSONSerialization.data(withJSONObject: settings,
                                                     options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return false
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
