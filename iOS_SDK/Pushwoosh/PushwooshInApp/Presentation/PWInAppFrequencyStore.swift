//
//  PWInAppFrequencyStore.swift
//  PushwooshInApp
//
//  Created by André Kis on 24.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Persisted display history per in-app id (UserDefaults) for opt-in frequency
//  capping — "show once" / max displays / cooldown / expiry. Survives relaunch,
//  unlike the in-memory queue dedup. `expireDate`/`ttl` are always enforced;
//  `maxDisplays`/`cooldown` only after `setFrequencyCapEnabled(true)`, so an
//  SDK update never changes display behaviour silently (Android parity).
//

#if canImport(UIKit) && os(iOS)
import Foundation

final class PWInAppFrequencyStore {

    static let shared = PWInAppFrequencyStore()

    // Flipped via setFrequencyCapEnabled from any thread (a host bridge) while
    // canShow reads it on main; the lock gives the flag atomic read/write,
    // matching Android's @Volatile.
    private let isCapEnabledLock = NSLock()
    private var _isCapEnabled = false

    /// Opt-in switch for `maxDisplays`/`cooldown`, flipped via
    /// `Pushwoosh.inApp.setFrequencyCapEnabled(_:)`. Defaults to off.
    var isCapEnabled: Bool {
        get {
            isCapEnabledLock.lock()
            defer { isCapEnabledLock.unlock() }
            return _isCapEnabled
        }
        set {
            isCapEnabledLock.lock()
            _isCapEnabled = newValue
            isCapEnabledLock.unlock()
        }
    }

    private let defaults = UserDefaults(suiteName: "com.pushwoosh.inapp.frequency") ?? .standard
    private let countPrefix = "pw_inapp_count_"
    private let lastShownPrefix = "pw_inapp_last_"

    private init() {}

    /// Whether the message is allowed to display now, given its (opt-in) caps.
    func canShow(_ message: PWInAppMessageModel) -> Bool {
        if let expireDate = message.expireDate, expireDate.timeIntervalSinceNow < 0 {
            return false
        }
        guard isCapEnabled, let id = message.id else {
            return true
        }
        if let maxDisplays = message.maxDisplays, displayCount(for: id) >= maxDisplays {
            return false
        }
        if let cooldown = message.cooldown, let last = lastShown(for: id),
           Date().timeIntervalSince(last) < cooldown {
            return false
        }
        return true
    }

    /// Records a display so future `canShow` calls honour the caps.
    func recordShown(_ message: PWInAppMessageModel) {
        guard let id = message.id else {
            return
        }
        defaults.set(displayCount(for: id) + 1, forKey: countPrefix + id)
        defaults.set(Date(), forKey: lastShownPrefix + id)
    }

    private func displayCount(for id: String) -> Int {
        defaults.integer(forKey: countPrefix + id)
    }

    private func lastShown(for id: String) -> Date? {
        defaults.object(forKey: lastShownPrefix + id) as? Date
    }
}
#endif
