//
//  PWForegroundPush.swift
//  PushwooshBridge
//
//  Created by André Kis on 20.08.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import PushwooshCore
import UIKit

@objc
public enum PWForegroundPushStyle: Int {
    case style1 = 0
}

@objc
public enum PWForegroundPushHapticFeedback: Int {
    case none = 0
    case light
    case medium
    case heavy
    case soft
    case rigid
    case notification
}

/**
 Enum representing the disappearance animation of a foreground push notification.
 
 - `balls`: The push notification explodes into small balls when disappearing.
 - `regularPush`: The push notification moves upward and disappears, mimicking the standard push behavior.
 */
@objc
public enum PWForegroundPushDisappearedAnimation: Int {
    case balls = 0
    case regularPush
}

/**
 Protocol for handling custom foreground pushes in Pushwoosh.
 
 Allows configuration of appearance, haptic feedback, and tap callbacks for foreground push notifications.
 */
@objc
public protocol PWForegroundPush {
    // MARK: - Appearance Settings

    /**
     Custom gradient colors for the push background.
     
     If set to nil, the default gradient is used.
     */
    @objc static var gradientColors: [UIColor]? { get set }
    /**
     Background color for the push.
     
     If nil and `gradientColors` is not set, the default gradient is used.
     */
    @objc static var backgroundColor: UIColor? { get set }
    
    /**
     Determines whether to use the default push animation when displaying a foreground push.

     If `true`, the push notification will animate in with a slide and wave effect.
     If `false`, the push will appear instantly without animation.
     */
    @objc static var usePushAnimation: Bool { get set }
    /**
     Color for the push title text.
     
     Defaults to system white if nil.
     */
    @objc static var titlePushColor: UIColor? { get set }
    
    /**
     The font used for the title text in a foreground push notification.

     Set this property to customize the appearance of the title.
     If `nil`, the default bold system font of size 18 will be used.
     */
    @objc static var titlePushFont: UIFont? { get set }
    
    /**
     The font used for the message body text in a foreground push notification.

     Set this property to customize the appearance of the message text.
     If `nil`, the default system font will be used.
     */
    @objc static var messagePushFont: UIFont? { get set }
    
    /**
     Color for the push message text.
     
     Defaults to system white if nil.
     */
    @objc static var messagePushColor: UIColor? { get set }
    
    /**
     Enables or disables the Liquid Glass style for foreground push notifications.

     Set this property to `true` to use the animated Liquid Glass effect (iOS 26+),
     or `false` to use the standard push appearance.

     Note:
     - If this flag is enabled but the user's system version is lower than iOS 26,
       a regular UIView-based push will be shown instead.
     - If your project is compiled with a Swift version **lower than 5.13**, the Liquid Glass
       effect will not be available at all — even on iOS 26. In that case, a blurred
       `UIVisualEffectView` (with UIBlurEffect) will be used instead on all devices.

     In summary:
     - Swift 5.13+ + iOS 26 → Liquid Glass
     - Swift 5.13+ + iOS < 26 → Standard UIView
     - Swift < 5.13 → Always blurred view (no Liquid Glass support)
     */
    @objc static var useLiquidView: Bool { get set }
    /**
     Callback triggered when the user taps on the push notification.
     
     - Parameter userInfo: Dictionary containing push payload data.
     */
    @objc
    static var didTapForegroundPush: (([AnyHashable: Any]) -> Void)? { get set }
    
    // MARK: - Push Methods

    /**
     Configure a foreground push with the specified style, duration, and haptic feedback.

     Call this method during application initialization to set up the foreground push behavior.

     - Parameters:
       - style: Display style of the push.
       - duration: Duration (in seconds) to show the push.
       - vibration: Haptic feedback type for the push.
       - disappearedPushAnimation: The animation to use when the push disappears. Use `.balls` for a particle-like explosion effect, or `.regularPush` to mimic the standard upward push disappearance.
     */
    @objc
    static func foregroundNotificationWith(style: PWForegroundPushStyle,
                                           duration: Int,
                                           vibration: PWForegroundPushHapticFeedback,
                                           disappearedPushAnimation: PWForegroundPushDisappearedAnimation)
    /**
     Show a foreground push with the specified payload.

     - Parameter userInfo: Dictionary containing push payload data.
     */
    @objc
    static func showForegroundPush(userInfo: [AnyHashable: Any])
}
