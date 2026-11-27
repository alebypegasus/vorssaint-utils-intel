#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
#
# Installs the latest Universal 2 (Apple Silicon + Intel) release from GitHub,
# verifying integrity and code signature before touching /Applications.
#
#   ./Tools/install.sh                     install the newest release
#   ./Tools/install.sh --stable-signing    keep Accessibility & Screen Recording across updates
#   ./Tools/install.sh --version v3.8.0
#   ./Tools/install.sh --dest ~/Applications
#
# What it does, in order:
#   1. Looks up the GitHub Release and locates the Universal 2 .dmg (and .sha256 if published)
#   2. Downloads and verifies SHA-256 (when available) + codesign + bundle identifier
#   3. Quits a running Vorssaint, copies Vorssaint.app cleanly, clears download quarantine
#   4. With --stable-signing, re-signs with the local "Vorssaint Utils Signing" identity
#      created by Tools/setup-signing.sh so macOS TCC permissions survive future updates.
set -euo pipefail

REPO="${VORSSAINT_REPO:-alebypegasus/vorssaint-utils-intel}"
APP_NAME="Vorssaint"
BUNDLE_ID="com.vorssaint.utils"
IDENTITY="Vorssaint Utils Signing"
KEYCHAIN="$HOME/Library/Keychains/vorssaint-signing.keychain-db"
KEYCHAIN_PASS="vorssaint-signing"

DEST="/Applications"
VERSION=""
STABLE=0

while (( $# )); do
    case "$1" in
        --stable-signing) STABLE=1 ;;
        --version) shift; VERSION="${1:-}"; [[ -n "$VERSION" ]] || { echo "✗ --version needs a tag" >&2; exit 2; } ;;
        --dest) shift; DEST="${1:-}"; [[ -d "$DEST" ]] || { echo "✗ --dest must be an existing folder" >&2; exit 2; } ;;
        -h|--help) sed -n '5,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "✗ unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "✗ $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "Vorssaint runs on macOS only."
(( $(sw_vers -productVersion | cut -d. -f1) >= 14 )) || die "macOS 14 or newer is required."

WORK="$(mktemp -d)"
MOUNT_POINT=""
cleanup() {
    if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

# 1. Discover the release and its Universal 2 DMG (+ optional .sha256).
if [[ -n "$VERSION" ]]; then
    API="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
else
    API="https://api.github.com/repos/$REPO/releases/latest"
fi
echo "▸ Looking up release on $REPO…"
curl -fsSL -H "Accept: application/vnd.github+json" "$API" -o "$WORK/release.json" \
    || die "could not reach GitHub ($API)."
TAG="$(plutil -extract "tag_name" raw -o - "$WORK/release.json" 2>/dev/null)" || die "no release found."

DMG_URL=""
SUM_URL=""
i=0
while URL="$(plutil -extract "assets.$i.browser_download_url" raw -o - "$WORK/release.json" 2>/dev/null)"; do
    case "$URL" in
        *.dmg) DMG_URL="$URL" ;;
        *.dmg.sha256) SUM_URL="$URL" ;;
    esac
    i=$((i + 1))
done
[[ -n "$DMG_URL" ]] || die "release $TAG has no .dmg asset."
case "$DMG_URL" in
    "https://github.com/$REPO/releases/download/"*) ;;
    *) die "unexpected download address; stopping." ;;
esac

# 2. Download and verify checksum + code signature.
DMG="$WORK/$(basename "$DMG_URL")"
echo "▸ Downloading $TAG ($(basename "$DMG_URL"))…"
PROGRESS=(-sS); [[ -t 2 ]] && PROGRESS=(--progress-bar)
curl -fL "${PROGRESS[@]}" "$DMG_URL" -o "$DMG"

if [[ -n "$SUM_URL" ]]; then
    curl -fsSL "$SUM_URL" -o "$WORK/expected.sha256"
    EXPECTED="$(awk '{print $1; exit}' "$WORK/expected.sha256")"
    ACTUAL="$(shasum -a 256 "$DMG" | awk '{print $1}')"
    [[ "$EXPECTED" =~ ^[0-9a-f]{64}$ ]] || die "the checksum file is not a valid SHA-256."
    [[ "$EXPECTED" == "$ACTUAL" ]] || die "SHA-256 mismatch — nothing was installed."
    echo "✓ SHA-256 verified ($ACTUAL)"
else
    echo "⚠ Release $TAG has no .sha256 file; skipping checksum check."
fi

MOUNT_POINT="$WORK/mount"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG" -nobrowse -readonly -quiet -mountpoint "$MOUNT_POINT" \
    || die "failed to mount $DMG."
NEW_APP="$MOUNT_POINT/$APP_NAME.app"
[[ -d "$NEW_APP" ]] || die "the DMG does not contain $APP_NAME.app."

codesign --verify --deep --strict "$NEW_APP" 2>/dev/null \
    || die "the app's code signature failed verification. Nothing was installed."
FOUND_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$NEW_APP/Contents/Info.plist")"
[[ "$FOUND_ID" == "$BUNDLE_ID" ]] || die "unexpected bundle identifier ($FOUND_ID)."
lipo -info "$NEW_APP/Contents/MacOS/$APP_NAME" 2>/dev/null | grep -q "$(uname -m)" \
    || die "binary does not include architecture $(uname -m)."
echo "✓ Signature, bundle ID and $(uname -m) slice verified"

# 3. Replace existing installation cleanly.
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "▸ Quitting running $APP_NAME…"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in {1..10}; do pgrep -x "$APP_NAME" >/dev/null 2>&1 || break; sleep 1; done
    pgrep -x "$APP_NAME" >/dev/null 2>&1 && die "$APP_NAME is still running; quit it and retry."
fi
TARGET="$DEST/$APP_NAME.app"
[[ -e "$TARGET" ]] && rm -rf "$TARGET"
ditto "$NEW_APP" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
echo "✓ Installed $TARGET"

# 4. Optional stable local signing so TCC permissions survive future updates.
if (( STABLE )); then
    SETUP="${0:A:h}/setup-signing.sh"
    [[ -x "$SETUP" || -f "$SETUP" ]] || die "--stable-signing requires Tools/setup-signing.sh next to this script."
    echo "▸ Preparing local signing identity ($IDENTITY)…"
    zsh "$SETUP"
    security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN" 2>/dev/null || true
    HELPER="$TARGET/Contents/Library/LaunchServices/$BUNDLE_ID.fan-control"
    ADAPTER="$TARGET/Contents/Frameworks/libVorssaintNowPlaying.dylib"
    [[ -f "$HELPER" ]]  && codesign --force --strip-disallowed-xattrs --identifier "$BUNDLE_ID.fan-control" --sign "$IDENTITY" "$HELPER"
    [[ -f "$ADAPTER" ]] && codesign --force --strip-disallowed-xattrs --identifier "$BUNDLE_ID.now-playing" --sign "$IDENTITY" "$ADAPTER"
    codesign --force --strip-disallowed-xattrs --sign "$IDENTITY" "$TARGET"
    codesign --verify --deep --strict "$TARGET" || die "re-signing failed."
    echo "✓ Signed with '$IDENTITY': Accessibility and Screen Recording permissions will survive future updates."
else
    echo
    echo "Tip: run './Tools/install.sh --stable-signing' to re-sign with a local identity so macOS"
    echo "keeps Accessibility and Screen Recording permissions across future updates."
fi

echo
echo "Done. Open $TARGET (on first launch, right-click → Open if Gatekeeper asks)."
