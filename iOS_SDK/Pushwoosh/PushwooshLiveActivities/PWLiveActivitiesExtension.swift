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
    static func sendPushToStartLiveActivity(token: String) {
        PushwooshLiveActivitiesImplementationSetup.sendPushToStartLiveActivity(token: token)
    }
    static func sendPushToStartLiveActivity(token: String, completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.sendPushToStartLiveActivity(token: token, completion: completion)
    }
    
    static func startLiveActivity(token: String, activityId: String) {
        PushwooshLiveActivitiesImplementationSetup.startLiveActivity(token: token, activityId: activityId)
    }
    static func startLiveActivity(token: String, activityId: String, completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.startLiveActivity(token: token, activityId: activityId, completion: completion)
    }
    
    static func stopLiveActivity() {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity()
    }
    static func stopLiveActivity(completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(completion: completion)
    }
    
    static func stopLiveActivity(activityId: String) {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(activityId: activityId)
    }
    static func stopLiveActivity(activityId: String, completion: @escaping (Error?) -> Void) {
        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(activityId: activityId, completion: completion)
    }

    /**
     Sets up the Pushwoosh live activity for the specified attributes.
     
     This method configures the live activity using the provided `Attributes` type,
     which must conform to the `PushwooshLiveActivityAttributes` protocol. It is only
     available for iOS versions 16.1 and above.
     
     - Parameter activityType: The type of the activity attributes to be set up. This should be a
     type that conforms to the `PushwooshLiveActivityAttributes` protocol.
     
     - Note: Ensure that your app is running on iOS 16.1 or later before calling this method,
     as it will not be available on earlier versions.
     */
    @available(iOS 16.1, *)
    static func setup<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(activityType)
    }
    
    /**
     Configures the Pushwoosh SDK to manage the default `DefaultLiveActivityAttributes` structure, which conforms to the
     `PushwooshLiveActivityAttributes` protocol. By using this function, the widget attributes are controlled by the Pushwoosh SDK,
     enabling the SDK to handle the entire lifecycle of the live activity. From the app's perspective, the only requirement is to create
     a Live Activity widget within a widget extension, including an `ActivityConfiguration` for `DefaultLiveActivityAttributes`.
     
     This approach is particularly useful for scenarios where:
     1. There is only one Live Activity widget in the app.
     2. A cross-platform framework is used, and the developer wants to avoid creating bindings between the framework and iOS native
        ActivityKit.
     */
    @available(iOS 16.1, *)
    static func defaultSetup() {
        PushwooshLiveActivitiesImplementationSetup.defaultSetup()
    }
    
    /**
     Starts a new Live Activity modeled by the `DefaultLiveActivityAttributes` structure. The `DefaultLiveActivityAttributes`
     is initialized using the dynamic `attributes` and `content` provided.

     - Parameters:
       - activityId: The identifier for the live activity on this device, which will be used to start the activity and make it eligible for updates.
       - attributes: A dictionary containing the static attributes to initialize `DefaultLiveActivityAttributes`.
       - content: A dictionary containing the initial content state to initialize `DefaultLiveActivityAttributes`.
     */
    @available(iOS 16.1, *)
    static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(activityId, attributes: attributes, content: content)
    }
}
#endif
