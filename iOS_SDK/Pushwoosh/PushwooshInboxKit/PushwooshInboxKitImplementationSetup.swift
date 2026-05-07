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
    @objc
    public static func makeViewController() -> UIViewController {
        return PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
    }
}
#endif
