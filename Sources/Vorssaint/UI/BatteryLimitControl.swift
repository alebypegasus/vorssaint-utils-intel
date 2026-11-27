// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The battery level under which Keep Awake switches itself off on battery:
/// a switch plus a number the user types (or steps) between 1 and 95. Shared
/// by the menu panel and Settings so both edit the same value.
struct BatteryLimitControl: View {
    @AppStorage(DefaultsKey.batteryLimit) private var limit = 10
    /// What the number comes back to when the switch is turned on again.
    @State private var lastActive = 10

    var compact = false

    private var isOn: Binding<Bool> {
        Binding(
            get: { limit > 0 },
            set: { on in
                if on {
                    limit = Defaults.sanitizedBatteryLimit(lastActive) > 0 ? lastActive : 10
                } else {
                    if limit > 0 { lastActive = limit }
                    limit = 0
                }
            }
        )
    }

    private var percent: Binding<Int> {
        Binding(
            get: { max(limit, 1) },
            set: { limit = Defaults.clampedBatteryLimit($0) }
        )
    }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            if limit > 0 {
                TextField("", value: percent, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: compact ? 42 : 48)
                    .controlSize(compact ? .small : .regular)
                    .accessibilityLabel(L10n.shared.s.batteryDisableBelow)
                Text("%")
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Stepper("", value: percent, in: 1...Defaults.maxBatteryLimit)
                    .labelsHidden()
                    .controlSize(compact ? .small : .regular)
            }
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(compact ? .mini : .small)
                .accessibilityLabel(L10n.shared.s.batteryDisableBelow)
        }
        .onAppear {
            limit = Defaults.sanitizedBatteryLimit(limit)
            if limit > 0 { lastActive = limit }
        }
    }
}
