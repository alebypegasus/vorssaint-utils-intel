#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Cleanly removes Vorssaint and every piece of system state it created:
# the login item, TCC permissions, preferences, saved state and (if present)
# the password-free closed-lid sudoers rule. Leaves no dead entries behind.
# Also clears the pre-rename "Vorssaint Utils.app" if it is still around.
set -uo pipefail

BUNDLE="com.vorssaint.utils.intel"
LEGACY_BUNDLE="com.vorssaint.utils"
APP="/Applications/Vorssaint Intel.app"
LEGACY_APP="/Applications/Vorssaint.app"
OLD_LEGACY_APP="/Applications/Vorssaint Utils.app"

echo "▸ Quitting…"
pkill -x VorssaintIntel 2>/dev/null || true
pkill -x VorssaintDeveloper 2>/dev/null || true
pkill -x Vorssaint 2>/dev/null || true
pkill -x VorssaintUtils 2>/dev/null || true
sleep 0.5

# Detach from the system from inside whichever bundle still exists: unregisters
# the login item (no BTM tombstone) and restores normal sleep.
for candidate in "$APP/Contents/MacOS/Vorssaint" "$APP/Contents/MacOS/VorssaintIntel" "$LEGACY_APP/Contents/MacOS/Vorssaint" "$OLD_LEGACY_APP/Contents/MacOS/VorssaintUtils"; do
    if [[ -x "$candidate" ]]; then
        echo "▸ Detaching login item and restoring sleep…"
        "$candidate" --uninstall || true
        break
    fi
done

echo "▸ Resetting permissions (Accessibility, Screen Recording)…"
tccutil reset All "$BUNDLE" >/dev/null 2>&1 || true
tccutil reset All "$LEGACY_BUNDLE" >/dev/null 2>&1 || true

echo "▸ Removing app, preferences and saved state…"
rm -rf "$APP" "$LEGACY_APP" "$OLD_LEGACY_APP"
defaults delete "$BUNDLE" >/dev/null 2>&1 || true
defaults delete "$LEGACY_BUNDLE" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/$BUNDLE.plist" "$HOME/Library/Preferences/$LEGACY_BUNDLE.plist"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE.savedState" "$HOME/Library/Saved Application State/$LEGACY_BUNDLE.savedState"

RULES="/etc/sudoers.d/vorssaint-clamshell /etc/sudoers.d/vorssaint-utils-clamshell /etc/sudoers.d/vorss-clamshell"
if ls $RULES >/dev/null 2>&1; then
    echo "▸ Removing closed-lid sudoers rule (asks for your admin password)…"
    osascript -e "do shell script \"rm -f $RULES\" with administrator privileges with prompt \"Vorssaint uninstaller\"" || true
fi

echo "✓ Vorssaint fully removed."
