//
//  DefaultLiveActivityAttributes.swift
//  PushwooshiOS
//
//  Created by André Kis on 26.11.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if targetEnvironment(macCatalyst)
#else

/**
 A default structure conforming to `PushwooshLiveActivityAttributes` that is registered with Pushwoosh as a Live Activity
 through `PushwooshLiveActivities.defaultSetup()`. The only requirement for the customer app is to create a Widget
 in their Widget Extension with an `ActivityConfiguration` for `DefaultLiveActivityAttributes`.

 All properties (attributes and content-state) within this widget are dynamically defined as a dictionary of values
 in the static `data` property. Note that the `data` properties must be included in the payloads.

 Example "start notification" payload using `DefaultLiveActivityAttributes`:
 
 ```
 "live_activity": {
    "event": "start",
        "content-state": {
            "data" : {
                "yourKey": "yourValue"
            }
        },
    "attributes-type": "DefaultLiveActivityAttributes",
        "attributes": {
            "data" : {
                "youKey": "yourValue"
        }
    }
 
 ```
 
 Example "update notification" payload using `DefaultLiveActivityAttributes`:
 
 ```
 "live_activity": {
   "event": "update",
     "content-state": {
         "data": {
             "yourKey": "yourValue"
         }
     },
     "attributes-type": "DefaultLiveActivityAttributes",
         "attributes": {
             "data" : {
                 "yourKey": "yourValue"
             }
      }
 }
 
 ```
 */

public struct DefaultLiveActivityAttributes: PushwooshLiveActivityAttributes {
    public var data: [String: AnyCodable]
    public var pushwoosh: PushwooshLiveActivityAttributeData
    
    public struct ContentState: PushwooshLiveActivityContentState {
        public var data: [String: AnyCodable]
        public var pushwoosh: PushwooshLiveActivityContentStateData?
    }
}
#endif
