//
//  PushwooshSwiftInterface.swift
//  Pushwoosh
//
//  Created by André Kis on 08.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//
#if !targetEnvironment(macCatalyst)
import Foundation

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
}
#endif
