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

/// Orchestrates iOS Live Activities integration with Pushwoosh push notifications.
@objc(PushwooshLiveActivitiesImplementationSetup)
public class PushwooshLiveActivitiesImplementationSetup: NSObject, PWLiveActivities {

    private static let registrationLock = NSLock()
    private static var registeredTypes: Set<ObjectIdentifier> = []
    private static var typeTasks: [ObjectIdentifier: [Task<Void, Never>]] = [:]
    private static var perActivityTasks: [String: [Task<Void, Never>]] = [:]

    // Test-only seam. Read in send(_:), written by tests in setUp/tearDown.
    // Safe without synchronization while PushwooshLiveActivitiesTests.xcscheme has
    // parallelizable=NO. DO NOT enable parallel testing without converting this to a
    // lock-guarded or @Atomic property — concurrent setUp/tearDown across test classes
    // would race.
    internal static var _requestSender: ((PWCoreSetLiveActivityTokenRequest, @escaping (Error?) -> Void) -> Void)? = nil

    internal static var _registeredTypeCount: Int {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        return registeredTypes.count
    }

    public static func sendPushToStartLiveActivity(token: String) {
        sendPushToStartLiveActivity(token: token, completion: { _ in })
    }

    public static func sendPushToStartLiveActivity(token: String, completion: @escaping (((any Error)?) -> Void)) {
        let requestParameters = ActivityRequestParameters(pushToStartToken: token)
        let request = PWRequestSetPushToStartToken(parameters: requestParameters)
        send(request, completion: completion)
    }

    public static func startLiveActivity(token: String, activityId: String) {
        startLiveActivity(token: token, activityId: activityId, completion: { _ in })
    }

    public static func startLiveActivity(token: String, activityId: String, completion: @escaping ((any Error)?) -> Void) {
        let requestParameters = ActivityRequestParameters(activityId: activityId, token: token)
        let request = PWRequestSetActivityToken(parameters: requestParameters)
        send(request, completion: completion)
    }

    public static func stopLiveActivity() {
        stopLiveActivity(completion: { _ in })
    }

    public static func stopLiveActivity(completion: @escaping ((any Error)?) -> Void) {
        let request = PWRequestStopLiveActivity(parameters: ActivityRequestParameters())
        send(request, completion: completion)
    }

    public static func stopLiveActivity(activityId: String) {
        stopLiveActivity(activityId: activityId, completion: { _ in })
    }

    public static func stopLiveActivity(activityId: String, completion: @escaping ((any Error)?) -> Void) {
        let requestParameters = ActivityRequestParameters(activityId: activityId)
        let request = PWRequestStopLiveActivity(parameters: requestParameters)
        send(request, completion: completion)
    }

    @objc
    public static func liveActivities() -> AnyClass {
        return PushwooshLiveActivitiesImplementationSetup.self
    }

    // Public to preserve the pre-7.0.45 ABI: integrators historically reached this directly as
    // `PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(MyAttrs.self)`. New code
    // should prefer `Pushwoosh.LiveActivities.setup(MyAttrs.self)` (extension wrapper in
    // PWLiveActivitiesExtension.swift) — both call paths are equivalent.
    @available(iOS 16.1, *)
    public static func configureLiveActivity<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        let typeId = ObjectIdentifier(activityType)
        registrationLock.lock()
        defer { registrationLock.unlock() }
        guard !registeredTypes.contains(typeId) else { return }
        registeredTypes.insert(typeId)
        var tasks: [Task<Void, Never>] = []
        if #available(iOS 17.2, *) {
            tasks.append(observePushToStart(activityType))
        }
        tasks.append(observeActivity(activityType))
        typeTasks[typeId] = tasks
    }

    // No @available(iOS 16.1, *) on the @objc entrypoints below: Obj-C / cross-platform plugin
    // callers reach these via `Pushwoosh.LiveActivities` from any OS version and would otherwise
    // get a link error. The runtime `guard #available(iOS 16.1, *)` inside each method is the
    // actual gate. Protocol/stub/extension declarations DO carry the @available because their
    // callers are Swift-typed and the compiler can enforce the version at the call site.
    @objc
    public static func defaultSetup() {
        guard #available(iOS 16.1, *) else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self,
                message: "defaultSetup requires iOS 16.1+. No-op on this OS version.")
            return
        }
        configureLiveActivity(DefaultLiveActivityAttributes.self)
    }

    @objc
    public static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        defaultStart(activityId, attributes: attributes, content: content, completion: { _ in })
    }

    @objc
    public static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any], completion: @escaping (Error?) -> Void) {
        guard #available(iOS 16.1, *) else {
            let error = NSError(domain: "pushwoosh", code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "defaultStart requires iOS 16.1+."])
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self,
                message: "defaultStart requires iOS 16.1+. No-op on this OS version.")
            completion(error)
            return
        }

        let pushwooshAttribute = PushwooshLiveActivityAttributeData.create(activityId: activityId)

        var attributeData = [String: AnyCodable]()
        for attribute in attributes {
            attributeData.updateValue(AnyCodable(attribute.value), forKey: attribute.key)
        }

        var contentData = [String: AnyCodable]()
        for contentItem in content {
            contentData.updateValue(AnyCodable(contentItem.value), forKey: contentItem.key)
        }

        let activityAttributes = DefaultLiveActivityAttributes(data: attributeData, pushwoosh: pushwooshAttribute)
        let contentState = DefaultLiveActivityAttributes.ContentState(data: contentData)
        let requestActivity = {
            do {
                _ = try Activity<DefaultLiveActivityAttributes>.request(
                        attributes: activityAttributes,
                        contentState: contentState,
                        pushType: .token)
                completion(nil)
            } catch let error {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Start default live activity error: \(error.localizedDescription)")
                completion(error)
            }
        }
        if Thread.isMainThread {
            requestActivity()
        } else {
            DispatchQueue.main.async {
                requestActivity()
            }
        }
    }

    private static func send(_ request: PWCoreSetLiveActivityTokenRequest,
                             completion: @escaping (Error?) -> Void) {
        if let sender = _requestSender {
            sender(request, completion)
            return
        }
        guard request.prepareForExecution() else {
            let error = NSError(domain: "pushwoosh", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Request preparation failed."])
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Failed to prepare the request.")
            completion(error)
            return
        }
        PushwooshCoreManager.sharedManager().send(request) { completion($0) }
    }

    // Test-only seam. Cancels stored Tasks cooperatively but does NOT await their actual completion.
    // Tests are safe because mock streams (no real ActivityKit) don't emit further values after cancel.
    internal static func _resetForTesting() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        typeTasks.values.flatMap { $0 }.forEach { $0.cancel() }
        perActivityTasks.values.flatMap { $0 }.forEach { $0.cancel() }
        registeredTypes.removeAll()
        typeTasks.removeAll()
        perActivityTasks.removeAll()
    }

    private static func cancelActivityTasks(_ activityId: String) {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        if let staleTasks = perActivityTasks.removeValue(forKey: activityId) {
            staleTasks.forEach { $0.cancel() }
        }
    }

    @available(iOS 17.2, *)
    private static func observePushToStart<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) -> Task<Void, Never> {
        return Task {
            for await data in Activity<Attributes>.pushToStartTokenUpdates {
                let token = data.map { String(format: "%02x", $0) }.joined()
                setPushToStartToken(activityType, withToken: token)
            }
        }
    }

    @available(iOS 17.2, *)
    private static func setPushToStartToken<Attributes: ActivityAttributes>(_ activityType: Attributes.Type, withToken: String) {
        let request = PWRequestSetPushToStartToken(parameters: ActivityRequestParameters(pushToStartToken: withToken))
        send(request) { error in
            handlePushTokenResult(error: error)
        }
    }

    @available(iOS 16.1, *)
    private static func observeActivity<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) -> Task<Void, Never> {
        return Task {
            for await activity in Activity<Attributes>.activityUpdates {
                if #available(iOS 16.2, *) {
                    handleMultipleActivities(activity, for: activityType)
                }
                spawnAndStoreActivityTasks(activity, for: activityType)
            }
        }
    }

    @available(iOS 16.1, *)
    private static func spawnAndStoreActivityTasks<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) {
        let stateTask = observeActivityStateUpdates(activity, for: activityType)
        let tokenTask = observeActivityPushTokenUpdates(activity, for: activityType)
        replaceActivityTasks(forId: activity.id, with: [stateTask, tokenTask])
    }

    /// Replaces the tracked tasks for `activityId`, cancelling any prior tasks for the same id before overwriting.
    /// Internal-visible so unit tests can exercise the cancel-before-overwrite contract directly without spawning a real `Activity<…>`.
    internal static func replaceActivityTasks(forId activityId: String, with tasks: [Task<Void, Never>]) {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        perActivityTasks.removeValue(forKey: activityId)?.forEach { $0.cancel() }
        perActivityTasks[activityId] = tasks
    }

    /// Internal-visible read of the per-activity task slot count for tests.
    internal static func _activityTaskCount(forId activityId: String) -> Int {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        return perActivityTasks[activityId]?.count ?? 0
    }

    @available(iOS 16.2, *)
    private static func handleMultipleActivities<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) {
        for otherActivity in Activity<Attributes>.activities {
            if activity.id != otherActivity.id && otherActivity.attributes.pushwoosh.activityId == activity.attributes.pushwoosh.activityId {
                cancelActivityTasks(otherActivity.id)
                Task {
                    await otherActivity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    @available(iOS 16.1, *)
    private static func observeActivityStateUpdates<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) -> Task<Void, Never> {
        return Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed:
                    handleDismissedState(forActivityId: activity.attributes.pushwoosh.activityId,
                                         runtimeActivityId: activity.id)
                default:
                    break
                }
            }
        }
    }

    internal static func dismissedActivityRequest(forActivityId activityId: String) -> PWCoreSetLiveActivityTokenRequest {
        let params = ActivityRequestParameters(activityId: activityId)
        return PWRequestStopLiveActivity(parameters: params)
    }

    /// Sends the stop request for a dismissed activity and cancels its tracked observer tasks.
    /// Internal so unit tests can drive the dismissal code path directly without an `Activity<>` instance.
    /// `runtimeActivityId` is the ActivityKit-issued `activity.id` (UUID) used as the `perActivityTasks`
    /// key — passing the business activityId here would silently miss the cancel.
    internal static func handleDismissedState(forActivityId activityId: String, runtimeActivityId: String) {
        let request = dismissedActivityRequest(forActivityId: activityId)
        send(request) { error in
            handlePushTokenResult(error: error)
        }
        cancelActivityTasks(runtimeActivityId)
    }

    @available(iOS 16.1, *)
    private static func observeActivityPushTokenUpdates<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) -> Task<Void, Never> {
        return Task {
            for await pushToken in activity.pushTokenUpdates {
                let token = pushToken.map { String(format: "%02x", $0) }.joined()
                let requestParameters = ActivityRequestParameters(activityId: activity.attributes.pushwoosh.activityId, token: token)
                let request = PWRequestSetActivityToken(parameters: requestParameters)
                send(request) { error in
                    handlePushTokenResult(error: error)
                }
            }
        }
    }

    private static func handlePushTokenResult(error: Error?) {
        let logLevel: PUSHWOOSH_LOG_LEVEL = error == nil ? .PW_LL_INFO : .PW_LL_ERROR
        let message = error == nil ?
            "Successfully sent live activity token." :
            "Failed to send push token. Error: \(error?.localizedDescription ?? "unknown")"

        PushwooshLog.pushwooshLog(logLevel, className: self, message: message)
    }
}
#endif
