//
//  PWLiveActivitiesExtension.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//
#if !targetEnvironment(macCatalyst) && os(iOS)

import Foundation
import ActivityKit
import PushwooshCore
import PushwooshBridge

public extension PWLiveActivities {
    /// Sends push-to-start token to enable remote activity initiation.
    ///
    /// - Parameter token: The push-to-start token from ActivityKit.
    static func sendPushToStartLiveActivity(token: String) {
        PushwooshLiveActivitiesImplementationSetup.sendPushToStartLiveActivity(token: token)
    }

    /// Sends push-to-start token to enable remote activity initiation with completion handler.
    ///
    /// - Parameters:
    ///   - token: The push-to-start token from ActivityKit.
    ///   - completion: Completion handler called when the request finishes.
    static func sendPushToStartLiveActivity(token: String, completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.sendPushToStartLiveActivity(token: token, completion: completion)
    }

    /// Registers an active Live Activity with the server.
    ///
    /// - Parameters:
    ///   - token: The activity push token from ActivityKit.
    ///   - activityId: Unique identifier for this activity instance.
    static func startLiveActivity(token: String, activityId: String) {
        PushwooshLiveActivitiesImplementationSetup.startLiveActivity(token: token, activityId: activityId)
    }

    /// Registers an active Live Activity with the server with completion handler.
    ///
    /// - Parameters:
    ///   - token: The activity push token from ActivityKit.
    ///   - activityId: Unique identifier for this activity instance.
    ///   - completion: Completion handler called when the request finishes.
    static func startLiveActivity(token: String, activityId: String, completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.startLiveActivity(token: token, activityId: activityId, completion: completion)
    }

    /// Notifies the server that all Live Activities have ended.
    static func stopLiveActivity() {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity()
    }

    /// Notifies the server that all Live Activities have ended with completion handler.
    ///
    /// - Parameter completion: Completion handler called when the request finishes.
    static func stopLiveActivity(completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(completion: completion)
    }

    /// Notifies the server that a specific Live Activity has ended.
    ///
    /// - Parameter activityId: The unique identifier of the activity that ended.
    static func stopLiveActivity(activityId: String) {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(activityId: activityId)
    }

    /// Notifies the server that a specific Live Activity has ended with completion handler.
    ///
    /// - Parameters:
    ///   - activityId: The unique identifier of the activity that ended.
    ///   - completion: Completion handler called when the request finishes.
    static func stopLiveActivity(activityId: String, completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(activityId: activityId, completion: completion)
    }

    /// Configures Live Activities with custom attributes.
    ///
    /// This method sets up automatic token registration and activity lifecycle management
    /// for your custom ``PushwooshLiveActivityAttributes`` type.
    ///
    /// > Important: Call this for **every** attributes type you use, at app launch — in
    /// > `application(_:didFinishLaunchingWithOptions:)` (or the `App.init` for SwiftUI apps).
    /// > This is what re-attaches the SDK to activities that are **already running** at launch and
    /// > re-uploads their per-activity push token to the server, so remote updates keep working after
    /// > a cold start — including an activity that started (or was scheduled to start) while the app was
    /// > terminated. This is a required, one-time-per-launch call, not tied to any screen: ActivityKit
    /// > exposes running activities only through the concrete `Activity<Attributes>` generic and does
    /// > not persist the set of types across launches, so the SDK cannot reconnect a type it hasn't been
    /// > told about in the current session. Registering a type lazily (e.g. in a view's `onAppear`)
    /// > means the server can't update that activity until that screen is opened. The call is idempotent,
    /// > so registering at launch and again per-screen is safe.
    ///
    /// - Parameter activityType: Your custom attributes type conforming to ``PushwooshLiveActivityAttributes``.
    @available(iOS 16.1, *)
    static func setup<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(activityType)
    }

    /// Configures Live Activities with default attributes managed by Pushwoosh.
    ///
    /// This method sets up automatic lifecycle management using ``DefaultLiveActivityAttributes``.
    /// Use this when you want the SDK to handle all activity management without defining custom types.
    ///
    /// This approach is particularly useful for scenarios where:
    /// - You have only one Live Activity widget in the app
    /// - You're using a cross-platform framework and want to avoid creating native bindings
    ///
    /// > Important: Available on iOS 16.1+. Obj-C / plugin callers are additionally
    /// > protected by a runtime guard — calling on iOS < 16.1 is a logged no-op.
    @available(iOS 16.1, *)
    static func defaultSetup() {
        PushwooshLiveActivitiesImplementationSetup.defaultSetup()
    }

    /// Starts a Live Activity using default attributes.
    ///
    /// - Parameters:
    ///   - activityId: Unique identifier for this activity instance.
    ///   - attributes: Static attributes dictionary.
    ///   - content: Initial content state dictionary.
    ///
    /// > Important: Available on iOS 16.1+. Obj-C / plugin callers are additionally
    /// > protected by a runtime guard — calling on iOS < 16.1 is a logged no-op.
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(activityId, attributes: attributes, content: content)
    }

    /// Starts a Live Activity using default attributes with a completion handler.
    ///
    /// - Parameters:
    ///   - activityId: Unique identifier for this activity instance.
    ///   - attributes: Static attributes dictionary.
    ///   - content: Initial content state dictionary.
    ///   - completion: Completion handler called with `nil` on success or an `Error` if the
    ///     OS version is below 16.1 or `Activity.request()` throws.
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any], completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(activityId, attributes: attributes, content: content, completion: completion)
    }

    /// Schedules a Live Activity with your custom attributes type to start at a future date.
    ///
    /// The activity is created in the `pending` state and the system starts it at `startDate` — even
    /// if the app is backgrounded by then. Token registration happens automatically through the
    /// observers installed by ``setup(_:)``. This wraps the iOS 26 `Activity.request(start:)` API and
    /// hides its boilerplate: the mandatory alert, the activity style, and `ActivityContent` wrapping.
    ///
    /// - Parameters:
    ///   - attributes: Your activity's static attributes instance.
    ///   - contentState: The initial dynamic content state shown until the first update.
    ///   - startDate: The future date at which the system starts the activity. Must be in the future.
    ///   - alertTitle: Title of the alert the system shows when the scheduled activity starts.
    ///   - alertBody: Body of the alert the system shows when the scheduled activity starts.
    /// - Returns: The created (pending) `Activity`.
    /// - Throws: An `Error` if `startDate` is not in the future, or whatever `Activity.request()` throws
    ///   (for example `ActivityAuthorizationError` when Live Activities are disabled).
    ///
    /// > Important: Available on iOS 26.0+. Call on the main thread while the app is in the foreground.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if #available(iOS 26.0, *) {
    ///     let activity = try Pushwoosh.LiveActivities.schedule(
    ///         attributes: MatchAttributes(teams: "Lakers vs Celtics"),
    ///         contentState: MatchAttributes.ContentState(score: "0:0", pushwoosh: nil),
    ///         at: kickoffDate,
    ///         alertTitle: "Game starting!",
    ///         alertBody: "Lakers vs Celtics is about to begin")
    /// }
    /// ```
    @available(iOS 26.0, *)
    @MainActor
    @discardableResult
    static func schedule<Attributes: PushwooshLiveActivityAttributes>(
        attributes: Attributes,
        contentState: Attributes.ContentState,
        at startDate: Date,
        alertTitle: String,
        alertBody: String
    ) throws -> Activity<Attributes> {
        try PushwooshLiveActivitiesImplementationSetup.schedule(
            attributes, contentState: contentState, at: startDate,
            alertTitle: alertTitle, alertBody: alertBody)
    }

    /// Schedules a Live Activity using default attributes to start at a future date.
    ///
    /// > Important: Available on iOS 26.0+. Obj-C / plugin callers are additionally protected by a
    /// > runtime guard — calling on iOS < 26.0 is a logged no-op.
    @available(iOS 26.0, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any],
                             at startDate: Date, alertTitle: String, alertBody: String) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(
            activityId, attributes: attributes, content: content,
            at: startDate, alertTitle: alertTitle, alertBody: alertBody)
    }

    /// Schedules a Live Activity using default attributes to start at a future date, with a completion handler.
    @available(iOS 26.0, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any],
                             at startDate: Date, alertTitle: String, alertBody: String,
                             completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(
            activityId, attributes: attributes, content: content,
            at: startDate, alertTitle: alertTitle, alertBody: alertBody, completion: completion)
    }

    /// Cancels a scheduled (or ends a running) Live Activity by its Pushwoosh `activityId`.
    ///
    /// Ends every `Activity<Attributes>` whose `pushwoosh.activityId` matches — a pending (scheduled)
    /// one is cancelled before it starts — and notifies the Pushwoosh server. No `Activity` reference needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if #available(iOS 16.2, *) {
    ///     Pushwoosh.LiveActivities.cancel(MatchAttributes.self, activityId: "wc_final")
    /// }
    /// ```
    ///
    /// > Important: Available on iOS 16.2+ — ending an activity uses `Activity.end(_:dismissalPolicy:)`.
    @available(iOS 16.2, *)
    static func cancel<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type, activityId: String) {
        PushwooshLiveActivitiesImplementationSetup.cancel(activityType, activityId: activityId)
    }
}
#endif
