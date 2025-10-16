//
//  PWTVoSExtension.swift
//  PushwooshTVOS
//
//  Created by André Kis on 07.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge

public extension PWTVoS {

    @available(tvOS 11.0, *)
    static func setAppCode(_ appCode: String) {
        PushwooshTVOSImplementation.setAppCode(appCode)
    }

    @available(tvOS 11.0, *)
    static func registerForTvPushNotifications(withToken token: Data, completion: ((Error?) -> Void)? = nil) {
        PushwooshTVOSImplementation.shared.registerForPushNotifications(withToken: token, completion: completion)
    }

    @available(tvOS 11.0, *)
    static func unregisterForTvPushNotifications(completion: ((Error?) -> Void)? = nil) {
        PushwooshTVOSImplementation.shared.unregisterForPushNotifications(completion: completion)
    }

    @available(tvOS 11.0, *)
    static func handleTVOSPush(userInfo: [AnyHashable: Any]) -> Bool {
        return PushwooshTVOSImplementation.handleTVOSPush(userInfo: userInfo)
    }

    @available(tvOS 11.0, *)
    static func configureRichMediaWith(position: PWTVOSRichMediaPosition, presentAnimation: PWTVOSRichMediaPresentAnimation, dismissAnimation: PWTVOSRichMediaDismissAnimation = .none) {
        PushwooshTVOSImplementation.configureRichMediaWith(position: position, presentAnimation: presentAnimation, dismissAnimation: dismissAnimation)
    }

    @available(tvOS 11.0, *)
    static func configureCloseButton(_ show: Bool) {
        PushwooshTVOSImplementation.configureCloseButton(show)
    }
}
