//
//  PWInline.swift
//  PushwooshBridge
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Theme an inline banner is drawn in. Same values as `PWRichMediaColorScheme`.
@objc
public enum PWInlineColorScheme: Int {
    /// Follows the interface style of the slot's view (its window and view controller). Default.
    case app
    /// Follows the device appearance setting.
    case system
    /// Always light.
    case light
    /// Always dark.
    case dark
}

/// Public surface of inline banners, reached as `Pushwoosh.inline`. Banners live in slots placed in
/// the app layout (`PushwooshInlineView` in UIKit, `PushwooshInlineSlot` in SwiftUI, both in
/// `PushwooshInApp`); resolves to a logged no-op when the `PushwooshInApp` module is not linked.
///
/// ```swift
/// Pushwoosh.inline.delegate = self
/// Pushwoosh.inline.requestSlots(["home_top", "cart_bottom"]) { error in }
/// ```
///
/// Callable from any thread. Calls without a result are handed to the main thread and return at once.
/// Reading `delegate` or `colorScheme` and calling `banner(forSlot:)` off the main thread waits until the
/// main thread runs them: never do it from a thread the main thread is waiting for, that deadlocks.
@objc
public protocol PWInline {
    /// Receives slot updates, shows, clicks and dismissals. Callbacks arrive on the main thread.
    @objc
    static var delegate: PWInlineDelegate? { get set }

    /// Theme banners are drawn in. Defaults to `.app`.
    @objc
    static var colorScheme: PWInlineColorScheme { get set }

    /// Requests banners for up to 10 slots in one call. A slot the server leaves empty collapses.
    /// `completion` runs on the main thread; on error the slots keep what they showed.
    ///
    /// Slots on screen are requested without this call: when a slot first appears, at a session start
    /// and once the server confirms `setUserId` / `resetUserId`. Manual calls are limited to 5 per session
    /// start, then one per 3 minutes; a call over the limit, or made before the server confirms a user
    /// change, fails without network and the slots keep their banners.
    @objc
    static func requestSlots(_ slotIds: [String], completion: ((Error?) -> Void)?)

    /// The banner the slot holds now, for apps that draw banners themselves. `nil` = the slot is empty.
    /// A control-group slot reads as empty and reports its control show once. Off the main thread waits
    /// for the main thread.
    @objc
    static func banner(forSlot slotId: String) -> PushwooshInlineBanner?

    /// Reports that the app showed the slot's banner itself; counted once per banner version and user.
    @objc(trackShownForSlot:bannerId:)
    static func trackShown(slotId: String, bannerId: String)

    /// Reports a tap on the slot's banner drawn by the app; `elementId` = the tapped element, `nil` = the banner itself.
    /// Events are kept and sent later when there is no network.
    @objc(trackClickForSlot:bannerId:elementId:)
    static func trackClick(slotId: String, bannerId: String, elementId: String?)

    /// Hides the banner in its slot; it is not shown to this user again before its `expireDate`. Once
    /// the server has the dismiss, the slot gets its next banner.
    @objc(dismissSlot:bannerId:)
    static func dismiss(slotId: String, bannerId: String)
}

/// Callbacks of inline banner slots, all optional, delivered on the main thread.
@objc(PWInlineDelegate)
public protocol PWInlineDelegate: AnyObject {
    /// The slot got a new banner or became empty (`nil`).
    @objc
    optional func inlineSlot(_ slotId: String, didUpdate banner: PushwooshInlineBanner?)

    /// The banner was shown: at least half of its height stayed on screen for 0.3 s, or the app called
    /// `trackShown`. Once per banner version and user.
    @objc
    optional func inlineSlot(_ slotId: String, didShow banner: PushwooshInlineBanner)

    /// The user tapped the banner; `elementId` = the tapped native element or the HTML element's
    /// `data-pw-id`, `nil` = the banner itself.
    @objc
    optional func inlineSlot(_ slotId: String, didClick banner: PushwooshInlineBanner, elementId: String?)

    /// The banner was closed (close button, a close action or `dismiss`) and the slot collapsed.
    @objc
    optional func inlineSlot(_ slotId: String, didDismiss banner: PushwooshInlineBanner)
}
