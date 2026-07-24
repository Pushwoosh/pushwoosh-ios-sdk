//
//  PWInAppHandler.swift
//  PushwooshBridge
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Back-channel protocol that lets Core dispatch a native in-app config to the
/// optional `PushwooshInApp` module without a `performSelector` chain.
///
/// The module registers a handler conforming to this protocol via
/// `PushwooshModuleRegistry.registerHandler(_:forIdentifier:)` at load time.
/// Core forwards the config dictionary (read from `native-config.json` in a
/// postEvent resource ZIP) through `handleInAppConfig(_:)`; when the module is
/// not linked the handler is `nil` and the message is a no-op.
///
/// Mirrors the Obj-C `@protocol PWInAppHandler` in
/// `PushwooshCore/Modules/Backchannels/PWInAppHandler.h` — same `@objc`
/// selectors, so dispatch resolves identically on either side.
@objc
public protocol PWInAppHandler {
    /// Hands a native in-app config dictionary off to the in-app presenter.
    @objc func handleInAppConfig(_ config: [AnyHashable: Any])

    /// Same as `handleInAppConfig(_:)`, with an `onShown` hook the presenter
    /// fires when the message is actually displayed (not on route acceptance —
    /// frequency caps, pause or the host delegate may still suppress it). Core
    /// uses the hook to fire the same show statistics as regular in-apps.
    @objc func handleInAppConfig(_ config: [AnyHashable: Any], onShown: (() -> Void)?)

    /// Full statistics variant: `onClicked` fires when a URL action runs (a
    /// close tap is not a click), `onClosed` once when the message is dismissed
    /// by any path. Core maps them to the same `richMediaAction` requests as the
    /// HTML rich media JS bridge (action types 1 and 4).
    @objc func handleInAppConfig(_ config: [AnyHashable: Any],
                                 onShown: (() -> Void)?,
                                 onClicked: (() -> Void)?,
                                 onClosed: (() -> Void)?)
}
