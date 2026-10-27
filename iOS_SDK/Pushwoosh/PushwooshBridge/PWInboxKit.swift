//
//  PWInboxKit.swift
//  PushwooshBridge
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#endif

/// Protocol bridging the optional `PushwooshInboxKit` module to the umbrella SDK.
///
/// The host SDK discovers `PushwooshInboxKit` at runtime through
/// `PushwooshModuleRegistry` — `PushwooshInboxKitLoader.+load` registers the
/// implementation class at image load. The bridge protocol intentionally
/// exposes only class-level factories — the customizable UI surface
/// (`PushwooshInboxKitViewController`, `PushwooshInboxKitAttributes`) is
/// consumed directly from the `PushwooshInboxKit` module by the host app.
@objc
public protocol PWInboxKit {
    /// Returns the implementation class. Used as a marker to confirm the
    /// optional module is linked.
    @objc static func inboxKit() -> AnyClass

    #if os(iOS)
    /// Default inbox screen; `nil` when `PushwooshInboxKit` is not linked.
    @objc static func makeViewController() -> UIViewController?
    #endif
}
