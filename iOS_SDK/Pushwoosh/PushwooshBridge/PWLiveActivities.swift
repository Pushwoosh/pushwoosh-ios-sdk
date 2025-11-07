//
//  PWLiveActivities.swift
//  PushwooshOSCore
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

/// Protocol for managing iOS Live Activities with Pushwoosh push notifications.
@objc
public protocol PWLiveActivities {
    /// Sends push-to-start token to enable remote activity initiation.
    ///
    /// Call this method when you want to register a push-to-start token with Pushwoosh server.
    /// Once the token is sent, it allows remote triggering of Live Activities through push notifications.
    ///
    /// - Parameter token: The push-to-start token from ActivityKit.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if #available(iOS 17.2, *) {
    ///     Task {
    ///         for await data in Activity<LiveActivityAttributes>.pushToStartTokenUpdates {
    ///             let token = data.map { String(format: "%02x", $0) }.joined()
    ///             Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: token)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// > Important: Available on iOS 17.2+. Use `setup()` method for automatic token management.
    static func sendPushToStartLiveActivity(token: String)

    /// Sends push-to-start token to enable remote activity initiation with completion handler.
    ///
    /// - Parameters:
    ///   - token: The push-to-start token from ActivityKit.
    ///   - completion: Completion handler called when the request finishes.
    static func sendPushToStartLiveActivity(token: String, completion: @escaping (Error?) -> Void)

    /// Registers an active Live Activity with the server.
    ///
    /// Call this method when you create a Live Activity to register its push token with Pushwoosh server.
    /// This allows the server to send push notification updates to this specific activity instance.
    ///
    /// - Parameters:
    ///   - token: The activity push token from ActivityKit.
    ///   - activityId: Unique identifier for this activity instance used for targeting updates.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let activity = try Activity<FoodDeliveryAttributes>.request(
    ///         attributes: attributes,
    ///         contentState: contentState,
    ///         pushType: .token
    ///     )
    ///
    ///     for await data in activity.pushTokenUpdates {
    ///         let token = data.map { String(format: "%02x", $0) }.joined()
    ///         Pushwoosh.LiveActivities.startLiveActivity(token: token, activityId: "order_123")
    ///     }
    /// } catch {
    ///     print("Error starting activity: \(error)")
    /// }
    /// ```
    ///
    /// > Important: Use `setup()` method for automatic token management.
    static func startLiveActivity(token: String, activityId: String)

    /// Registers an active Live Activity with the server with completion handler.
    ///
    /// - Parameters:
    ///   - token: The activity push token from ActivityKit.
    ///   - activityId: Unique identifier for this activity instance.
    ///   - completion: Completion handler called when the request finishes.
    static func startLiveActivity(token: String, activityId: String, completion: @escaping (Error?) -> Void)

    /// Notifies the server that all Live Activities have ended.
    ///
    /// Call this method after ending a Live Activity on the device to inform Pushwoosh server.
    /// This prevents the server from sending updates to activities that no longer exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func endActivity(activity: Activity<FoodDeliveryAttributes>) async {
    ///     await activity.end(dismissalPolicy: .immediate)
    ///     Pushwoosh.LiveActivities.stopLiveActivity()
    /// }
    /// ```
    ///
    /// > Important: This does not end the activity on the device. Call `activity.end()` first, then notify the server.
    static func stopLiveActivity()

    /// Notifies the server that all Live Activities have ended with completion handler.
    ///
    /// - Parameter completion: Completion handler called when the request finishes.
    static func stopLiveActivity(completion: @escaping (Error?) -> Void)

    /// Notifies the server that a specific Live Activity has ended.
    ///
    /// Call this method after ending a Live Activity on the device to inform Pushwoosh server.
    /// Use this variant when managing multiple activities to stop only a specific one.
    ///
    /// - Parameter activityId: The unique identifier of the activity that ended.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func endActivity(activity: Activity<FoodDeliveryAttributes>) async {
    ///     let activityId = activity.attributes.pushwoosh.activityId
    ///     await activity.end(dismissalPolicy: .immediate)
    ///     Pushwoosh.LiveActivities.stopLiveActivity(activityId: activityId)
    /// }
    /// ```
    ///
    /// > Important: This does not end the activity on the device. Call `activity.end()` first, then notify the server.
    static func stopLiveActivity(activityId: String)

    /// Notifies the server that a specific Live Activity has ended with completion handler.
    ///
    /// - Parameters:
    ///   - activityId: The unique identifier of the activity that ended.
    ///   - completion: Completion handler called when the request finishes.
    static func stopLiveActivity(activityId: String, completion: @escaping (Error?) -> Void)
}
