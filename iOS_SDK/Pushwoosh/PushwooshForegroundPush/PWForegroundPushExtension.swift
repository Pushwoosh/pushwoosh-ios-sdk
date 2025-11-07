//
//  PWForegroundPushExtension.swift
//  PushwooshForegroundPush
//
//  Created by André Kis on 20.08.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge
import UIKit

@available(iOS 13.0, *)
public extension PWForegroundPush {
    
    static var delegate: PWForegroundPushDelegate {
        get { PushwooshForegroundPushImplementation.delegate as! PWForegroundPushDelegate }
        set { PushwooshForegroundPushImplementation.delegate = newValue }
    }
    
    static func foregroundNotificationWith(style: PWForegroundPushStyle,
                                           duration: Int,
                                           vibration: PWForegroundPushHapticFeedback,
                                           disappearedPushAnimation: PWForegroundPushDisappearedAnimation) {
        PushwooshForegroundPushImplementation.foregroundNotificationWith(style: style, duration: duration, vibration: vibration, disappearedPushAnimation: disappearedPushAnimation)
    }
    
    static func showForegroundPush(userInfo: [AnyHashable: Any]) {
        PushwooshForegroundPushImplementation.showForegroundPush(userInfo: userInfo)
    }
    
    static var gradientColors: [UIColor]? {
        get { PushwooshForegroundPushImplementation.gradientColors }
        set { PushwooshForegroundPushImplementation.gradientColors = newValue }
    }
    
    static var backgroundColor: UIColor? {
        get { PushwooshForegroundPushImplementation.backgroundColor }
        set { PushwooshForegroundPushImplementation.backgroundColor = newValue }
    }
    
    static var usePushAnimation: Bool {
        get { PushwooshForegroundPushImplementation.usePushAnimation }
        set { PushwooshForegroundPushImplementation.usePushAnimation = newValue }
    }
    
    static var titlePushColor: UIColor? {
        get { PushwooshForegroundPushImplementation.titlePushColor }
        set { PushwooshForegroundPushImplementation.titlePushColor = newValue }
    }
    
    static var messagePushColor: UIColor? {
        get { PushwooshForegroundPushImplementation.messagePushColor }
        set { PushwooshForegroundPushImplementation.messagePushColor = newValue }
    }
    
    static var titlePushFont: UIFont? {
        get { PushwooshForegroundPushImplementation.titlePushFont }
        set { PushwooshForegroundPushImplementation.titlePushFont = newValue }
    }
    
    static var messagePushFont: UIFont? {
        get { PushwooshForegroundPushImplementation.messagePushFont }
        set { PushwooshForegroundPushImplementation.messagePushFont = newValue }
    }
    
    static var useLiquidView: Bool {
        get { PushwooshForegroundPushImplementation.useLiquidView }
        set { PushwooshForegroundPushImplementation.useLiquidView = newValue }
    }
}

/// Delegate protocol for receiving foreground push events.
@objc public protocol PWForegroundPushDelegate: NSObjectProtocol {
    /// Called when user taps on the foreground push notification.
    @objc optional func didTapForegroundPush(_ userInfo: [AnyHashable: Any])
}
