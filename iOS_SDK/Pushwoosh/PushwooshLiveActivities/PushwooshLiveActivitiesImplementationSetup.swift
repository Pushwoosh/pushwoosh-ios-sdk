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
        let activityAttributes = DefaultLiveActivityAttributes(data: anyCodableDictionary(attributes), pushwoosh: pushwooshAttribute)
        let contentState = DefaultLiveActivityAttributes.ContentState(data: anyCodableDictionary(content))

        runOnMain {
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
    }

    // No @available(iOS 26.0, *) on the @objc entrypoints below, for the same reason as the
    // 16.1 defaultStart pair above: Obj-C / cross-platform plugin callers reach these from any OS
    // version and a compile-time @available would break linking. The runtime `guard #available(iOS 26.0, *)`
    // inside is the actual gate. Scheduling needs iOS 26.0 — that's where ActivityKit added the
    // `start:` parameter to `Activity.request`.
    @objc
    public static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any],
                                    at startDate: Date, alertTitle: String, alertBody: String) {
        defaultStart(activityId, attributes: attributes, content: content,
                     at: startDate, alertTitle: alertTitle, alertBody: alertBody, completion: { _ in })
    }

    @objc
    public static func defaultStart(_ activityId: String, attributes: [String: Any], content: [String: Any],
                                    at startDate: Date, alertTitle: String, alertBody: String,
                                    completion: @escaping (Error?) -> Void) {
        guard #available(iOS 26.0, *) else {
            let error = NSError(domain: "pushwoosh", code: 4,
                                userInfo: [NSLocalizedDescriptionKey: "Scheduling a Live Activity requires iOS 26.0+."])
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self,
                message: "defaultStart(at:) requires iOS 26.0+. No-op on this OS version.")
            completion(error)
            return
        }

        let pushwooshAttribute = PushwooshLiveActivityAttributeData.create(activityId: activityId)
        let activityAttributes = DefaultLiveActivityAttributes(data: anyCodableDictionary(attributes), pushwoosh: pushwooshAttribute)
        let contentState = DefaultLiveActivityAttributes.ContentState(data: anyCodableDictionary(content))

        runOnMain {
            do {
                _ = try schedule(activityAttributes, contentState: contentState, at: startDate,
                                 alertTitle: alertTitle, alertBody: alertBody)
                completion(nil)
            } catch let error {
                PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Schedule default live activity error: \(error.localizedDescription)")
                completion(error)
            }
        }
    }

    /// Schedules a Live Activity with a custom attributes type to start at a future date.
    /// Mirrors `Activity.request(...)` (throws and returns the started activity) but hides the
    /// iOS 26 `start:` mechanics: mandatory alert, activity style, `ActivityContent` wrapping.
    /// Call on the main thread while the app is in the foreground.
    @available(iOS 26.0, *)
    public static func schedule<Attributes: PushwooshLiveActivityAttributes>(
        _ attributes: Attributes,
        contentState: Attributes.ContentState,
        at startDate: Date,
        alertTitle: String,
        alertBody: String
    ) throws -> Activity<Attributes> {
        guard startDate > Date() else {
            throw NSError(domain: "pushwoosh", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Scheduled start date must be in the future."])
        }
#if compiler(>=6.2)
        // The `start:` overload of Activity.request and ActivityStyle.standard exist only in the
        // iOS 26 SDK (Xcode 26 / Swift 6.2+). Gate the call by compiler version so the module still
        // builds with older toolchains (e.g. Xcode 15.4 on CI), where these symbols are absent.
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        let activity = try Activity<Attributes>.request(
            attributes: attributes,
            content: activityContent,
            pushType: .token,
            style: .standard,
            alertConfiguration: makeAlertConfiguration(title: alertTitle, body: alertBody),
            start: startDate)

        // No schedule-time backend call by design: the server learns the activity once it starts
        // and emits a per-activity push token, picked up by the pushTokenUpdates observer that
        // setup()/configureLiveActivity installs.
        return activity
#else
        // Built with a pre-iOS-26 SDK: the scheduling overload does not exist to call. A binary built
        // this way can never run on a toolchain that has iOS 26 anyway, so fail loudly at runtime.
        throw NSError(domain: "pushwoosh", code: 5,
                      userInfo: [NSLocalizedDescriptionKey: "Scheduling a Live Activity requires building with the iOS 26 SDK (Xcode 26+)."])
#endif
    }

#if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func makeAlertConfiguration(title: String, body: String) -> AlertConfiguration {
        AlertConfiguration(
            title: LocalizedStringResource(stringLiteral: title),
            body: LocalizedStringResource(stringLiteral: body),
            sound: .default)
    }
#endif

    private static func anyCodableDictionary(_ dictionary: [String: Any]) -> [String: AnyCodable] {
        dictionary.mapValues { AnyCodable($0) }
    }

    private static func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    /// Cancels a scheduled (or ends a running) Live Activity by its Pushwoosh `activityId`.
    ///
    /// Finds every `Activity<Attributes>` whose `pushwoosh.activityId` matches, ends it on the device —
    /// a pending (scheduled) activity is cancelled before it starts — and notifies the Pushwoosh server.
    /// You do not need to hold the `Activity` reference.
    ///
    /// Requires iOS 16.2: ending an activity goes through `Activity.end(_:dismissalPolicy:)`, which is
    /// 16.2+. The 16.1-only deprecated `end(using:dismissalPolicy:)` is intentionally not used.
    @available(iOS 16.2, *)
    public static func cancel<Attributes: PushwooshLiveActivityAttributes>(
        _ activityType: Attributes.Type, activityId: String
    ) {
        // ActivityKit reads/ends should run on the main thread; callers may invoke cancel from any
        // queue (e.g. a push handler), so hop to main like the defaultStart path does. The server
        // notify is sequenced inside the same hop, after task cancellation, so it always runs after
        // cancelActivityTasks regardless of the calling thread.
        runOnMain {
            for activity in Activity<Attributes>.activities where activity.attributes.pushwoosh.activityId == activityId {
                // Cancel the per-activity observer tasks first so the .dismissed state update from
                // end() does not fire a second PWRequestStopLiveActivity. Mirrors handleMultipleActivities.
                cancelActivityTasks(activity.id)
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            // Notify the server the activity stopped. Same PWRequestStopLiveActivity as the existing
            // stopLiveActivity(activityId:) path.
            stopLiveActivity(activityId: activityId) { _ in }
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
        // Cancel the per-activity observer tasks first, so a concurrent token rotation can't register a
        // post-stop token after the stop request is sent.
        cancelActivityTasks(runtimeActivityId)
        let request = dismissedActivityRequest(forActivityId: activityId)
        send(request) { error in
            handlePushTokenResult(error: error)
        }
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
