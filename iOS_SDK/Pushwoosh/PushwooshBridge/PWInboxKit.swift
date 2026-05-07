//
//  PWInboxKit.swift
//  PushwooshBridge
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Protocol bridging the optional `PushwooshInboxKit` module to the umbrella SDK.
///
/// The host SDK (`PushwooshFramework`) discovers `PushwooshInboxKit` at runtime
/// through `NSClassFromString("PushwooshInboxKitImplementation")`. The bridge
/// protocol intentionally exposes only a class-level factory — the public UI
/// surface (`PushwooshInboxKitViewController`, `PushwooshInboxKitAttributes`)
/// is consumed directly from the `PushwooshInboxKit` module by the host app.
@objc
public protocol PWInboxKit {
    /// Returns the implementation class. Used as a marker to confirm the
    /// optional module is linked.
    @objc static func inboxKit() -> AnyClass
}
