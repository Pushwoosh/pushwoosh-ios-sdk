//
//  PWTVoSStub.swift
//  PushwooshBridge
//
//  Created by André Kis on 03.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

/**
 Stub implementation of PWTVoS protocol.

 This class is used when the PushwooshTVOS module is not linked to the project.
 All methods provide no-op implementations and print warning messages.
 */
@objc public class PWTVoSStub: NSObject, PWTVoS {

    @objc
    public static func setAppCode(_ appCode: String) {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS features, add the PushwooshTVOS module to your project.")
    }

    @objc
    public static func registerForTvPushNotifications() {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS push registration, add the PushwooshTVOS module to your project.")
    }

    @objc
    public static func registerForTvPushNotifications(withToken token: Data, completion: ((Error?) -> Void)?) {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS push registration, add the PushwooshTVOS module to your project.")
        let error = NSError(domain: "Pushwoosh", code: -1, userInfo: [NSLocalizedDescriptionKey: "PushwooshTVOS module not found"])
        completion?(error)
    }

    @objc
    public static func unregisterForTvPushNotifications(completion: ((Error?) -> Void)?) {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS push unregistration, add the PushwooshTVOS module to your project.")
        let error = NSError(domain: "Pushwoosh", code: -1, userInfo: [NSLocalizedDescriptionKey: "PushwooshTVOS module not found"])
        completion?(error)
    }

    @objc
    public static func handleTvPushToken(_ deviceToken: Data) {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS push token handling, add the PushwooshTVOS module to your project.")
    }

    @objc
    public static func handleTvPushRegistrationFailure(_ error: Error) {
        print("[Pushwoosh] PushwooshTVOS module not found. Failed to register for push notifications: \(error.localizedDescription)")
    }

    @objc
    public static func handleTvPushReceived(userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS push handling, add the PushwooshTVOS module to your project.")
        completionHandler(.noData)
    }

    @objc
    public static func handleTVOSPush(userInfo: [AnyHashable : Any]) -> Bool {
        print("[Pushwoosh] PushwooshTVOS module not found. To enable tvOS-specific push handling, add the PushwooshTVOS module to your project.")
        return false
    }

    @objc
    public static func configureRichMediaWith(position: PWTVOSRichMediaPosition, presentAnimation: PWTVOSRichMediaPresentAnimation, dismissAnimation: PWTVOSRichMediaDismissAnimation = .none) {
        print("[Pushwoosh] PushwooshTVOS module not found. To configure rich media position and animations, add the PushwooshTVOS module to your project.")
    }

    @objc
    public static func configureCloseButton(_ show: Bool) {
        print("[Pushwoosh] PushwooshTVOS module not found. To configure close button visibility, add the PushwooshTVOS module to your project.")
    }

    @objc
    public static func setRichMediaGetTagsHandler(_ handler: @escaping ([AnyHashable: Any]) -> Void) {
        print("[Pushwoosh] PushwooshTVOS module not found. To set rich media get tags handler, add the PushwooshTVOS module to your project.")
    }

    @objc
    public static func tvos() -> AnyClass {
        return PWTVoSStub.self
    }
}
