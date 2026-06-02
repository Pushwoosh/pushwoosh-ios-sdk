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

    /// Configures Live Activities with default Pushwoosh-managed attributes.
    ///
    /// Registers the bundled `DefaultLiveActivityAttributes` type with Pushwoosh so that
    /// push-to-start tokens and per-activity tokens flow automatically, without the integrator
    /// having to declare a custom `ActivityAttributes` struct.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if #available(iOS 16.1, *) {
    ///     Pushwoosh.LiveActivities.defaultSetup()
    /// }
    /// ```
    ///
    /// > Important: Available on iOS 16.1+. Call once during app launch. Repeat calls are no-ops.
    /// > Obj-C / plugin callers (RN, Flutter, etc.) are additionally protected by a runtime
    /// > availability guard inside the implementation — calling on iOS < 16.1 is a logged no-op.
    @available(iOS 16.1, *)
    static func defaultSetup()

    /// Starts a Live Activity using the default Pushwoosh-managed attributes.
    ///
    /// Constructs a `DefaultLiveActivityAttributes` instance from the supplied dictionaries
    /// and requests a new activity. Use this when you do not need a custom attributes/state struct.
    ///
    /// - Parameters:
    ///   - activityId: Unique identifier for this activity instance used for targeting updates.
    ///   - attributes: Static attribute dictionary that does not change across the activity lifetime.
    ///   - content: Initial dynamic content-state dictionary rendered by the widget.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if #available(iOS 16.1, *) {
    ///     Pushwoosh.LiveActivities.defaultStart(
    ///         "order_123",
    ///         attributes: ["orderName": "Pizza"],
    ///         content: ["status": "Preparing"]
    ///     )
    /// }
    /// ```
    ///
    /// > Important: Available on iOS 16.1+. Must be paired with `defaultSetup()` called earlier in the launch path.
    /// > Obj-C / plugin callers are additionally protected by a runtime availability guard
    /// > inside the implementation — calling on iOS < 16.1 is a logged no-op.
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any])

    /// Starts a Live Activity using the default Pushwoosh-managed attributes with completion handler.
    ///
    /// - Parameters:
    ///   - activityId: Unique identifier for this activity instance used for targeting updates.
    ///   - attributes: Static attribute dictionary that does not change across the activity lifetime.
    ///   - content: Initial dynamic content-state dictionary rendered by the widget.
    ///   - completion: Completion handler called with `nil` on success or an `Error` if the
    ///     OS version is below 16.1 or `Activity.request()` throws.
    ///
    /// > Important: Available on iOS 16.1+. Obj-C / plugin callers are additionally protected
    /// > by a runtime availability guard — calling on iOS < 16.1 invokes the completion with
    /// > an `Error` describing the unsupported OS version.
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any], completion: @escaping (Error?) -> Void)
}

// Default no-op fallbacks for external conformers (custom mocks / test doubles).
// The concrete `PushwooshLiveActivitiesImplementationSetup` overrides these —
// when the module is not linked, `PushwooshModuleRegistry` returns
// `PWMissingModule` which forwards all selectors to a logged no-op. These
// defaults exist only so that future external conformers don't break
// source-compatibility when new requirements land on the protocol.
//
// `defaultStart(...:completion:)` returns an explicit error so an integrator's custom conformer
// that forgets to override doesn't silently report success — surfacing the gap to the caller.
public extension PWLiveActivities {
    @available(iOS 16.1, *)
    static func defaultSetup() { }
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) { }
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any], completion: @escaping (Error?) -> Void) {
        let error = NSError(
            domain: "pushwoosh",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey:
                "defaultStart(_:attributes:content:completion:) is not implemented by this PWLiveActivities conformer."])
        completion(error)
    }
}
