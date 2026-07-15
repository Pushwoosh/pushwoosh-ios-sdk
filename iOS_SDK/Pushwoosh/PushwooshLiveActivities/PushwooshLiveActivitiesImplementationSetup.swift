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

    // Guards the two-tier token-send dedup state below.
    //  - inFlightActivityTokenSends (in-memory, dies with the process): tokens currently being
    //    sent, so the multi-path fan-out at setup fires exactly one request per (activityId, token).
    //  - UserDefaults[sentActivityTokensKey] (persisted): tokens the server CONFIRMED receiving,
    //    written only in the send's success branch. Never written optimistically — a request lost
    //    in flight (e.g. queued in PWSdkStateProvider while the SDK is initializing and the process
    //    is killed) must not be recorded as sent, or dedup would block the resend on every future
    //    launch. Tokens can rotate, so both tiers compare values, not just "did we ever send one".
    private static let tokenCacheLock = NSLock()
    private static let sentActivityTokensKey = "PWLiveActivitySentTokens"
    private static var inFlightActivityTokenSends: [String: Set<String>] = [:]

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
        if registeredTypes.contains(typeId) {
            registrationLock.unlock()
            return
        }
        registeredTypes.insert(typeId)
        var tasks: [Task<Void, Never>] = []
        if #available(iOS 17.2, *) {
            tasks.append(observePushToStart(activityType))
        }
        tasks.append(observeActivity(activityType))
        typeTasks[typeId] = tasks
        registrationLock.unlock()

        // Re-attach per-activity observers to activities that are ALREADY running
        // at setup time — e.g. one started earlier, then the app was terminated and
        // relaunched. `activityUpdates` isn't guaranteed to replay those, so their
        // push token would otherwise never be re-sent and the server couldn't update
        // them. Runs after unlocking: spawnAndStoreActivityTasks → replaceActivityTasks
        // takes the same lock, so doing this under it would deadlock.
        reconnectRunningActivities(activityType)
    }

    /// Re-observes the push token / state of every currently-running activity of
    /// this type, re-uploading the token so a relaunched app resyncs the server.
    ///
    /// INTENTIONAL OVERLAP with `observeActivity`: `activityUpdates` may also replay these
    /// already-running activities to the fresh subscriber, so both paths can call
    /// `spawnAndStoreActivityTasks` for the same activity. This is safe by design and relies on TWO
    /// dedup layers — do not remove either without removing this overlap: (1) `replaceActivityTasks`
    /// cancels the prior tasks before overwriting (so only one observer pair survives per activity),
    /// and (2) `claimActivityTokenForSend` collapses the duplicate token sends into one request.
    /// The reconnect path is kept because `activityUpdates` replay is NOT guaranteed on every OS.
    @available(iOS 16.1, *)
    private static func reconnectRunningActivities<Attributes: PushwooshLiveActivityAttributes>(_ activityType: Attributes.Type) {
        for activity in Activity<Attributes>.activities {
            spawnAndStoreActivityTasks(activity, for: activityType)

            // Push the token synchronously, right now: pushTokenUpdates is not guaranteed to
            // replay the current token to a fresh subscriber, so on relaunch the observer above
            // might never re-emit it. Reading activity.pushToken directly re-sends it immediately
            // instead of waiting for a rotation that may never come. sendActivityToken skips the
            // network call when the server already has this exact token.
            if let token = activity.pushToken {
                sendActivityToken(token, for: activity)
            }
        }
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
            // Drop the cached token directly: cancelling the observer tasks above means the .dismissed
            // transition is never observed, so handleDismissedState (which normally clears the cache)
            // won't run for this path. Without this, the activityId lingers in the dedup cache forever.
            removeCachedActivityToken(forActivityId: activityId)
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
        tokenCacheLock.lock()
        inFlightActivityTokenSends.removeAll()
        tokenCacheLock.unlock()

        registrationLock.lock()
        defer { registrationLock.unlock() }
        typeTasks.values.flatMap { $0 }.forEach { $0.cancel() }
        perActivityTasks.values.flatMap { $0 }.forEach { $0.cancel() }
        registeredTypes.removeAll()
        typeTasks.removeAll()
        perActivityTasks.removeAll()
        UserDefaults.standard.removeObject(forKey: sentActivityTokensKey)
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
            // NOTE: at setup this may replay already-running activities that reconnectRunningActivities
            // is also (re)attaching to on the calling thread. The double spawnAndStoreActivityTasks is
            // intentional and safe — see the dedup-layers note on reconnectRunningActivities.
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
        // Cancel the per-activity observer tasks first to reduce the window in which a concurrent
        // token rotation could register a post-stop token after the stop request is sent. Note this
        // narrows but does not fully close it: Task.cancel() is cooperative, so a send already past
        // its await point still completes. The dedup cache clear below plus the server treating the
        // stop as authoritative keep a late token from mattering.
        cancelActivityTasks(runtimeActivityId)
        // The activity is gone; drop its cached token so a future activity reusing the same
        // activityId is never wrongly deduplicated against this dead one.
        removeCachedActivityToken(forActivityId: activityId)
        let request = dismissedActivityRequest(forActivityId: activityId)
        send(request) { error in
            handlePushTokenResult(error: error)
        }
    }

    @available(iOS 16.1, *)
    private static func observeActivityPushTokenUpdates<Attributes: PushwooshLiveActivityAttributes>(_ activity: Activity<Attributes>, for activityType: Attributes.Type) -> Task<Void, Never> {
        return Task {
            for await pushToken in activity.pushTokenUpdates {
                sendActivityToken(pushToken, for: activity)
            }
        }
    }

    @available(iOS 16.1, *)
    private static func sendActivityToken<Attributes: PushwooshLiveActivityAttributes>(_ pushToken: Data, for activity: Activity<Attributes>) {
        let token = pushToken.map { String(format: "%02x", $0) }.joined()
        let activityId = activity.attributes.pushwoosh.activityId

        // Claim before sending so exactly one of the concurrent setup paths wins (the
        // activityUpdates initial replay, reconnect's re-subscription, and reconnect's own
        // synchronous pushToken read). The claim is in-memory only; the persisted cache is written
        // exclusively after the server confirms the send, so a request lost in flight can never be
        // recorded as sent.
        guard claimActivityTokenForSend(token, forActivityId: activityId) else {
            PushwooshLog.pushwooshLog(.PW_LL_DEBUG, className: self,
                message: "Live activity token for \(activityId) already sent or in flight; skipping resend.")
            return
        }

        let requestParameters = ActivityRequestParameters(activityId: activityId, token: token)
        let request = PWRequestSetActivityToken(parameters: requestParameters)
        send(request) { error in
            if error == nil {
                markActivityTokenSent(token, forActivityId: activityId)
            } else {
                // Release the claim so a later token emission or the next launch retries.
                releaseActivityTokenClaim(token, forActivityId: activityId)
            }
            handlePushTokenResult(error: error)
        }
    }

    /// Returns true when this exact token still needs a send for the activity: it is neither
    /// server-confirmed (persisted cache) nor already being sent right now (in-flight claim).
    /// Registers the in-flight claim on success. Check-and-set is atomic under tokenCacheLock so
    /// racing fan-out callers can't all pass the guard.
    /// Internal-visible so unit tests can drive the dedup state machine without an `Activity<…>`.
    internal static func claimActivityTokenForSend(_ token: String, forActivityId activityId: String) -> Bool {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        let confirmed = (UserDefaults.standard.dictionary(forKey: sentActivityTokensKey) as? [String: String]) ?? [:]
        if confirmed[activityId] == token || inFlightActivityTokenSends[activityId]?.contains(token) == true {
            return false
        }
        inFlightActivityTokenSends[activityId, default: []].insert(token)
        return true
    }

    /// Persists the token as server-confirmed and releases its in-flight claim. Called only from
    /// the success branch of the send completion — write-after-confirm keeps the cache truthful
    /// when a completion is lost with the process. Skips persisting when the claim was already
    /// revoked by a concurrent dismissal, so a dead activity never re-enters the cache.
    /// Internal-visible for unit tests.
    internal static func markActivityTokenSent(_ token: String, forActivityId activityId: String) {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        guard inFlightActivityTokenSends[activityId]?.remove(token) != nil else { return }
        if inFlightActivityTokenSends[activityId]?.isEmpty == true {
            inFlightActivityTokenSends.removeValue(forKey: activityId)
        }
        var map = (UserDefaults.standard.dictionary(forKey: sentActivityTokensKey) as? [String: String]) ?? [:]
        map[activityId] = token
        UserDefaults.standard.set(map, forKey: sentActivityTokensKey)
    }

    /// Releases the in-flight claim after a failed send so a later token emission or the next
    /// launch retries. The persisted cache is untouched — it never contained this token.
    /// Internal-visible for unit tests.
    internal static func releaseActivityTokenClaim(_ token: String, forActivityId activityId: String) {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        inFlightActivityTokenSends[activityId]?.remove(token)
        if inFlightActivityTokenSends[activityId]?.isEmpty == true {
            inFlightActivityTokenSends.removeValue(forKey: activityId)
        }
    }

    /// Test-only seam: models a process relaunch for the dedup state — in-flight claims die with
    /// the process while the persisted server-confirmed cache survives.
    internal static func _clearInFlightClaimsForTesting() {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        inFlightActivityTokenSends.removeAll()
    }

    private static func removeCachedActivityToken(forActivityId activityId: String) {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        // Revoke any in-flight claim too: a send racing this dismissal must not persist its token
        // after the entry is cleared, or the dead activity would linger in the cache forever.
        inFlightActivityTokenSends.removeValue(forKey: activityId)
        guard var map = UserDefaults.standard.dictionary(forKey: sentActivityTokensKey) as? [String: String] else { return }
        map.removeValue(forKey: activityId)
        UserDefaults.standard.set(map, forKey: sentActivityTokensKey)
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
