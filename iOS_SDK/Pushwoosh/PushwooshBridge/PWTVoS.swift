//
//  PWTVoS.swift
//  PushwooshBridge
//
//  Created by André Kis on 03.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import PushwooshCore
import Foundation
import UIKit

/**
 Animation types for presenting rich media content on tvOS.
 */
@objc public enum PWTVOSRichMediaPresentAnimation: Int {
    /// No animation, content appears immediately (default)
    case none = 0
    /// Content slides in from the top of the screen
    case fromTop
    /// Content slides in from the bottom of the screen
    case fromBottom
    /// Content slides in from the left side of the screen
    case fromLeft
    /// Content slides in from the right side of the screen
    case fromRight
}

/**
 Animation types for dismissing rich media content on tvOS.
 */
@objc public enum PWTVOSRichMediaDismissAnimation: Int {
    /// No animation, content disappears immediately (default)
    case none = 0
    /// Content slides out to the top of the screen
    case toTop
    /// Content slides out to the bottom of the screen
    case toBottom
    /// Content slides out to the left side of the screen
    case toLeft
    /// Content slides out to the right side of the screen
    case toRight
}

/**
 Position options for displaying rich media content on tvOS.
 */
@objc public enum PWTVOSRichMediaPosition: Int {
    /// Content positioned at the center of the screen (default)
    case center = 0
    /// Content positioned at the left side of the screen
    case left
    /// Content positioned at the right side of the screen
    case right
    /// Content positioned at the top of the screen
    case top
    /// Content positioned at the bottom of the screen
    case bottom
}

/**
 Protocol for handling tvOS-specific features in Pushwoosh.

 This protocol provides an interface for tvOS-specific functionality that can be
 optionally included in the project. If the PushwooshTVOS module is not linked,
 a stub implementation will be used instead.
 */
@objc
public protocol PWTVoS {
    // MARK: - Configuration

    /**
     Sets the Pushwoosh application code for tvOS.

     This method must be called before registering for push notifications.
     The app code can be found in your Pushwoosh Control Panel.

     - Parameter appCode: The Pushwoosh application identifier.

     Example:
     ```swift
     Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")
     ```
     */
    @objc
    static func setAppCode(_ appCode: String)

    // MARK: - Registration

    /**
     Registers for tvOS push notifications.

     This method requests push notification authorization and registers the device
     for remote notifications on tvOS.
     */
    @objc
    static func registerForTvPushNotifications()

    /**
     Registers the tvOS device for push notifications with the Pushwoosh server.

     Call this method after receiving a device token from Apple Push Notification service.
     This method sends the device token to Pushwoosh servers to enable push notifications.

     - Parameters:
       - token: The device token received from APNs in `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
       - completion: Optional completion handler called when registration completes. The handler receives an error parameter if registration fails, or nil on success.

     Example:
     ```swift
     func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
         Pushwoosh.TVoS.registerForTvPushNotifications(withToken: deviceToken) { error in
             if let error = error {
                 print("Failed to register: \(error)")
             } else {
                 print("Successfully registered for push notifications")
             }
         }
     }
     ```
     */
    @objc
    static func registerForTvPushNotifications(withToken token: Data, completion: ((Error?) -> Void)?)

    /**
     Unregisters the tvOS device from receiving push notifications.

     This method removes the device registration from Pushwoosh servers.
     The device will no longer receive push notifications until it registers again.

     - Parameter completion: Optional completion handler called when unregistration completes. The handler receives an error parameter if unregistration fails, or nil on success.

     Example:
     ```swift
     Pushwoosh.TVoS.unregisterForTvPushNotifications { error in
         if let error = error {
             print("Failed to unregister: \(error)")
         } else {
             print("Successfully unregistered from push notifications")
         }
     }
     ```
     */
    @objc
    static func unregisterForTvPushNotifications(completion: ((Error?) -> Void)?)

    // MARK: - AppDelegate Helpers

    /**
     Handles the device token received from tvOS push registration.

     - Parameter deviceToken: The device token data received from APNs.
     */
    @objc
    static func handleTvPushToken(_ deviceToken: Data)

    /**
     Handles push registration failure on tvOS.

     Call this method from application:didFailToRegisterForRemoteNotificationsWithError:
     to log and handle registration errors.

     - Parameter error: The error that occurred during registration.
     */
    @objc
    static func handleTvPushRegistrationFailure(_ error: Error)

    /**
     Handles incoming push notification on tvOS.

     Call this method from application:didReceiveRemoteNotification:fetchCompletionHandler:
     to process incoming push notifications.

     - Parameter userInfo: Dictionary containing push payload data.
     - Parameter completionHandler: Completion handler to call when processing is complete.
     */
    @objc
    static func handleTvPushReceived(userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void)

    // MARK: - Rich Media

    /**
     Handles incoming push notifications with rich media content for tvOS.

     Call this method to process push notifications that may contain rich media content.
     If the notification contains rich media, it will be displayed automatically.

     - Parameter userInfo: The push notification payload received from APNs.
     - Returns: `true` if the notification contains rich media and was handled, `false` otherwise.

     Example:
     ```swift
     func application(_ application: UIApplication,
                      didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
         if Pushwoosh.TVoS.handleTVOSPush(userInfo: userInfo) {
             completionHandler(.newData)
         } else {
             completionHandler(.noData)
         }
     }
     ```
     */
    @objc
    static func handleTVOSPush(userInfo: [AnyHashable: Any]) -> Bool

    /**
     Configures rich media presentation, positioning, and dismissal animations for tvOS.

     This method allows you to customize how rich media content appears, where it's positioned,
     and how it disappears on screen. You can choose from different animation directions,
     screen positions, or disable animation entirely.

     - Parameter position: The screen position where rich media content will be displayed.
       Available options:
       - `.center` - Content positioned at the center of the screen (default)
       - `.left` - Content positioned at the left side of the screen
       - `.right` - Content positioned at the right side of the screen
       - `.top` - Content positioned at the top of the screen
       - `.bottom` - Content positioned at the bottom of the screen

     - Parameter presentAnimation: The animation type to use when presenting rich media.
       Available options:
       - `.none` - No animation, content appears immediately (default)
       - `.fromTop` - Content slides in from the top of the screen
       - `.fromBottom` - Content slides in from the bottom of the screen
       - `.fromLeft` - Content slides in from the left side of the screen
       - `.fromRight` - Content slides in from the right side of the screen

     - Parameter dismissAnimation: The animation type to use when dismissing rich media.
       Available options:
       - `.none` - No animation, content disappears immediately (default)
       - `.toTop` - Content slides out to the top of the screen
       - `.toBottom` - Content slides out to the bottom of the screen
       - `.toLeft` - Content slides out to the left side of the screen
       - `.toRight` - Content slides out to the right side of the screen

     Example:
     ```swift
     // Configure rich media to appear on the left, slide in from bottom and slide out to left
     Pushwoosh.TVoS.configureRichMediaWith(position: .left, presentAnimation: .fromBottom, dismissAnimation: .toLeft)

     // Only configure position and present animation (dismiss will use .none)
     Pushwoosh.TVoS.configureRichMediaWith(position: .right, presentAnimation: .fromTop, dismissAnimation: .none)
     ```

     Note: This configuration applies to all subsequent rich media presentations until changed.
     */
    @objc
    static func configureRichMediaWith(position: PWTVOSRichMediaPosition, presentAnimation: PWTVOSRichMediaPresentAnimation, dismissAnimation: PWTVOSRichMediaDismissAnimation)

    /**
     Controls whether the Close button is displayed on rich media content.

     By default, a Close button is shown at the bottom of rich media presentations,
     allowing users to dismiss the content. You can hide this button if you want
     rich media to only be dismissible through button actions within the content itself.

     - Parameter show: `true` to show the Close button (default), `false` to hide it.

     Example:
     ```swift
     // Hide the system Close button
     Pushwoosh.TVoS.configureCloseButton(false)
     ```

     Note: If you hide the Close button, ensure your rich media content includes
     a button with the `closeInApp` action to allow users to dismiss it.
     */
    @objc
    static func configureCloseButton(_ show: Bool)
}
