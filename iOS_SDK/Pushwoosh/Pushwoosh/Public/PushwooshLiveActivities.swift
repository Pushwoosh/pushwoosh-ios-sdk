//
//  PushwooshSwiftInterface.swift
//  Pushwoosh
//
//  Created by André Kis on 08.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//
#if !targetEnvironment(macCatalyst)
import Foundation

@objc
public class PushwooshLiveActivities: NSObject {
    
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
    public static func setup<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
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

     - Parameters:
       - options: An optional parameter for providing more detailed configuration options.
     */
    @available(iOS 16.1, *)
    @objc
    public static func defaultSetup() {
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
    @objc
    public static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        PushwooshLiveActivitiesImplementationSetup.defaultStart(activityId, attributes: attributes, content: content)
    }
}
#endif
