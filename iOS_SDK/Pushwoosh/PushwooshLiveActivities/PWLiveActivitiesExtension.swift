//
//  PWLiveActivitiesExtension.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//
#if !targetEnvironment(macCatalyst) && os(iOS)

import Foundation
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
    /// for your custom ``PushwooshLiveActivityAttributes`` type. Call this during app initialization,
    /// typically in `application(_:didFinishLaunchingWithOptions:)`.
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
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(activityId, attributes: attributes, content: content)
    }
}
#endif
