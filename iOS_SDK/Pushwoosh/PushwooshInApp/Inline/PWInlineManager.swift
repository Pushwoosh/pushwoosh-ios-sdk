//
//  PWInlineManager.swift
//  PushwooshInApp
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import Foundation
import PushwooshCore
import PushwooshBridge

/// Requests slots from the server, keeps the answers in the store and reports slot changes to the
/// delegate. Known slots are requested on their own at a session start (first activation or a return
/// after 30 minutes in the background) and after a confirmed user change; a slot first put on screen
/// is requested together with the other new slots of the next 0.5 s. Manual requests are limited to
/// 5 per session start, then one per 3 minutes. Shows, clicks, dismisses and control-group shows go to
/// `trackInlineEvent` through the retry queue; a show or control is reported once per banner version
/// and user. Until the server confirms a user change, events of the shown banners go out for the
/// previous user, their postEvent actions (native, `pushwoosh.postEvent()` and `pushManager.postEvent()` of HTML)
/// are skipped, no slot is requested and no answer is applied; a user id set before the module starts is
/// taken as the current user. Main thread only.
final class PWInlineManager {

    typealias Transport = (PWGetInlineBannersRequest, @escaping (Error?) -> Void) -> Void
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void
    typealias EventSender = ([String: Any], @escaping (Error?) -> Void) -> Void

    enum ErrorCode: Int {
        case invalidArgument = 1
        case endpointUnavailable
        case rateLimited
        case invalidResponse
        case ownerChanged
    }

    static let errorDomain = "com.pushwoosh.inline"
    static let maxSlotsPerRequest = 10
    static let sessionGap: TimeInterval = 30 * 60
    static let manualBurst = 5
    static let manualInterval: TimeInterval = 3 * 60
    static let newSlotDelay: TimeInterval = 0.5

    static let shared = PWInlineManager(store: .shared)
    static let colorSchemeDidChange = Notification.Name("PWInlineColorSchemeDidChange")

    weak var delegate: PWInlineDelegate?
    var colorScheme: PWInlineColorScheme = .app {
        didSet {
            guard colorScheme != oldValue else {
                return
            }
            log("Inline banners color scheme: \(Self.name(of: colorScheme))")
            NotificationCenter.default.post(name: Self.colorSchemeDidChange, object: self)
        }
    }
    let store: PWInlineStore
    /// Posts a banner's postEvent action; a test passes its own.
    var postEvent: (String, [String: Any]) -> Void = { PushwooshConfig.postEvent($0, withAttributes: $1) }
    private let now: () -> Date
    private let scheduler: Scheduler
    private let transport: Transport
    private let eventSender: EventSender
    private var sessionStarted = false
    private var backgroundedAt: Date?
    private var requested = RequestedSlots()
    /// Slots not requested while a user change was unconfirmed; requested once it is settled.
    private var heldSlots = Set<String>()
    private var pendingNewSlots: [String] = []
    private var manualTokens = PWInlineManager.manualBurst
    private var refilledAt: Date

    /// The default transport and event sender are the live request manager; a test passes its own.
    init(store: PWInlineStore, now: @escaping () -> Date = Date.init,
         scheduler: @escaping Scheduler = { delay, work in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work) },
         transport: @escaping Transport = { request, completion in
        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }, eventSender: @escaping EventSender = PWInlineManager.sendEvent) {
        self.store = store
        self.now = now
        self.scheduler = scheduler
        self.transport = transport
        self.eventSender = eventSender
        refilledAt = now()
        store.onChange = { [weak self] slotIds in
            guard let self = self else {
                return
            }
            for slotId in slotIds {
                let banner = self.store.banner(for: slotId).flatMap { $0.isControl ? nil : Self.publicBanner($0) }
                self.delegate?.inlineSlot?(slotId, didUpdate: banner)
            }
        }
    }

    // MARK: - Automatic requests

    func applicationDidBecomeActive() {
        store.reloadIfNeeded()
        let isNewSession = !sessionStarted || backgroundedAt.map { now().timeIntervalSince($0) >= Self.sessionGap } ?? false
        backgroundedAt = nil
        guard isNewSession else {
            requestKnownSlots()
            return
        }
        if sessionStarted {
            requested.removeAll()
            manualTokens = Self.manualBurst
            refilledAt = now()
        }
        sessionStarted = true
        if store.previousUserId == nil {
            store.syncOwner()
        }
        requestKnownSlots()
    }

    func applicationDidEnterBackground() {
        backgroundedAt = now()
    }

    /// The server confirmed another user: the previous user's banners are cleared and known slots requested again.
    func userDidChange() {
        store.syncOwner()
        requested.removeAll()
        heldSlots.removeAll()
        requestKnownSlots()
    }

    /// The server refused a user change and the SDK went back to the previous user, whose banners stayed:
    /// slots held back or whose answer was dropped meanwhile are requested again, together.
    func userChangeDidFail() {
        store.syncOwner()
        let held = heldSlots
        heldSlots.removeAll()
        requestKnownSlots(adding: held)
    }

    /// The SDK moved to another application code: the previous application's banners are cleared and known
    /// slots requested again.
    func activeApplicationDidChange() {
        userDidChange()
    }

    /// A slot view is on screen: the slot becomes known and, when it has nothing yet, is requested with
    /// the other new slots of the next 0.5 s.
    func slotDidAppear(_ slotId: String) {
        guard !slotId.isEmpty else {
            return
        }
        store.rememberSlots([slotId])
        guard !requested.contains(slotId, owner: store.currentOwner()), store.banner(for: slotId) == nil,
              !pendingNewSlots.contains(slotId) else {
            return
        }
        pendingNewSlots.append(slotId)
        if pendingNewSlots.count == 1 {
            scheduler(Self.newSlotDelay) { [weak self] in
                self?.requestNewSlots()
            }
        }
    }

    /// The `inline` block of a postEvent answer (`{"slots": {...}}`) updates only the slots it lists;
    /// `owner` is the user and application the event was sent for.
    func applyEventSlots(_ content: Any, owner: String?) {
        guard let slots = (content as? [String: Any])?["slots"] as? [String: Any], !slots.isEmpty else {
            return
        }
        guard owner == store.currentOwner() else {
            warn("Event answer with inline slots is for the previous user or application and is dropped")
            return
        }
        log("Event answer updates inline slots: \(slots.keys.sorted().joined(separator: ", "))")
        apply(Array(slots.keys), response: slots)
    }

    /// Slots whose request failed are requested again.
    func networkReachabilityDidChange() {
        guard sessionStarted, backgroundedAt == nil else {
            return
        }
        requestKnownSlots()
    }

    /// The retry queue delivered an inline event: a delivered dismiss requests its slot's next banner.
    func retriedEventDelivered(_ event: [String: Any]) {
        guard event["type"] as? String == "dismiss", let slotId = event["slotId"] as? String,
              store.banner(for: slotId) == nil else {
            return
        }
        requestAutomatically([slotId])
    }

    /// Known slots not requested yet, plus `extra`; nothing while a user change is unconfirmed, as its outcome
    /// requests them.
    private func requestKnownSlots(adding extra: Set<String> = []) {
        guard store.previousUserId == nil else {
            return
        }
        let owner = store.currentOwner()
        let slots = extra.union(store.knownSlotIds().filter { !requested.contains($0, owner: owner) })
        requestAutomatically(slots.sorted())
    }

    private func requestNewSlots() {
        let owner = store.currentOwner()
        let slots = pendingNewSlots.filter { !requested.contains($0, owner: owner) }
        pendingNewSlots.removeAll()
        requestAutomatically(slots)
    }

    private func requestAutomatically(_ slotIds: [String]) {
        for start in stride(from: 0, to: slotIds.count, by: Self.maxSlotsPerRequest) {
            send(Array(slotIds[start..<min(start + Self.maxSlotsPerRequest, slotIds.count)]), completion: nil)
        }
    }

    // MARK: - Manual requests

    func requestSlots(_ slotIds: [String], completion: ((Error?) -> Void)?) {
        var seen = Set<String>()
        let slots = slotIds.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !slots.isEmpty else {
            completion?(Self.error(.invalidArgument, "No inline slots to request"))
            return
        }
        guard slots.count <= Self.maxSlotsPerRequest else {
            warn("Inline slots are requested at most \(Self.maxSlotsPerRequest) per call, \(slots.count) slots are not requested")
            completion?(Self.error(.invalidArgument, "Too many inline slots in one request"))
            return
        }
        store.rememberSlots(slots)
        guard store.previousUserId == nil else {
            warn("Inline slots are requested once the server confirms the user change, slots keep their banners")
            completion?(Self.error(.ownerChanged, "The user change is not confirmed yet"))
            return
        }
        guard takeManualToken() else {
            warn("Inline slots request limit reached (5 per session start, then one per 3 minutes), slots keep their banners")
            completion?(Self.error(.rateLimited, "Inline slots request limit reached"))
            return
        }
        send(slots, completion: completion)
    }

    private func takeManualToken() -> Bool {
        let now = self.now()
        let refills = Int(now.timeIntervalSince(refilledAt) / Self.manualInterval)
        if refills > 0 {
            manualTokens = min(Self.manualBurst, manualTokens + refills)
            refilledAt = refilledAt.addingTimeInterval(Double(refills) * Self.manualInterval)
        }
        guard manualTokens > 0 else {
            return false
        }
        if manualTokens == Self.manualBurst {
            refilledAt = now
        }
        manualTokens -= 1
        return true
    }

    // MARK: - Network

    private func send(_ slots: [String], completion: ((Error?) -> Void)?) {
        guard store.previousUserId == nil else {
            heldSlots.formUnion(slots)
            completion?(Self.error(.ownerChanged, "The user change is not confirmed yet"))
            return
        }
        let request = PWGetInlineBannersRequest(slots: slots, formats: ["native", "html"])
        guard !request.baseUrl().isEmpty else {
            warn("Inline banners are not available through this reverse proxy, slots are not requested")
            completion?(Self.error(.endpointUnavailable, "No inline banners endpoint"))
            return
        }
        let owner = store.currentOwner()
        requested.insert(slots, owner: owner)
        transport(request) { [weak self] error in
            PWInlineManager.runOnMain { self?.finish(request, owner: owner, error: error, completion: completion) }
        }
    }

    private func finish(_ request: PWGetInlineBannersRequest, owner: String?, error: Error?,
                        completion: ((Error?) -> Void)?) {
        if let error = error {
            warn("Inline slots request failed, slots keep their banners: \(error.localizedDescription)")
            requested.remove(request.slots, owner: owner)
            completion?(error)
            return
        }
        guard owner == store.currentOwner() else {
            warn("Inline slots answer is for the previous user or application and is dropped")
            requested.remove(request.slots, owner: owner)
            completion?(Self.error(.ownerChanged, "User or application changed during the inline slots request"))
            return
        }
        guard let response = request.slotsResponse else {
            warn("Inline slots response has no slots object, slots keep their banners")
            requested.remove(request.slots, owner: owner)
            completion?(Self.error(.invalidResponse, "Invalid inline slots response"))
            return
        }
        apply(request.slots, response: response)
        completion?(nil)
    }

    private func apply(_ slotIds: [String], response: [String: Any]) {
        let receivedAt = now()
        var received: [String: PWInlineBanner] = [:]
        for slotId in slotIds {
            received[slotId] = PWInlineParser.banner(from: response[slotId], slotId: slotId, receivedAt: receivedAt)
        }
        store.apply(slotIds, banners: received)
    }

    // MARK: - Slots

    /// A control-group banner reads as empty and reports its control event once.
    func banner(forSlot slotId: String) -> PushwooshInlineBanner? {
        guard let banner = store.banner(for: slotId) else {
            return nil
        }
        guard !banner.isControl else {
            bannerDidBecomeVisible(banner)
            return nil
        }
        return Self.publicBanner(banner)
    }

    func trackShown(slotId: String, bannerId: String) {
        if let banner = currentBanner(slotId: slotId, bannerId: bannerId) {
            bannerDidBecomeVisible(banner)
        }
    }

    func trackClick(slotId: String, bannerId: String, elementId: String?) {
        if let banner = currentBanner(slotId: slotId, bannerId: bannerId) {
            click(banner, elementId: elementId)
        }
    }

    /// A tap on a banner the slot no longer holds for the current user (the user changed) is not reported.
    func didClick(_ banner: PWInlineBanner, elementId: String?) {
        trackClick(slotId: banner.slotId, bannerId: banner.bannerId, elementId: elementId)
    }

    /// The slot collapses at once; once the server has the dismiss, the slot is requested for its next banner.
    func dismiss(slotId: String, bannerId: String) {
        guard let banner = currentBanner(slotId: slotId, bannerId: bannerId) else {
            return
        }
        store.dismiss(slotId)
        delegate?.inlineSlot?(slotId, didDismiss: Self.publicBanner(banner))
        track("dismiss", banner) { [weak self] error in
            if error == nil {
                self?.requestAutomatically([slotId])
            }
        }
    }

    /// The banner is on screen (or, for the control group, its empty slot is): reported once per version and user.
    func bannerDidBecomeVisible(_ banner: PWInlineBanner) {
        guard store.markReported(banner) else {
            return
        }
        if banner.isControl {
            log("Inline banner '\(banner.bannerId)' would be shown in slot '\(banner.slotId)' (control group)")
            track("control", banner)
            return
        }
        log("Inline banner '\(banner.bannerId)' shown in slot '\(banner.slotId)'")
        track("show", banner)
        delegate?.inlineSlot?(banner.slotId, didShow: Self.publicBanner(banner))
    }

    /// A banner's postEvent is not sent until a user change is confirmed, since it would go out for the new user.
    var canPostBannerEvent: Bool {
        store.previousUserId == nil
    }

    func postBannerEvent(_ name: String, attributes: [String: Any]) {
        guard canPostBannerEvent else {
            warn("Inline banner event '\(name)' is not posted: the user change is not confirmed yet")
            return
        }
        postEvent(name, attributes)
    }

    private func click(_ banner: PWInlineBanner, elementId: String?) {
        log("Inline banner '\(banner.bannerId)' clicked in slot '\(banner.slotId)', element '\(elementId ?? "banner")'")
        track("click", banner, elementId: elementId)
        delegate?.inlineSlot?(banner.slotId, didClick: Self.publicBanner(banner), elementId: elementId)
    }

    private func currentBanner(slotId: String, bannerId: String) -> PWInlineBanner? {
        guard let banner = store.banner(for: slotId), banner.bannerId == bannerId else {
            warn("Inline banner '\(bannerId)' is not in slot '\(slotId)', the event is not sent")
            return nil
        }
        return banner
    }

    // MARK: - Events

    private func track(_ type: String, _ banner: PWInlineBanner, elementId: String? = nil,
                       completion: ((Error?) -> Void)? = nil) {
        var event: [String: Any] = ["eventId": UUID().uuidString, "type": type, "slotId": banner.slotId,
                                    "bannerId": banner.bannerId, "version": banner.version,
                                    "timestamp": Int(now().timeIntervalSince1970), "test": banner.isTest]
        event["elementId"] = elementId
        event["userId"] = store.previousUserId
        eventSender(event) { [weak self] error in
            PWInlineManager.runOnMain {
                if let error = error {
                    self?.warn("Inline '\(type)' event of banner '\(banner.bannerId)' is not delivered: \(error.localizedDescription)")
                }
                completion?(error)
            }
        }
    }

    /// Sends through the request manager: a request that fails is kept in the retry queue, offline until
    /// the network is back.
    static func sendEvent(_ event: [String: Any], completion: @escaping (Error?) -> Void) {
        let request = PWTrackInlineEventRequest(event: event)
        guard !request.baseUrl().isEmpty else {
            completion(error(.endpointUnavailable, "No inline events endpoint"))
            return
        }
        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }

    /// Runs `work` at once on the main thread; from another thread queues it there without waiting.
    static func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    static func publicBanner(_ banner: PWInlineBanner) -> PushwooshInlineBanner {
        PushwooshInlineBanner(slotId: banner.slotId, bannerId: banner.bannerId, version: banner.version,
                              format: banner.raw["format"] as? String ?? "", html: banner.html,
                              payload: banner.payload,
                              expireDate: banner.expireDate, isTest: banner.isTest,
                              dictionary: banner.raw)
    }

    private static func error(_ code: ErrorCode, _ message: String) -> NSError {
        NSError(domain: errorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func name(of scheme: PWInlineColorScheme) -> String {
        switch scheme {
        case .app:
            return "app"
        case .system:
            return "system"
        case .light:
            return "light"
        case .dark:
            return "dark"
        @unknown default:
            return "unknown"
        }
    }

    private func log(_ message: String) {
        PushwooshLog.pushwooshLog(.PW_LL_INFO, className: "PWInlineManager", message: message)
    }

    private func warn(_ message: String) {
        PushwooshLog.pushwooshLog(.PW_LL_WARN, className: "PWInlineManager", message: message)
    }
}

/// Slots requested in this session for one user and application: another owner starts with none requested,
/// and an answer of an owner no longer marked frees no slot.
private struct RequestedSlots {
    private var owner: String?
    private var slots = Set<String>()

    func contains(_ slotId: String, owner: String?) -> Bool {
        owner == self.owner && slots.contains(slotId)
    }

    mutating func insert(_ slotIds: [String], owner: String?) {
        if owner != self.owner {
            self.owner = owner
            slots.removeAll()
        }
        slots.formUnion(slotIds)
    }

    mutating func remove(_ slotIds: [String], owner: String?) {
        if owner == self.owner {
            slots.subtract(slotIds)
        }
    }

    mutating func removeAll() {
        slots.removeAll()
    }
}
#endif
