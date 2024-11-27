//
//  PushwooshLiveActivitiesImplementationSetup.swift
//  Pushwoosh
//
//  Created by André Kis on 08.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst)
import Foundation
import ActivityKit

enum LiveActivityError: Error {
    case incorrectTypeLA(String)
}

public class PushwooshLiveActivitiesImplementationSetup: NSObject {
    
    /**
     Configures the live activity for the specified attributes.
     
     This method sets up the live activity using the provided `Attributes` type, which
     must conform to the `PushwooshLiveActivityAttributes` protocol. It observes
     push notifications for starting the live activity and general activity updates.
     The method is only available for iOS versions 16.1 and above.
     
     - Parameter activityType: The type of the activity attributes to be configured. This
     should be a type that conforms to the `PushwooshLiveActivityAttributes` protocol.
     
     - Note: If the app is running on iOS 17.2 or later, it will additionally observe
     push notifications specifically for starting the live activity.
     */
    @available(iOS 16.1, *)
    static func configureLiveActivity<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        if #available(iOS 17.2, *) {
            observePushToStart(activityType)
        }
        observeActivity(activityType)
    }
    
    @available(iOS 16.1, *)
    public static func defaultSetup() {
        configureLiveActivity(DefaultLiveActivityAttributes.self)
    }
    
    @objc
    @available(iOS 16.1, *)
    public static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        let pushwooshAttribute = PushwooshLiveActivityAttributeData.create(activityId: activityId)

        var attributeData = [String: AnyCodable]()
        for attribute in attributes {
            attributeData.updateValue(AnyCodable(attribute.value), forKey: attribute.key)
        }

        var contentData = [String: AnyCodable]()
        for contentItem in content {
            contentData.updateValue(AnyCodable(contentItem.value), forKey: contentItem.key)
        }

        let attributes = DefaultLiveActivityAttributes(data: attributeData, pushwoosh: pushwooshAttribute)
        let contentState = DefaultLiveActivityAttributes.ContentState(data: contentData)
        do {
            _ = try Activity<DefaultLiveActivityAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: .token)
        } catch let error {
            print("Start default live activity error: \(error.localizedDescription)")
        }
    }

    // MARK: - OBSERVE PUSH TO START TOKEN
    @available(iOS 17.2, *)
    private static func observePushToStart<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        Task {
            for try await data in Activity<Attributes>.pushToStartTokenUpdates {
                let token = data.map { String(format: "%02x", $0) }.joined()
                setPushToStartToken(activityType, withToken: token)
            }
        }
    }
    
    @available(iOS 17.2, *)
    public static func setPushToStartToken<Attributes: ActivityAttributes>(_ activityType: Attributes.Type, withToken: String) {
        do {
            try validateAndSendPushToken(for: "\(activityType)", withToken: withToken)
        } catch {
            print("Failed to set push token for activity type \(activityType): \(error.localizedDescription)")
        }
    }
    
    @available(iOS 17.2, *)
    private static func validateAndSendPushToken(for activityType: String, withToken: String) throws {
        guard activityType.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) != nil else {
            throw LiveActivityError.incorrectTypeLA("Unable to convert activity type to a URL-encoded string.")
        }
        
        Pushwoosh.sharedInstance().sendPush(toStartLiveActivityToken: withToken)
    }
    
    // MARK: - OBSERVE LIVE ACTIVITY
    @available(iOS 16.1, *)
    private static func observeActivity<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        Task {
            for await activity in Activity<Attributes>.activityUpdates {
                if #available(iOS 16.2, *) {
                    handleMultipleActivities(activity, for: activityType)
                }
                observeActivityStateUpdates(activity, for: activityType)
                observeActivityPushTokenUpdates(activity, for: activityType)
            }
        }
    }
    
    @available(iOS 16.2, *)
    private static func handleMultipleActivities<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) {
        for otherActivity in Activity<Attributes>.activities {
            if activity.id != otherActivity.id && otherActivity.attributes.pushwoosh.activityId == activity.attributes.pushwoosh.activityId {
                Task {
                    await otherActivity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
    
    @available(iOS 16.1, *)
    private static func observeActivityStateUpdates<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) {
        Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed:
                    try await Pushwoosh.sharedInstance().stopLiveActivity(with: activity.attributes.pushwoosh.activityId)
                default:
                    break
                }
            }
        }
    }
    
    @available(iOS 16.1, *)
    private static func observeActivityPushTokenUpdates<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) {
        Task {
            for await pushToken in activity.pushTokenUpdates {
                let token = pushToken.map { String(format: "%02x", $0) }.joined()
                try await Pushwoosh.sharedInstance().startLiveActivity(withToken: token, activityId: activity.attributes.pushwoosh.activityId)
            }
        }
    }
}
#endif
