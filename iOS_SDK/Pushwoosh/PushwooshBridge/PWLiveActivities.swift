//
//  PWLiveActivities.swift
//  PushwooshOSCore
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

@objc
public protocol PWLiveActivities {    
    /**
     Sends push to start live activity token to the server.
     Call this method when you want to initiate live activity via push notification
          
     This method should be called when you want to send the push token to the server in order to initiate a live activity via a push notification. Once the token is sent to the server, it allows you to remotely trigger and manage the live activity through push notifications.
     
     Example:
     
     ```
     if #available(iOS 17.2, *) {
             Task {
                 for await data in Activity<LiveActivityAttributes>.pushToStartTokenUpdates {
                     let token = data.map { String(format: "%02x", $0) }.joined()
                     do {
                         try await Pushwoosh.LiveActivities.sendPush(toStartLiveActivityToken: "token")
                     } catch {
                         print("Error sending push to start live activity: \(error)")
                     }
                }
            }
      }
     ```
     */
    static func sendPushToStartLiveActivity(token: String)
    static func sendPushToStartLiveActivity(token: String, completion: @escaping (Error?) -> Void)
    
    /**
     Sends live activity token to the server.
     Call this method when you create a live activity.
     
     This method sends the activity token and activity ID to the server when a live activity is started on the user's device. It handles the asynchronous request to notify the server about the new activity. Ensure that both the token and activity ID are valid before calling this method to avoid potential issues.
     
     Example:
     
     ```
     do {
         let activity = try Activity<PushwooshAppAttributes>.request(
             attributes: attributes,
             contentState: contentState,
             pushType: .token)
         
         for await data in activity.pushTokenUpdates {
             guard let token = data.map { String(format: "%02x", $0) }.joined(separator: "") else {
                 continue
             }
             
             do {
                 try await Pushwoosh.LiveActivities.startLiveActivity(token: "token", activityId: "activityId")
                 return token
             } catch {
                 print("Failed to start live activity with token \(token): \(error.localizedDescription)")
                 return nil
             }
         }
         return nil
     } catch {
         print("Error requesting activity: \(error.localizedDescription)")
         return nil
     }
     ```
     
     @param token Activity token
     @param activityId Activity ID for updating Live Activities by segments
     */
    static func startLiveActivity(token: String, activityId: String)
    static func startLiveActivity(token: String, activityId: String, completion: @escaping (Error?) -> Void)

    /**
     Call this method when you finish working with the live activity and want to notify the server that the activity has ended.
     This does **not** stop or remove the activity from the device itself; it simply informs the server that the activity has been completed.
     
     This method should be called when you finish working with the live activity. It sends a request to the server to notify that the live activity has been completed. Typically, this is called when the user has completed the task or interaction that was being tracked by the live activity.
     The server can then process this information and take appropriate actions based on the completion status of the live activity.
     
     Example:
     ```
     func end(activity: Activity<PushwooshAppAttributes>) {
         Task {
             await activity.end(dismissalPolicy: .immediate)
             try await Pushwoosh.LiveActivities.stopLiveActivity()
         }
     }
     ```
     */
    static func stopLiveActivity()
    static func stopLiveActivity(completion: @escaping (Error?) -> Void)

    /**
     Call this method when you finish working with the live activity and want to notify the server that the activity has ended.
     This does **not** stop or remove the activity from the device itself; it simply informs the server that the activity has been completed.
     
     This method should be called when you finish working with the live activity. It sends a request to the server to notify that the live activity has been completed. Typically, this is called when the user has completed the task or interaction that was being tracked by the live activity.
     The server can then process this information and take appropriate actions based on the completion status of the live activity.

     The `activityId` is a unique identifier for the live activity instance. It is used to reference the specific activity that is being completed. This ID should be passed to the server so it can associate the completion notification with the correct live activity.
     
     Example:
     ```
     func end(activity: Activity<PushwooshAppAttributes>) {
         Task {
             await activity.end(dismissalPolicy: .immediate)
             try await Pushwoosh.LiveActivities.stopLiveActivity(activityId: "activityId")
         }
     }
     ```
     */
    static func stopLiveActivity(activityId: String)
    static func stopLiveActivity(activityId: String, completion: @escaping (Error?) -> Void)
}
