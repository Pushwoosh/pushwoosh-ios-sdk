//
//  PWForegroundPushStub.swift
//  PushwooshBridge
//
//  Created by André Kis on 20.08.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@objc public class PWForegroundPushStub: NSObject, PWForegroundPush {
    @objc public static var gradientColors: [UIColor]?
    @objc public static var backgroundColor: UIColor?
    @objc public static var usePushAnimation: Bool = true
    @objc public static var titlePushColor: UIColor?
    @objc public static var messagePushColor: UIColor?
    @objc public static var titlePushFont: UIFont?
    @objc public static var messagePushFont: UIFont?
    @objc public static var useLiquidView: Bool = false
    
    public static var didTapForegroundPush: (([AnyHashable : Any]) -> Void)?
    
    public static func showForegroundPush(userInfo: [AnyHashable : Any]) {
        print("PushwooshForegroundPush not found. To enable custom foreground push features, make sure the PushwooshForegroundPush module is added to the project.")
    }
    
    @objc
    public static func foregroundPush() -> AnyClass {
        return PWForegroundPushStub.self
    }
    
    @objc
    public static func foregroundNotificationWith(style: PWForegroundPushStyle, duration: Int, vibration: PWForegroundPushHapticFeedback, disappearedPushAnimation: PWForegroundPushDisappearedAnimation) {
        print("PushwooshForegroundPush not found. To enable custom foreground push features, make sure the PushwooshForegroundPush module is added to the project.")
    }
}
