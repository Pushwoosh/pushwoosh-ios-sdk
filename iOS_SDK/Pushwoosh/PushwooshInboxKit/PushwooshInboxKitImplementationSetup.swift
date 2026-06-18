//
//  PushwooshInboxKitImplementationSetup.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS) && os(iOS)
import Foundation
import UIKit
import PushwooshCore
import PushwooshBridge

/// Implementation entry-point discovered by the umbrella SDK via
/// `NSClassFromString("PushwooshInboxKitImplementation")`.
///
/// Hosts instantiate the controller directly:
/// - Swift: `PushwooshInboxKitViewController(attributes:)`
/// - Obj-C: `[[PushwooshInboxKitViewController alloc] init]`
@objc(PushwooshInboxKitImplementation)
public class PushwooshInboxKitImplementation: NSObject, PWInboxKit {

    @objc
    public static func inboxKit() -> AnyClass {
        return PushwooshInboxKitImplementation.self
    }

    /// Convenience factory for Obj-C hosts that want a default-configured
    /// controller without touching the Swift `Attributes` struct.
    ///
    /// Reserved scaffold — not currently wired into an integration path:
    /// it is intentionally NOT declared on the `PWInboxKit` bridge protocol,
    /// so it is not reachable through `Pushwoosh.InboxKit` today. Current
    /// integrations build the controller directly
    /// (`PushwooshInboxKitViewController(attributes:)`, or `[[… alloc] init]`
    /// from Obj-C). Kept for a possible future Obj-C entry point: to activate
    /// it, add `static func makeViewController() -> UIViewController` to the
    /// `PWInboxKit` protocol so `[[Pushwoosh InboxKit] makeViewController]`
    /// resolves end-to-end.
    @objc
    public static func makeViewController() -> UIViewController {
        return PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
    }
}
#endif
