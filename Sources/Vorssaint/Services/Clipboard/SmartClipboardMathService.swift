// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// Smart Math & Calculation HUD for copied expressions
/// Evaluates expressions like `(150 * 1.25) - 40` or `2^10` when copied.
final class SmartClipboardMathService: ObservableObject {
    static let shared = SmartClipboardMathService()

    @Published var lastCalculatedExpression: String? = nil
    @Published var lastResult: String? = nil

    private var changeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?

    private init() {}

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != changeCount else { return }
        changeCount = currentCount

        guard let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty,
              string.count < 120,
              isMathExpression(string)
        else { return }

        if let result = evaluateMath(string) {
            DispatchQueue.main.async {
                self.lastCalculatedExpression = string
                self.lastResult = result
                QuickToolHUD.show(
                    icon: "equal.circle.fill",
                    message: "\(string) = \(result)"
                )
            }
        }
    }

    private func isMathExpression(_ text: String) -> Bool {
        // Needs at least one arithmetic operator and numbers
        let mathPattern = #"^[0-9\.\s\+\-\*\/\^\(\)\%\,]+$"#
        guard text.range(of: mathPattern, options: .regularExpression) != nil else { return false }
        let hasOperator = text.contains("+") || text.contains("-") || text.contains("*") || text.contains("/") || text.contains("^") || text.contains("%")
        let hasDigits = text.rangeOfCharacter(from: .decimalDigits) != nil
        return hasOperator && hasDigits
    }

    private func evaluateMath(_ expression: String) -> String? {
        let cleaned = expression
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "X", with: "*")
            .replacingOccurrences(of: "^", with: "**")

        let nsExpr = NSExpression(format: cleaned)
        guard let value = nsExpr.expressionValue(with: nil, context: nil) as? NSNumber else {
            return nil
        }

        let doubleVal = value.doubleValue
        if doubleVal.isNaN || doubleVal.isInfinite { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: doubleVal))
    }
}
