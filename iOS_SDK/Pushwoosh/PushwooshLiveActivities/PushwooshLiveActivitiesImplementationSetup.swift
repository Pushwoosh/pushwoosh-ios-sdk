//
//  PushwooshLiveActivitiesImplementationSetup.swift
//  Pushwoosh
//
//  Created by André Kis on 08.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst) && os(iOS)
import Foundation
import ActivityKit
import PushwooshCore
import PushwooshBridge

enum LiveActivityError: Error {
    case incorrectTypeLA(String)
}

/// Orchestrates iOS Live Activities integration with Pushwoosh push notifications.
@objc(PushwooshLiveActivitiesImplementationSetup)
public class PushwooshLiveActivitiesImplementationSetup: NSObject, PWLiveActivities {

    /// Sends push-to-start token to enable remote activity initiation.
    ///
    /// - Parameter token: The push-to-start token from ActivityKit.
    public static func sendPushToStartLiveActivity(token: String) {
        sendPushToStartLiveActivity(token: token, completion: { _ in })
    }

    /// Sends push-to-start token to enable remote activity initiation with completion handler.
    ///
    /// - Parameters:
    ///   - token: The push-to-start token from ActivityKit.
    ///   - completion: Completion handler called when the request finishes.
    public static func sendPushToStartLiveActivity(token: String, completion: @escaping (((any Error)?) -> Void)) {
        let requestParameters = ActivityRequestParameters(pushToStartToken: token)
        let requst = PWRequestSetPushToStartToken(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: requst, completion: completion)
    }

    /// Registers an active Live Activity with the server.
    ///
    /// - Parameters:
    ///   - token: The activity push token from ActivityKit.
    ///   - activityId: Unique identifier for this activity instance.
    public static func startLiveActivity(token: String, activityId: String) {
        startLiveActivity(token: token, activityId: activityId, completion: { _ in })
    }

    /// Registers an active Live Activity with the server with completion handler.
    ///
    /// - Parameters:
    ///   - token: The activity push token from ActivityKit.
    ///   - activityId: Unique identifier for this activity instance.
    ///   - completion: Completion handler called when the request finishes.
    public static func startLiveActivity(token: String, activityId: String, completion: @escaping ((any Error)?) -> Void) {
        let requestParameters = ActivityRequestParameters(activityId: activityId, token: token)
        let request = PWRequestSetActivityToken(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: request, completion: completion)
    }

    /// Notifies the server that all Live Activities have ended.
    public static func stopLiveActivity() {
        stopLiveActivity(completion: { _ in })
    }

    /// Notifies the server that all Live Activities have ended with completion handler.
    ///
    /// - Parameter completion: Completion handler called when the request finishes.
    public static func stopLiveActivity(completion: @escaping ((any Error)?) -> Void) {
        let request = PWRequestStopLiveActivity(parameters: ActivityRequestParameters())
        NetworkManager.shared.sendInnerRequest(request: request, completion: completion)
    }

    /// Notifies the server that a specific Live Activity has ended.
    ///
    /// - Parameter activityId: The unique identifier of the activity that ended.
    public static func stopLiveActivity(activityId: String) {
        stopLiveActivity(activityId: activityId, completion: { _ in })
    }

    /// Notifies the server that a specific Live Activity has ended with completion handler.
    ///
    /// - Parameters:
    ///   - activityId: The unique identifier of the activity that ended.
    ///   - completion: Completion handler called when the request finishes.
    public static func stopLiveActivity(activityId: String, completion: @escaping ((any Error)?) -> Void) {
        let requestParameters = ActivityRequestParameters(activityId: activityId)
        let request = PWRequestStopLiveActivity(parameters: requestParameters)
        NetworkManager.shared.sendInnerRequest(request: request, completion: completion)
    }

    @objc
    public static func liveActivities() -> AnyClass {
        return PushwooshLiveActivitiesImplementationSetup.self
    }

    /// Configures Live Activities with custom attributes.
    ///
    /// This method sets up automatic token registration and activity lifecycle management
    /// for your custom ``PushwooshLiveActivityAttributes`` type. Call this during app initialization,
    /// typically in `application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// - Parameter activityType: Your custom attributes type conforming to ``PushwooshLiveActivityAttributes``.
    @available(iOS 16.1, *)
    public static func configureLiveActivity<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        if #available(iOS 17.2, *) {
            observePushToStart(activityType)
        }
        observeActivity(activityType)
    }

    /// Configures Live Activities with default attributes managed by Pushwoosh.
    ///
    /// This method sets up automatic lifecycle management using ``DefaultLiveActivityAttributes``.
    /// Use this when you want the SDK to handle all activity management without defining custom types.
    @objc
    @available(iOS 16.1, *)
    public static func defaultSetup() {
        configureLiveActivity(DefaultLiveActivityAttributes.self)
    }

    /// Starts a Live Activity using default attributes.
    ///
    /// - Parameters:
    ///   - activityId: Unique identifier for this activity instance.
    ///   - attributes: Static attributes dictionary.
    ///   - content: Initial content state dictionary.
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
