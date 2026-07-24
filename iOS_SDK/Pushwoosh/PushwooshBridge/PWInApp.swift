//
//  PWInApp.swift
//  PushwooshBridge
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import PushwooshCore

/// Public surface of the optional `PushwooshInApp` module, reached as
/// `Pushwoosh.inApp`. Resolves to the module's implementation class when the
/// module is linked, otherwise to a logged no-op (`PWMissingModule`).
///
/// Production in-app messages are presented automatically — config arrives as
/// `native-config.json` inside a postEvent resource ZIP and is dispatched to
/// the module via the `PWInAppHandler` back-channel. `present(_:)` is the
/// manual / testing entry point.
@objc
public protocol PWInApp {
    /// Presents a native in-app message from a raw config dictionary.
    ///
    /// Use from code to test layouts without a server round-trip:
    /// ```swift
    /// Pushwoosh.inApp.present(["displayType": "modal", "modal": [ ... ]])
    /// ```
    @objc
    static func present(_ config: [AnyHashable: Any])

    /// Delegate receiving in-app lifecycle and click callbacks. The object must
    /// conform to `PWInAppMessageDelegate` (declared in `PushwooshInApp`).
    @objc
    static var delegate: AnyObject? { get set }

    /// When `true`, eligible in-app messages are queued but not displayed.
    /// Defaults to `false`.
    @objc
    static var isPaused: Bool { get set }

    /// `true` while any in-app (including a floating PiP) is on screen.
    @objc
    static var isPresenting: Bool { get }

    /// Dismisses whatever in-app is currently shown (e.g. on logout or a
    /// deep-link navigation). No-op if nothing is showing.
    @objc
    static func dismiss()

    /// Opt-in enforcement of the `maxDisplays` / `cooldown` frequency caps.
    /// Defaults to `false` — an SDK update never changes display behaviour
    /// silently. `expireDate` / `ttl` are always enforced regardless.
    @objc
    static func setFrequencyCapEnabled(_ enabled: Bool)
}
