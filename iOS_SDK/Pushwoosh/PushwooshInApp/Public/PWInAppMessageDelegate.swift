//
//  PWInAppMessageDelegate.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Lifecycle and click callbacks for native in-app messages. Assign an object
/// conforming to this protocol via `Pushwoosh.inApp.delegate`.
///
/// All callbacks are delivered on the main thread.
@objc
public protocol PWInAppMessageDelegate: AnyObject {
    /// Called right before an in-app message is animated in.
    @objc optional func pushwooshInAppWillPresent(messageId: String?)

    /// Called once the in-app message is on screen.
    @objc optional func pushwooshInAppDidPresent(messageId: String?)

    /// Called after the in-app message has been dismissed.
    @objc optional func pushwooshInAppDidClose(messageId: String?)

    /// Called when the user taps an element with a URL action, before the URL is
    /// opened. `url` is the absolute destination string.
    @objc optional func pushwooshInAppClickedAction(url: String, messageId: String?)

    /// Asked right before a message would be shown. Return `false` to suppress
    /// this specific message (it is discarded, not deferred). Not implementing
    /// the method shows everything (default behaviour). Use it to block in-apps
    /// on sensitive screens (e.g. checkout, a video player).
    @objc optional func pushwooshInAppShouldDisplay(messageId: String?) -> Bool

    /// Gamified templates (scratch card, spin wheel): the game finished and the
    /// prize is on screen. `promoCode` is the revealed code, if the reward
    /// carries one.
    @objc optional func pushwooshInAppRewardRevealed(promoCode: String?, messageId: String?)

    /// Gamified templates: the user copied the revealed promo code to the
    /// pasteboard.
    @objc optional func pushwooshInAppRewardClaimed(promoCode: String, messageId: String?)
}
