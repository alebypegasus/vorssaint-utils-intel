// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Every judgment call of the cleaner in one place: what starts checked in
/// the review list and what never even appears. The rule of thumb is that a
/// find is pre checked only when the evidence is strong and rebuilding the
/// data is cheap; anything based on guessing starts unchecked and waits for
/// the user's eye.
enum CleanerPolicy {
    /// Leftovers are an educated guess against the installed apps oracle, so
    /// they start unchecked and the interface explains what they are.
    static let precheckLeftovers = false

    /// An orphaned startup item needs two independent signals (every
    /// executable gone AND no living owner for its label), so these start
    /// checked; they are the ghosts in Login Items and Extensions.
    static let precheckLoginItems = true

    /// Logs are diagnostic text apps rewrite freely.
    static let precheckLogs = true

    /// Build products, package managers and simulator caches regenerate on demand.
    static let precheckDeveloper = true

    /// Browser caches are safe to rebuild and free significant disk space.
    static let precheckBrowserCaches = true

    /// App communication caches are rebuildable from cloud servers.
    static let precheckAppMediaCaches = true

    /// System crash dumps and diagnostic logs.
    static let precheckSystemLogs = true

    /// Stale temporary files and incomplete downloads.
    static let precheckTemporaryResidue = true

    /// External drive trash folders.
    static let precheckExternalTrashes = false

    /// Relative to the home folder. Only ever offered when they exist.
    static let developerJunkPaths: [String] = [
        "/Library/Developer/Xcode/DerivedData",
        "/Library/Developer/Xcode/DocumentationCache",
        "/Library/Developer/CoreSimulator/Caches",
        "/Library/Developer/Xcode/iOS DeviceSupport",
        "/Library/Developer/Xcode/watchOS DeviceSupport",
        "/Library/Developer/Xcode/tvOS DeviceSupport",
        "/Library/Developer/Xcode/Archives",
        "/Library/Caches/org.swift.swiftpm",
        "/Library/Caches/CocoaPods",
        "/Library/Caches/Homebrew",
        "/Library/Caches/Yarn",
        "/Library/Caches/pip",
        "/Library/Caches/go-build",
        "/Library/Caches/JetBrains",
        "/Library/Caches/com.microsoft.VSCode",
        "/.gradle/caches",
        "/.gradle/daemon",
        "/.npm/_cacache",
        "/.cargo/registry/cache",
        "/.cargo/git/db",
        "/.cache/pip",
        "/.cache/pypoetry",
        "/Library/pnpm/store",
    ]

    /// Known browser cache locations relative to the home folder.
    static let browserCachePaths: [(path: String, label: String)] = [
        ("/Library/Caches/com.apple.Safari", "Safari Cache"),
        ("/Library/Safari/FaviconsCache", "Safari Favicons"),
        ("/Library/Caches/Google/Chrome", "Google Chrome Cache"),
        ("/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage", "Chrome Service Workers"),
        ("/Library/Application Support/Google/Chrome/Default/GPUCache", "Chrome GPU Cache"),
        ("/Library/Caches/company.thebrowser.Browser", "Arc Browser Cache"),
        ("/Library/Caches/com.microsoft.edgemac", "Microsoft Edge Cache"),
        ("/Library/Caches/com.brave.Browser", "Brave Browser Cache"),
        ("/Library/Caches/org.mozilla.firefox", "Firefox Cache"),
        ("/Library/Caches/com.operasoftware.Opera", "Opera Cache"),
        ("/Library/Caches/com.vivaldi.Vivaldi", "Vivaldi Cache"),
    ]

    /// Known communication and streaming app caches relative to the home folder.
    static let appMediaCachePaths: [(path: String, label: String)] = [
        ("/Library/Application Support/Slack/Cache", "Slack Cache"),
        ("/Library/Application Support/Slack/Service Worker/CacheStorage", "Slack Storage"),
        ("/Library/Application Support/discord/Cache", "Discord Cache"),
        ("/Library/Application Support/discord/Code Cache", "Discord Code Cache"),
        ("/Library/Application Support/discord/GPUCache", "Discord GPU Cache"),
        ("/Library/Caches/com.spotify.client/Data", "Spotify Data Cache"),
        ("/Library/Caches/com.spotify.client/Storage", "Spotify Storage"),
        ("/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/account-1/postbox/media", "Telegram Media Cache"),
    ]

    /// Device backups are the user's safety net: enormous, ancient, and the
    /// other classic tenant of "Other" storage, but never a machine's call
    /// to delete. Every find waits unchecked for the user's eye.
    static let precheckDeviceBackups = false

    /// Cache folders that never appear in the list at all: this app's own
    /// data and entries known to break things when removed (audio output
    /// loss, blank Settings panels, service sign outs, plugin licensing),
    /// each learned the hard way by the cleaners that came before.
    private static let hiddenCachePrefixes = [
        "com.vorssaint",
        "CloudKit", "com.apple.bird",
        "com.apple.coreaudio", "com.apple.audio.", "coreaudiod",
        "com.apple.systempreferences", "com.apple.controlcenter",
        "com.apple.finder", "com.apple.dock",
        "com.apple.FontRegistry", "com.apple.ATS",
        "com.apple.akd", "com.apple.AuthKit",
        "com.paceap.", "com.native-instruments", "com.fabfilter",
    ]

    /// Third party caches whose content the user paid bandwidth or setup
    /// for (offline media, model and browser downloads): shown, never pre
    /// checked.
    private static let sensitiveCachePrefixes = [
        "com.spotify.client",
        "ms-playwright",
    ]

    static func isExcludedCacheEntry(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return hiddenCachePrefixes.contains { lowered.hasPrefix($0.lowercased()) }
    }

    /// Plain named cache folders known to be pure downloads or build junk;
    /// anything plain named outside this list stays unchecked because bare
    /// names cannot be attributed (some are the system's own, like the maps
    /// tile cache).
    private static let safePlainNameCaches: Set<String> = [
        "homebrew", "pip", "node-gyp", "yarn", "npm", "google",
        "electron", "cypress", "typescript", "puppeteer",
    ]

    /// Apple's own caches are safe to remove but the system rebuilds them
    /// eagerly (slower first launches, re indexing), so they are listed for
    /// the willing and pre checked for nobody. Third party caches start
    /// checked unless they hold content worth keeping, and plain named
    /// folders only when they are known download or build caches.
    static func precheckCacheEntry(_ name: String) -> Bool {
        let lowered = name.lowercased()
        if sensitiveCachePrefixes.contains(where: { lowered.hasPrefix($0.lowercased()) }) { return false }
        if CleanerSupport.looksLikeBundleID(name) {
            return !lowered.hasPrefix("com.apple.")
        }
        return safePlainNameCaches.contains(lowered)
    }
}
