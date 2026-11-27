// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum SudoersSupport {
    /// True when a `pmset -g` report lists lid sleep as disabled.
    static func sleepDisabled(inPmsetOutput output: String) -> Bool {
        output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
    }

    /// The closed-lid NOPASSWD rule, granted by uid (`#uid` user spec). A
    /// username would have to be sanitized against sudoers *and* shell
    /// metacharacters — short names on SSO-enrolled Macs can be full email
    /// addresses (#915) — while a uid interpolates as bare digits, which
    /// neither interpreter can read as anything else.
    static func clamshellRule(uid: uid_t) -> String {
        "#\(uid) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0"
    }

    /// True when `sudo -l` lists our NOPASSWD pmset rule before a later broad
    /// rule such as `(ALL) ALL`, which overrides it under sudo's last-match-wins
    /// evaluation (e.g. non-admin or institutional `/etc/sudoers` files that put
    /// `(ALL) ALL` below `#includedir /private/etc/sudoers.d`, issue #63).
    static func hasLaterSudoersOverride(inSudoListOutput output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        guard let ruleIndex = lines.firstIndex(where: {
            $0.contains("NOPASSWD:") && $0.contains("/usr/bin/pmset disablesleep")
        }) else {
            return false
        }
        return lines[(ruleIndex + 1)...].contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty
                && !trimmed.contains("NOPASSWD:")
                && trimmed.range(of: #"\((?:ALL|ALL\s*:\s*ALL)\)\s+ALL\b"#, options: .regularExpression) != nil
        }
    }
}
