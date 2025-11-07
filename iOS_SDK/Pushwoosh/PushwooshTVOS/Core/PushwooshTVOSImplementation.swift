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

/// Main implementation class for tvOS push notifications and Rich Media.
///
/// This class provides the core functionality for integrating Pushwoosh push notifications
/// and Rich Media content into tvOS applications. It handles device registration, push
/// notification processing, and Rich Media display with tvOS-specific optimizations.
///
/// ## Usage
///
/// Initialize and configure during app launch:
///
/// ```swift
/// Pushwoosh.TVoS.setAppCode("YOUR-APP-CODE")
/// Pushwoosh.TVoS.registerForTvPushNotifications()
/// ```
///
/// ## Topics
///
/// ### Configuration
/// - ``setAppCode(_:)``
/// - ``registerForTvPushNotifications()``
/// - ``registerForPushNotifications(withToken:completion:)``
///
/// ### Push Handling
/// - ``handleTvPushToken(_:)``
/// - ``handleTvPushRegistrationFailure(_:)``
/// - ``handleTvPushReceived(userInfo:completionHandler:)``
/// - ``handleTVOSPush(userInfo:)``
///
/// ### Rich Media
/// - ``richMediaManager``
/// - ``configureRichMediaWith(position:presentAnimation:dismissAnimation:)``
/// - ``configureCloseButton(_:)``
/// - ``setRichMediaGetTagsHandler(_:)``
@available(tvOS 11.0, *)
@objc(PushwooshTVOSImplementation)
public class PushwooshTVOSImplementation: NSObject {

    /// Shared singleton instance of the tvOS implementation.
    @objc(shared)
    public static let shared = PushwooshTVOSImplementation()

    private var appCode: String?
    private var deviceToken: String?

    private let apiClient = PWTVOSAPIClient()
    private let _richMediaManager = PWTVOSRichMediaManager()

    /// Rich Media manager instance for displaying HTML content.
    ///
    /// Provides access to the Rich Media manager for advanced configuration
    /// and programmatic control of Rich Media display.
    @objc
    public var richMediaManager: PWTVOSRichMediaManager {
        return _richMediaManager
    }

    private override init() {
        super.init()
    }

    /// Sets the Pushwoosh application code for tvOS.
    ///
    /// This method must be called before registering for push notifications.
    /// The app code can be found in your Pushwoosh Control Panel.
    ///
    /// - Parameter appCode: The Pushwoosh application identifier (format: XXXXX-XXXXX).
    ///
    /// ## Example
    ///
    /// ```swift
    /// Pushwoosh.TVoS.setAppCode("12345-67890")
    /// ```
    @objc
    public static func setAppCode(_ appCode: String) {
        shared.appCode = appCode
        PWPreferences.preferencesInstance().appCode = appCode

        let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type
        if let pushwooshClass = pushwooshClass {
            let initSelector = NSSelectorFromString("initializeWithAppCode:")
            if pushwooshClass.responds(to: initSelector) {
                _ = pushwooshClass.perform(initSelector, with: appCode)
            }
        }
    }

    /// Registers the tvOS device for push notifications with the Pushwoosh server.
    ///
    /// Call this method after receiving a device token from Apple Push Notification service.
    /// This method sends the device token to Pushwoosh servers to enable push notifications.
    ///
    /// - Parameters:
    ///   - token: The device token received from APNs in `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    ///   - completion: Optional completion handler called when registration completes. The handler receives an error parameter if registration fails, or nil on success.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    ///     Pushwoosh.TVoS.registerForPushNotifications(withToken: deviceToken) { error in
    ///         if let error = error {
    ///             print("Failed to register: \(error)")
    ///         } else {
    ///             print("Successfully registered")
    ///         }
    ///     }
    /// }
    /// ```
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

        let savedToken = PWPreferences.preferencesInstance().pushTvToken
        if savedToken == tokenString {
            completion?(nil)
            return
        }

        let hwid = PWPreferences.preferencesInstance().hwid
        apiClient.registerDevice(appCode: appCode, token: tokenString, hwid: hwid) { error in
            if let error = error {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: type(of: self), message: "Failed to register device: \(error.localizedDescription)")
            } else {
                PushwooshLog.pushwooshLog(.PW_LL_INFO, className: type(of: self), message: "Device successfully registered for push notifications")
                PWPreferences.preferencesInstance().pushTvToken = tokenString
            }
            completion?(error)
        }
    }

    /// Registers for tvOS push notifications.
    ///
    /// This method requests push notification authorization and registers the device
    /// for remote notifications on tvOS. Call this during app initialization.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///     Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")
    ///     Pushwoosh.TVoS.registerForTvPushNotifications()
    ///     return true
    /// }
    /// ```
    @objc
    public static func registerForTvPushNotifications() {
        shared.requestNotificationAuthorization()
    }

    /// Unregisters the tvOS device from receiving push notifications.
    ///
    /// This method removes the device registration from Pushwoosh servers.
    /// The device will no longer receive push notifications until it registers again.
    ///
    /// - Parameter completion: Optional completion handler called when unregistration completes. The handler receives an error parameter if unregistration fails, or nil on success.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Pushwoosh.TVoS.unregisterForTvPushNotifications { error in
    ///     if let error = error {
    ///         print("Failed to unregister: \(error)")
    ///     } else {
    ///         print("Successfully unregistered")
    ///     }
    /// }
    /// ```
    @objc
    public func unregisterForPushNotifications(completion: ((Error?) -> Void)? = nil) {
        PWPreferences.preferencesInstance().lastRegTime = nil

        apiClient.unregisterDevice { error in
            if let error = error {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: type(of: self), message: "Unregistering for push notifications failed")
            } else {
                PWPreferences.preferencesInstance().pushTvToken = nil
                PushwooshLog.pushwooshLog(.PW_LL_INFO, className: type(of: self), message: "Unregistered for push notifications")
            }
            completion?(error)
        }
    }

    /// Unregisters the tvOS device from receiving push notifications.
    ///
    /// This is a convenience method that calls the instance method on the shared instance.
    ///
    /// - Parameter completion: Optional completion handler called when unregistration completes.
    @objc
    public static func unregisterForTvPushNotifications(completion: ((Error?) -> Void)? = nil) {
        shared.unregisterForPushNotifications(completion: completion)
    }

    /// Handles the device token received from tvOS push registration.
    ///
    /// Call this method from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
    /// to process the device token and register it with Pushwoosh.
    ///
    /// - Parameter deviceToken: The device token data received from APNs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    ///     Pushwoosh.TVoS.handleTvPushToken(deviceToken)
    /// }
    /// ```
    @objc
    public static func handleTvPushToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PushwooshLog.pushwooshLog(.PW_LL_DEBUG, className: self, message: "Received push token: \(tokenString)")
        shared.registerForPushNotifications(withToken: deviceToken)
    }

    /// Handles push registration failure on tvOS.
    ///
    /// Call this method from `application(_:didFailToRegisterForRemoteNotificationsWithError:)`
    /// to log and handle registration errors.
    ///
    /// - Parameter error: The error that occurred during registration.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFailToRegisterForRemoteNotificationsWithError error: Error) {
    ///     Pushwoosh.TVoS.handleTvPushRegistrationFailure(error)
    /// }
    /// ```
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

    /// Handles incoming push notification on tvOS.
    ///
    /// Call this method from `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
    /// to process incoming push notifications. The method automatically detects and displays
    /// Rich Media if present in the notification payload.
    ///
    /// - Parameters:
    ///   - userInfo: Dictionary containing push payload data.
    ///   - completionHandler: Completion handler to call when processing is complete.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    ///                  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    ///     Pushwoosh.TVoS.handleTvPushReceived(userInfo: userInfo, completionHandler: completionHandler)
    /// }
    /// ```
    @objc
    public static func handleTvPushReceived(userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        shared.processPushNotification(userInfo: userInfo, completionHandler: completionHandler)
    }

    /// Handles incoming push notifications with rich media content for tvOS.
    ///
    /// Call this method to process push notifications that may contain rich media content.
    /// If the notification contains rich media, it will be displayed automatically.
    ///
    /// - Parameter userInfo: The push notification payload received from APNs.
    /// - Returns: `true` if the notification contains rich media and was handled, `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    ///                  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    ///     if Pushwoosh.TVoS.handleTVOSPush(userInfo: userInfo) {
    ///         completionHandler(.newData)
    ///     } else {
    ///         completionHandler(.noData)
    ///     }
    /// }
    /// ```
    @objc
    public static func handleTVOSPush(userInfo: [AnyHashable: Any]) -> Bool {
        return shared._richMediaManager.handlePush(userInfo: userInfo)
    }

    /// Configures rich media presentation, positioning, and dismissal animations for tvOS.
    ///
    /// This method allows you to customize how rich media content appears, where it's positioned,
    /// and how it disappears on screen. You can choose from different animation directions,
    /// screen positions, or disable animation entirely.
    ///
    /// - Parameters:
    ///   - position: The screen position where rich media content will be displayed. See ``PWTVOSRichMediaPosition`` for available options.
    ///   - presentAnimation: The animation type to use when presenting rich media. See ``PWTVOSRichMediaPresentAnimation`` for available options.
    ///   - dismissAnimation: The animation type to use when dismissing rich media. Defaults to `.none`. See ``PWTVOSRichMediaDismissAnimation`` for available options.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Configure rich media to appear on the left, slide in from bottom and slide out to left
    /// Pushwoosh.TVoS.configureRichMediaWith(
    ///     position: .left,
    ///     presentAnimation: .fromBottom,
    ///     dismissAnimation: .toLeft
    /// )
    /// ```
    ///
    /// - Note: This configuration applies to all subsequent rich media presentations until changed.
    @objc
    public static func configureRichMediaWith(position: PWTVOSRichMediaPosition, presentAnimation: PWTVOSRichMediaPresentAnimation, dismissAnimation: PWTVOSRichMediaDismissAnimation = .none) {
        shared._richMediaManager.configureRichMediaWith(position: position, presentAnimation: presentAnimation, dismissAnimation: dismissAnimation)
    }

    /// Controls whether the Close button is displayed on rich media content.
    ///
    /// By default, a Close button is shown at the bottom of rich media presentations,
    /// allowing users to dismiss the content. You can hide this button if you want
    /// rich media to only be dismissible through button actions within the content itself.
    ///
    /// - Parameter show: `true` to show the Close button (default), `false` to hide it.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Hide the system Close button
    /// Pushwoosh.TVoS.configureCloseButton(false)
    /// ```
    ///
    /// - Note: If you hide the Close button, ensure your rich media content includes a button with the `closeInApp()` action to allow users to dismiss it.
    @objc
    public static func configureCloseButton(_ show: Bool) {
        shared._richMediaManager.configureCloseButton(show)
    }

    /// Sets a handler to receive tags when requested from rich media content.
    ///
    /// When a user interacts with a getTags button in rich media HTML content,
    /// this handler will be called with the tags retrieved from Pushwoosh.
    /// This allows you to handle tag data in your application as needed.
    ///
    /// - Parameter handler: A closure that receives tags as a dictionary when getTags is triggered. The dictionary contains tag keys and their values.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Pushwoosh.TVoS.setRichMediaGetTagsHandler { tags in
    ///     print("Received tags from rich media: \(tags)")
    ///     // Handle tags in your application
    /// }
    /// ```
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
