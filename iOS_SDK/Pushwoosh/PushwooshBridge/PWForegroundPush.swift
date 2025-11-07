//
//  PWForegroundPush.swift
//  PushwooshBridge
//
//  Created by André Kis on 20.08.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import PushwooshCore
import UIKit

/// Visual style template for the foreground push notification.
@objc
public enum PWForegroundPushStyle: Int {
    /// Standard push notification style with icon, title, and message.
    case style1 = 0
}

/// Haptic feedback type to play when notification appears.
@objc
public enum PWForegroundPushHapticFeedback: Int {
    /// No haptic feedback.
    case none = 0
    /// Light impact haptic feedback.
    case light
    /// Medium impact haptic feedback.
    case medium
    /// Heavy impact haptic feedback.
    case heavy
    /// Soft impact haptic feedback.
    case soft
    /// Rigid impact haptic feedback.
    case rigid
    /// System notification haptic feedback.
    case notification
}

/// Animation style when push notification disappears.
@objc
public enum PWForegroundPushDisappearedAnimation: Int {
    /// Push explodes into small particles when disappearing.
    case balls = 0
    /// Push slides upward and fades out like standard notifications.
    case regularPush
}

/// Protocol for handling custom foreground pushes in Pushwoosh.
@objc
public protocol PWForegroundPush {
    /// Custom gradient colors for the push notification background.
    @objc static var gradientColors: [UIColor]? { get set }
    /// Solid background color for the push notification.
    @objc static var backgroundColor: UIColor? { get set }
    /// A Boolean value that indicates whether to use slide and wave animation when push appears.
    @objc static var usePushAnimation: Bool { get set }
    /// Text color for the notification title.
    @objc static var titlePushColor: UIColor? { get set }
    /// Custom font for the notification title.
    @objc static var titlePushFont: UIFont? { get set }
    /// Custom font for the notification message body.
    @objc static var messagePushFont: UIFont? { get set }
    /// Text color for the notification message body.
    @objc static var messagePushColor: UIColor? { get set }
    /// A Boolean value that indicates whether to enable modern Liquid Glass effect on iOS 26+ devices.
    @objc static var useLiquidView: Bool { get set }
    /// Callback triggered when user taps on the foreground push notification.
    @objc
    static var didTapForegroundPush: (([AnyHashable: Any]) -> Void)? { get set }

    /// Configures the foreground push notification display settings.
    @objc
    static func foregroundNotificationWith(style: PWForegroundPushStyle,
                                           duration: Int,
                                           vibration: PWForegroundPushHapticFeedback,
                                           disappearedPushAnimation: PWForegroundPushDisappearedAnimation)
    /// Displays a foreground push notification with the specified payload.
    @objc
    static func showForegroundPush(userInfo: [AnyHashable: Any])
}
