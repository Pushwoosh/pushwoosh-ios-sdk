//
//  PushwooshTVOSImplementation.swift
//  PushwooshTVOS
//
//  Created by André Kis on 03.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import PushwooshCore
import PushwooshBridge

@available(tvOS 11.0, *)
@objc(PushwooshTVOSImplementation)
public class PushwooshTVOSImplementation: NSObject {

    @objc(shared)
    public static let shared = PushwooshTVOSImplementation()

    private var appCode: String?
    private var deviceToken: String?

    private let apiClient = PWTVOSAPIClient()
    private let _richMediaManager = PWTVOSRichMediaManager()

    @objc
    public var richMediaManager: PWTVOSRichMediaManager {
        return _richMediaManager
    }

    private override init() {
        super.init()
    }

    @objc
    public static func setAppCode(_ appCode: String) {
        shared.appCode = appCode
        PWSettings.settingsInstance().appCode = appCode
    }

    @objc
    public func registerForPushNotifications(withToken token: Data, completion: ((Error?) -> Void)? = nil) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString

        guard let appCode = self.appCode else {
            let error = NSError(domain: "Pushwoosh", code: -1, userInfo: [NSLocalizedDescriptionKey: "App code is not set"])
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: type(of: self), message: "App code is not set")
            completion?(error)
            return
        }

        let savedToken = PWSettings.settingsInstance().pushTvToken
        if savedToken == tokenString {
            completion?(nil)
            return
        }

        let hwid = PWSettings.settingsInstance().hwid
        apiClient.registerDevice(appCode: appCode, token: tokenString, hwid: hwid) { error in
            if let error = error {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: type(of: self), message: "Failed to register device: \(error.localizedDescription)")
            } else {
                PushwooshLog.pushwooshLog(.PW_LL_INFO, className: type(of: self), message: "Device successfully registered for push notifications")
                PWSettings.settingsInstance().pushTvToken = tokenString
            }
            completion?(error)
        }
    }

    @objc
    public static func registerForTvPushNotifications() {
        shared.requestNotificationAuthorization()
    }

    @objc
    public func unregisterForPushNotifications(completion: ((Error?) -> Void)? = nil) {
        PWSettings.settingsInstance().lastRegTime = nil

        apiClient.unregisterDevice { error in
            if let error = error {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: type(of: self), message: "Unregistering for push notifications failed")
            } else {
                PWSettings.settingsInstance().pushTvToken = nil
                PushwooshLog.pushwooshLog(.PW_LL_INFO, className: type(of: self), message: "Unregistered for push notifications")
            }
            completion?(error)
        }
    }

    @objc
    public static func unregisterForTvPushNotifications(completion: ((Error?) -> Void)? = nil) {
        shared.unregisterForPushNotifications(completion: completion)
    }

    @objc
    public static func handleTvPushToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PushwooshLog.pushwooshLog(.PW_LL_DEBUG, className: self, message: "Received push token: \(tokenString)")
        shared.registerForPushNotifications(withToken: deviceToken)
    }

    @objc
    public static func handleTvPushRegistrationFailure(_ error: Error) {
        var errorMessage = "Failed to register for push notifications: \(error.localizedDescription)"

        if let nsError = error as NSError? {
            switch nsError.code {
            case 3010:
                errorMessage += " (APNs is not available. This is normal on simulator.)"
            case 3000:
                errorMessage += " (Missing push notification entitlement. Check your provisioning profile.)"
            default:
                errorMessage += " (Error code: \(nsError.code))"
            }
        }

        PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: errorMessage)
    }

    @objc
    public static func handleTvPushReceived(userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        shared.processPushNotification(userInfo: userInfo, completionHandler: completionHandler)
    }

    @objc
    public static func handleTVOSPush(userInfo: [AnyHashable: Any]) -> Bool {
        return shared._richMediaManager.handlePush(userInfo: userInfo)
    }

    @objc
    public static func configureRichMediaWith(position: PWTVOSRichMediaPosition, presentAnimation: PWTVOSRichMediaPresentAnimation, dismissAnimation: PWTVOSRichMediaDismissAnimation = .none) {
        shared._richMediaManager.configureRichMediaWith(position: position, presentAnimation: presentAnimation, dismissAnimation: dismissAnimation)
    }

    @objc
    public static func configureCloseButton(_ show: Bool) {
        shared._richMediaManager.configureCloseButton(show)
    }

    @objc
    public static func setRichMediaGetTagsHandler(_ handler: @escaping ([AnyHashable: Any]) -> Void) {
        shared._richMediaManager.setGetTagsHandler(handler)
    }

    private func processPushNotification(userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard isPushwooshMessage(userInfo) else {
            completionHandler(.noData)
            return
        }

        if isContentAvailablePush(userInfo) {
            PushwooshLog.pushwooshLog(.PW_LL_DEBUG, className: type(of: self), message: "Processing silent push notification")
            completionHandler(.newData)
            return
        }

        if _richMediaManager.handlePush(userInfo: userInfo) {
            PushwooshLog.pushwooshLog(.PW_LL_DEBUG, className: type(of: self), message: "Rich Media displayed for push notification")
            completionHandler(.newData)
        } else {
            PushwooshLog.pushwooshLog(.PW_LL_DEBUG, className: type(of: self), message: "Push notification received")
            completionHandler(.newData)
        }
    }

    private func isPushwooshMessage(_ userInfo: [AnyHashable: Any]) -> Bool {
        return userInfo["p"] != nil || userInfo["pw_msg"] != nil
    }

    private func isContentAvailablePush(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let aps = userInfo["aps"] as? [String: Any] {
            return aps["content-available"] as? Int == 1
        }
        return false
    }

    private func requestNotificationAuthorization() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    @objc
    public static func tvos() -> AnyClass {
        return PushwooshTVOSImplementation.self
    }
}
