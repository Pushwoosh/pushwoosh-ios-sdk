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
import PushwooshCore
import PushwooshBridge

enum LiveActivityError: Error {
    case incorrectTypeLA(String)
}

@objc(PushwooshLiveActivitiesImplementationSetup)
public class PushwooshLiveActivitiesImplementationSetup: NSObject, PWLiveActivities {
    
    public static func sendPushToStartLiveActivity(token: String) {
        sendPushToStartLiveActivity(token: token, completion: { _ in })
    }
    
    public static func sendPushToStartLiveActivity(token: String, completion: @escaping (((any Error)?) -> Void)) {
        let requestParameters = ActivityRequestParameters(pushToStartToken: token)
        let requst = PWRequestSetPushToStartToken(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: requst, completion: completion)
    }
    
    public static func startLiveActivity(token: String, activityId: String) {
        startLiveActivity(token: token, activityId: activityId, completion: { _ in })
    }
    
    public static func startLiveActivity(token: String, activityId: String, completion: @escaping ((any Error)?) -> Void) {
        let requestParameters = ActivityRequestParameters(activityId: activityId, token: token)
        let request = PWRequestSetActivityToken(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: request, completion: completion)
    }
    
    public static func stopLiveActivity() {
        stopLiveActivity(completion: { _ in })
    }
    
    public static func stopLiveActivity(completion: @escaping ((any Error)?) -> Void) {
        let request = PWRequestStopLiveActivity(parameters: ActivityRequestParameters())
        NetworkManager.shared.sendInnerRequest(request: request, completion: completion)
    }
    
    public static func stopLiveActivity(activityId: String) {
        stopLiveActivity(activityId: activityId, completion: { _ in })
    }
    
    public static func stopLiveActivity(activityId: String, completion: @escaping ((any Error)?) -> Void) {
        let requestParameters = ActivityRequestParameters(activityId: activityId)
        let request = PWRequestStopLiveActivity(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: request, completion: completion)
    }
    
    @objc
    public static func liveActivities() -> AnyClass {
        return PushwooshLiveActivitiesImplementationSetup.self
    }
    
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
    public static func configureLiveActivity<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        if #available(iOS 17.2, *) {
            observePushToStart(activityType)
        }
        observeActivity(activityType)
    }
    
    @objc
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
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Start default live activity error: \(error.localizedDescription)")
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
            try validateAndSendPushToken(for: "\(activityType)", token: withToken)
        } catch {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Failed to set push token for activity type \(activityType): \(error.localizedDescription)")
        }
    }
    
    @available(iOS 17.2, *)
    private static func validateAndSendPushToken(for activityType: String, token: String) throws {
        guard activityType.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) != nil else {
            throw LiveActivityError.incorrectTypeLA("Unable to convert activity type to a URL-encoded string.")
        }
        let requestParameters = ActivityRequestParameters(pushToStartToken: token)
        let request = PWRequestSetPushToStartToken(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: request) { error in
            handlePushTokenResult(error: error)
        }
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
                    let requestParameters = ActivityRequestParameters(activityId: activity.attributes.pushwoosh.activityId, token: "")
                    let request = PWRequestSetActivityToken(parameters: requestParameters)
                    NetworkManager.shared.sendInnerRequest(request: request) { error in
                        handlePushTokenResult(error: error)
                    }
                    break
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
                let requestParameters = ActivityRequestParameters(activityId: activity.attributes.pushwoosh.activityId, token: token)
                let request = PWRequestSetActivityToken(parameters: requestParameters)
                NetworkManager.shared.sendInnerRequest(request: request) { error in
                    handlePushTokenResult(error: error)
                }
            }
        }
    }
    
    private static func handlePushTokenResult(error: Error?) {
        let logLevel: PUSHWOOSH_LOG_LEVEL = error == nil ? .PW_LL_INFO : .PW_LL_ERROR
        let message = error == nil ?
            "Successfully sent live activity token." :
            "Failed to send push token. Error: \(error!.localizedDescription)"
        
        PushwooshLog.pushwooshLog(logLevel, className: self, message: message)
    }
}
#endif
