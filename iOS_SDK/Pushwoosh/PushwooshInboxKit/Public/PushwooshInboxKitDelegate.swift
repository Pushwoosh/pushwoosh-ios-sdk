//
//  PushwooshInboxKitDelegate.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

/// Lifecycle and interaction callbacks for ``PushwooshInboxKitViewController``.
///
/// All methods carry a default implementation; conformance only requires the
/// callbacks the host actually wants to handle.
public protocol PushwooshInboxKitDelegate: AnyObject {

    /// Invoked when a row is about to be displayed.
    func inboxKit(_ vc: PushwooshInboxKitViewController, willDisplay message: PWInboxMessageProtocol, at indexPath: IndexPath)

    /// Invoked on tap. Return `true` to let the SDK perform the default action
    /// (richmedia, URL, or deeplink). Return `false` if the host has handled
    /// the tap itself.
    func inboxKit(_ vc: PushwooshInboxKitViewController, didSelect message: PWInboxMessageProtocol) -> Bool

    /// Invoked before a swipe-to-delete commits. Return `false` to cancel.
    func inboxKit(_ vc: PushwooshInboxKitViewController, shouldDelete message: PWInboxMessageProtocol) -> Bool

    /// Invoked after each refresh cycle (success or failure).
    func inboxKit(_ vc: PushwooshInboxKitViewController, didRefreshWith messages: [PWInboxMessageProtocol], error: Error?)

    /// Invoked when the controller is being popped or dismissed.
    func inboxKit(didDismiss vc: PushwooshInboxKitViewController)

    /// Invoked when the user taps an inline CTA button rendered inside a cell.
    ///
    /// The default action is dispatched on `button.action`:
    /// - ``PushwooshInboxButtonAction/openURL(_:)`` → SDK opens the URL via
    ///   `UIApplication.shared.open`.
    /// - ``PushwooshInboxButtonAction/dismiss`` → SDK removes the carrying
    ///   message from the feed (subject to `shouldDelete`).
    /// - ``PushwooshInboxButtonAction/markRead`` → SDK marks the message read.
    /// - ``PushwooshInboxButtonAction/custom(_:)`` → SDK does nothing; the
    ///   host MUST handle it here by inspecting the payload (typically keyed
    ///   by a `tag` field agreed with the marketer).
    ///
    /// Return `true` to let the SDK perform the default for `openURL`,
    /// `dismiss`, and `markRead`. Return `false` to handle the tap entirely
    /// in the host. For `custom` the return value is ignored — SDK never
    /// performs a default action there.
    func inboxKit(_ vc: PushwooshInboxKitViewController,
                  didTapButton button: PushwooshInboxButton,
                  onMessage message: PWInboxMessageProtocol) -> Bool
}

public extension PushwooshInboxKitDelegate {
    func inboxKit(_ vc: PushwooshInboxKitViewController, willDisplay message: PWInboxMessageProtocol, at indexPath: IndexPath) {}
    func inboxKit(_ vc: PushwooshInboxKitViewController, didSelect message: PWInboxMessageProtocol) -> Bool { true }
    func inboxKit(_ vc: PushwooshInboxKitViewController, shouldDelete message: PWInboxMessageProtocol) -> Bool { true }
    func inboxKit(_ vc: PushwooshInboxKitViewController, didRefreshWith messages: [PWInboxMessageProtocol], error: Error?) {}
    func inboxKit(didDismiss vc: PushwooshInboxKitViewController) {}
    func inboxKit(_ vc: PushwooshInboxKitViewController,
                  didTapButton button: PushwooshInboxButton,
                  onMessage message: PWInboxMessageProtocol) -> Bool { true }
}
#endif
