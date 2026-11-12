//
//  PWInlineSessionTest.swift
//  PushwooshTests
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
import PushwooshCore
import PushwooshBridge
@testable import PushwooshInApp

private typealias CoreNotification = PushwooshInlineImplementation.CoreNotification

private final class PWInlineUpdateRecorder: NSObject, PWInlineDelegate {
    var updates: [String] = []

    func inlineSlot(_ slotId: String, didUpdate banner: PushwooshInlineBanner?) {
        updates.append("\(slotId)=\(banner?.bannerId ?? "empty")")
    }
}

class PWInlineSessionTest: XCTestCase {

    private var fileURL: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var owner: String? = "user-a|APP-1"
    private var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
    private var sent: [[String]] = []
    private var answers: [String: Any] = [:]
    private var holdAnswers = false
    private var answerHasNoSlots = false
    private var transportError: Error?
    private var held: [() -> Void] = []
    private var manager: PWInlineManager!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("banners.json")
        manager = makeManager()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func makeManager() -> PWInlineManager {
        let store = PWInlineStore(fileURL: fileURL, owner: { [unowned self] in self.owner },
                                  now: { [unowned self] in self.clock })
        return PWInlineManager(store: store, now: { [unowned self] in self.clock },
                               scheduler: { [unowned self] delay, work in self.scheduled.append((delay, work)) },
                               transport: { [unowned self] request, completion in
            self.sent.append(request.slots)
            let answer = self.answers
            let error = self.transportError
            let reply = {
                if error == nil {
                    request.parseResponse(self.answerHasNoSlots ? [:] : ["slots": answer])
                }
                completion(error)
            }
            if self.holdAnswers {
                self.held.append(reply)
            } else {
                reply()
            }
        }, eventSender: { _, completion in completion(nil) })
    }

    private func relaunch() {
        scheduled = []
        manager = makeManager()
    }

    private func fireScheduled() {
        let work = scheduled
        scheduled = []
        work.forEach { $0.work() }
    }

    private func nativeBanner(_ id: String, version: Int = 1) -> [String: Any] {
        ["bannerId": id, "version": version, "format": "native",
         "native": ["root": ["type": "text", "text": id]]]
    }

    @discardableResult
    private func request(_ slotIds: [String]) -> Error? {
        var result: Error?
        var finished = false
        manager.requestSlots(slotIds) { error in
            result = error
            finished = true
        }
        XCTAssertTrue(finished)
        return result
    }

    private func code(_ error: Error?) -> Int? {
        (error as NSError?)?.code
    }

    private func shown(_ slotId: String) -> String? {
        manager.banner(forSlot: slotId)?.bannerId
    }

    /// Verifies that without any known slot the session start, a user change and the accessors send nothing.
    func testNoKnownSlotsSendNothing() {
        let recorder = PWInlineUpdateRecorder()

        manager.applicationDidBecomeActive()
        manager.delegate = recorder
        manager.colorScheme = .dark
        _ = manager.banner(forSlot: "home_top")
        manager.userDidChange()

        XCTAssertTrue(sent.isEmpty)
        XCTAssertTrue(scheduled.isEmpty)
    }

    /// Verifies that the session start requests every known slot in one call.
    func testSessionStartRequestsKnownSlots() {
        manager.store.rememberSlots(["home_top", "cart_bottom"])

        manager.applicationDidBecomeActive()

        XCTAssertEqual(sent, [["cart_bottom", "home_top"]])
    }

    /// Verifies that a return within 30 minutes keeps the session and a 30-minute break starts a new one.
    func testThirtyMinuteBreakStartsNewSession() {
        manager.store.rememberSlots(["home_top"])
        manager.applicationDidBecomeActive()

        manager.applicationDidEnterBackground()
        clock.addTimeInterval(29 * 60)
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 1)

        manager.applicationDidEnterBackground()
        clock.addTimeInterval(30 * 60)
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 2)
    }

    /// Verifies that more than 10 known slots are requested in calls of at most 10 slots.
    func testKnownSlotsGoTenPerRequest() {
        let slots = (1...23).map { "slot_\($0)" }
        manager.store.rememberSlots(slots)

        manager.applicationDidBecomeActive()

        XCTAssertEqual(sent.map(\.count), [10, 10, 3])
        XCTAssertEqual(Set(sent.joined()), Set(slots))
    }

    /// Verifies that a manual request for more than 10 slots fails without network.
    func testManualRequestOverTenSlotsFails() {
        let error = request((1...11).map { "slot_\($0)" })

        XCTAssertEqual(code(error), PWInlineManager.ErrorCode.invalidArgument.rawValue)
        XCTAssertTrue(sent.isEmpty)
    }

    /// Verifies the manual limit: 5 requests at session start, then one per 3 minutes, full again in a new session.
    func testManualLimitIsFiveThenOnePerThreeMinutes() {
        let rateLimited = PWInlineManager.ErrorCode.rateLimited.rawValue
        manager.applicationDidBecomeActive()
        for _ in 1...5 {
            XCTAssertNil(request(["home_top"]))
        }
        XCTAssertEqual(code(request(["home_top"])), rateLimited)

        clock.addTimeInterval(179)
        XCTAssertEqual(code(request(["home_top"])), rateLimited)
        clock.addTimeInterval(1)
        XCTAssertNil(request(["home_top"]))
        XCTAssertEqual(code(request(["home_top"])), rateLimited)
        XCTAssertEqual(sent.count, 6)

        manager.applicationDidEnterBackground()
        clock.addTimeInterval(30 * 60)
        manager.applicationDidBecomeActive()
        let afterSessionStart = sent.count
        for _ in 1...5 {
            XCTAssertNil(request(["home_top"]))
        }
        XCTAssertEqual(sent.count, afterSessionStart + 5)
    }

    /// Verifies that a request over the limit keeps the cached banner.
    func testLimitedRequestKeepsCachedBanner() {
        answers = ["home_top": nativeBanner("b1")]
        for _ in 1...5 {
            request(["home_top"])
        }
        answers = ["home_top": nativeBanner("b2")]

        XCTAssertNotNil(request(["home_top"]))

        XCTAssertEqual(shown("home_top"), "b1")
    }

    /// Verifies that automatic requests do not spend the manual limit.
    func testAutomaticRequestsDoNotSpendManualLimit() {
        manager.store.rememberSlots(["home_top"])
        manager.applicationDidBecomeActive()
        manager.userDidChange()
        manager.slotDidAppear("cart_bottom")
        fireScheduled()
        let automatic = sent.count

        for _ in 1...5 {
            XCTAssertNil(request(["home_top"]))
        }

        XCTAssertEqual(automatic, 3)
        XCTAssertEqual(sent.count, automatic + 5)
    }

    /// Verifies that new slot views within 0.5 s share one request and slots already requested are left out.
    func testNewSlotViewsShareOneRequest() {
        answers = ["home_top": nativeBanner("b1")]
        request(["home_top"])

        manager.slotDidAppear("cart_bottom")
        manager.slotDidAppear("home_top")
        manager.slotDidAppear("pdp_offer")
        manager.slotDidAppear("cart_bottom")
        XCTAssertEqual(scheduled.map(\.delay), [0.5])
        fireScheduled()

        XCTAssertEqual(sent.last, ["cart_bottom", "pdp_offer"])
        manager.slotDidAppear("cart_bottom")
        XCTAssertTrue(scheduled.isEmpty)
    }

    /// Verifies that a slot seen in an earlier launch is requested at session start until it goes 30 days without a view.
    func testKnownSlotSurvivesRelaunchAndIsForgottenAfterThirtyDays() {
        manager.slotDidAppear("home_top")

        clock.addTimeInterval(29 * 24 * 3600)
        relaunch()
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent, [["home_top"]])

        clock.addTimeInterval(24 * 3600)
        relaunch()
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 1)
    }

    /// Verifies that the previous user's slots keep their banners until the server confirms the new user,
    /// then are emptied and filled for the new user.
    func testUserChangeReplacesPreviousUserBanners() {
        let recorder = PWInlineUpdateRecorder()
        manager.delegate = recorder
        answers = ["home_top": nativeBanner("b_user_a")]
        request(["home_top"])

        owner = "user-b|APP-1"
        XCTAssertEqual(shown("home_top"), "b_user_a")
        answers = ["home_top": nativeBanner("b_user_b")]
        manager.userDidChange()

        XCTAssertEqual(shown("home_top"), "b_user_b")
        XCTAssertEqual(recorder.updates, ["home_top=b_user_a", "home_top=empty", "home_top=b_user_b"])
    }

    /// Verifies that during an unconfirmed user change no slot is requested and no answer is applied, so a refused
    /// change leaves the previous user's banners and closed banners as they were.
    func testRefusedUserChangeKeepsPreviousUserBanners() {
        answers = ["home_top": nativeBanner("b_user_a"), "cart_bottom": nativeBanner("c_user_a")]
        request(["home_top", "cart_bottom"])
        answers = ["home_top": nativeBanner("b_user_a")]
        manager.dismiss(slotId: "cart_bottom", bannerId: "c_user_a")
        let sentBeforeChange = sent.count

        owner = "user-b|APP-1"
        answers = ["home_top": nativeBanner("b_user_b"), "cart_bottom": nativeBanner("c_user_a")]
        XCTAssertEqual(code(request(["home_top"])), PWInlineManager.ErrorCode.ownerChanged.rawValue)
        manager.applyEventSlots(["slots": answers], owner: "user-b|APP-1")
        XCTAssertEqual(sent.count, sentBeforeChange)
        XCTAssertEqual(shown("home_top"), "b_user_a")

        owner = "user-a|APP-1"
        manager.userChangeDidFail()
        request(["cart_bottom"])

        XCTAssertEqual(shown("home_top"), "b_user_a")
        XCTAssertNil(shown("cart_bottom"))
        XCTAssertNil(manager.store.previousUserId)
    }

    /// Verifies that an answer for the previous user dropped after a confirmed change does not free the slot the new
    /// user's request is still in flight for, so the slot is not requested twice.
    func testDroppedAnswerOfPreviousUserKeepsNewUserRequestInFlight() {
        holdAnswers = true
        manager.requestSlots(["home_top"], completion: nil)
        owner = "user-b|APP-1"
        manager.userDidChange()
        XCTAssertEqual(sent, [["home_top"], ["home_top"]])

        held.removeFirst()()
        manager.slotDidAppear("home_top")
        fireScheduled()

        XCTAssertEqual(sent.count, 2)
    }

    /// Verifies that a slot held back during an unconfirmed user change is requested once the change is refused,
    /// also when it was already requested for the previous user in this session.
    func testSlotHeldDuringUnconfirmedUserChangeIsRequestedAfterRefusal() {
        request(["home_top"])
        owner = "user-b|APP-1"
        manager.retriedEventDelivered(["type": "dismiss", "slotId": "home_top"])
        XCTAssertEqual(sent.count, 1)

        owner = "user-a|APP-1"
        answers = ["home_top": nativeBanner("b_user_a")]
        manager.userChangeDidFail()

        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(shown("home_top"), "b_user_a")
    }

    /// Verifies that a session start during an unconfirmed user change keeps the previous user's banners and
    /// requests nothing until the server confirms the change.
    func testSessionStartDuringUnconfirmedUserChangeWaitsForTheServer() {
        answers = ["home_top": nativeBanner("b_user_a")]
        request(["home_top"])
        owner = "user-b|APP-1"
        answers = ["home_top": nativeBanner("b_user_b")]

        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(shown("home_top"), "b_user_a")

        manager.userDidChange()
        XCTAssertEqual(shown("home_top"), "b_user_b")
    }

    /// Verifies that a return from the background during an unconfirmed user change holds no slot back, so a refusal
    /// requests nothing for slots the previous user already has.
    func testReturnDuringUnconfirmedUserChangeRequestsNothingAfterRefusal() {
        answers = ["home_top": nativeBanner("b_user_a")]
        manager.store.rememberSlots(["home_top", "cart_bottom"])
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 1)

        manager.applicationDidEnterBackground()
        owner = "user-b|APP-1"
        manager.applicationDidBecomeActive()
        owner = "user-a|APP-1"
        manager.userChangeDidFail()

        XCTAssertEqual(sent.count, 1)
    }

    /// Verifies that a refusal requests the held slots and the previous user's slots not requested yet in one request.
    func testRefusalRequestsHeldAndUnrequestedSlotsTogether() {
        request(["home_top"])
        owner = "user-b|APP-1"
        manager.retriedEventDelivered(["type": "dismiss", "slotId": "home_top"])
        manager.store.rememberSlots(["cart_bottom"])

        owner = "user-a|APP-1"
        manager.userChangeDidFail()

        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent.last.map(Set.init), ["cart_bottom", "home_top"])
    }

    /// Verifies that an answer requested for the previous user or application is dropped.
    func testAnswerForPreviousOwnerIsDropped() {
        holdAnswers = true
        answers = ["home_top": nativeBanner("b1")]
        var result: Error?
        manager.requestSlots(["home_top"]) { result = $0 }

        owner = "user-a|APP-2"
        held.forEach { $0() }

        XCTAssertEqual(code(result), PWInlineManager.ErrorCode.ownerChanged.rawValue)
        XCTAssertNil(shown("home_top"))
    }

    /// Verifies that banners cached for one user and application are not shown after a relaunch under another.
    func testCacheOfAnotherOwnerIsNotShownAfterRelaunch() {
        answers = ["home_top": nativeBanner("b1")]
        request(["home_top"])

        owner = "user-a|APP-2"
        relaunch()

        XCTAssertNil(shown("home_top"))
    }

    /// Verifies that the banner block of a postEvent answer updates only the slots it lists.
    func testEventAnswerUpdatesOnlyListedSlots() {
        let recorder = PWInlineUpdateRecorder()
        manager.delegate = recorder
        answers = ["home_top": nativeBanner("b1"), "cart_bottom": nativeBanner("c1")]
        request(["home_top", "cart_bottom"])

        manager.applyEventSlots(["slots": ["cart_bottom": nativeBanner("c2")]], owner: owner)
        XCTAssertEqual(shown("home_top"), "b1")
        XCTAssertEqual(shown("cart_bottom"), "c2")

        manager.applyEventSlots(["slots": ["cart_bottom": NSNull()]], owner: owner)
        XCTAssertEqual(shown("home_top"), "b1")
        XCTAssertNil(shown("cart_bottom"))
        XCTAssertEqual(recorder.updates.suffix(2), ["cart_bottom=c2", "cart_bottom=empty"])
    }

    /// Verifies that the banner block of a postEvent answer sent for the previous user does not reach the current user.
    func testEventAnswerForPreviousOwnerIsDropped() {
        manager.applyEventSlots(["slots": ["home_top": nativeBanner("b_user_a")]], owner: "user-a|APP-1")
        XCTAssertEqual(shown("home_top"), "b_user_a")

        owner = "user-b|APP-1"
        manager.applyEventSlots(["slots": ["home_top": nativeBanner("b_late_a")]], owner: "user-a|APP-1")
        XCTAssertEqual(shown("home_top"), "b_user_a")

        manager.userDidChange()
        manager.applyEventSlots(["slots": ["home_top": nativeBanner("b_user_b")]], owner: "user-b|APP-1")
        XCTAssertEqual(shown("home_top"), "b_user_b")
    }

    /// Verifies that a slot whose automatic request failed is requested again when its view shows up again.
    func testFailedRequestIsRepeatedWhenSlotShowsAgain() {
        manager.store.rememberSlots(["home_top"])
        transportError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        manager.applicationDidBecomeActive()

        transportError = nil
        answers = ["home_top": nativeBanner("b1")]
        manager.slotDidAppear("home_top")
        fireScheduled()

        XCTAssertEqual(sent, [["home_top"], ["home_top"]])
        XCTAssertEqual(shown("home_top"), "b1")
    }

    /// Verifies that an answer without a slots object leaves the slots unrequested, so they are requested again.
    func testAnswerWithoutSlotsIsRepeatedWhenSlotShowsAgain() {
        manager.store.rememberSlots(["home_top"])
        answerHasNoSlots = true
        manager.applicationDidBecomeActive()

        answerHasNoSlots = false
        answers = ["home_top": nativeBanner("b1")]
        manager.slotDidAppear("home_top")
        fireScheduled()

        XCTAssertEqual(sent, [["home_top"], ["home_top"]])
        XCTAssertEqual(shown("home_top"), "b1")
    }

    /// Verifies that inline slots handed to the back-channel on the main thread are applied before the call returns.
    func testBackchannelAppliesEventSlotsBeforeReturning() {
        let slotId = "backchannel_\(UUID().uuidString)"
        let preferences = PWPreferences.preferencesInstance()
        let store = PWInlineManager.shared.store
        defer { store.apply([slotId], banners: [:]) }

        PushwooshInAppBackchannel().handleInlineSlots(["slots": [slotId: nativeBanner("b1")]],
                                                      userId: preferences.userId, appCode: preferences.appCode)

        XCTAssertEqual(PWInlineManager.shared.banner(forSlot: slotId)?.bannerId, "b1")
    }

    /// Verifies that every Core notification name and userInfo key the module observes has the value Core exports.
    func testCoreNotificationNamesAndKeysAreTheOnesCoreExports() {
        let coreSymbols = [
            "kPWReachabilityChangedNotification": CoreNotification.reachabilityChanged.rawValue,
            "PWRetryQueueDidDeliverRequestNotification": CoreNotification.retryDelivered.rawValue,
            "PWRetryQueueMethodNameKey": CoreNotification.retryMethodNameKey,
            "PWRetryQueueBodyKey": CoreNotification.retryBodyKey,
            "kPWActiveApplicationChangedNotification": CoreNotification.applicationChanged.rawValue,
            "kPWActiveApplicationChangedAppCodeChangedKey": CoreNotification.appCodeChangedKey,
        ]
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
        for (symbol, value) in coreSymbols {
            guard let address = dlsym(defaultHandle, symbol) else {
                XCTFail("PushwooshCore does not export \(symbol)")
                continue
            }
            XCTAssertEqual(address.load(as: NSString.self) as String, value, symbol)
        }
    }

    /// Verifies that the module hears Core's reachability and retry queue delivery notifications by their Core names.
    func testCoreNotificationsReachTheManager() {
        let center = NotificationCenter()
        PushwooshInlineImplementation.observe(self.manager, in: center)
        manager.store.rememberSlots(["home_top"])
        transportError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        manager.applicationDidBecomeActive()
        transportError = nil
        answers = ["home_top": nativeBanner("b1")]

        center.post(name: CoreNotification.reachabilityChanged, object: nil)
        XCTAssertEqual(shown("home_top"), "b1")

        center.post(name: CoreNotification.retryDelivered, object: nil,
                    userInfo: [CoreNotification.retryMethodNameKey: "trackInlineEvent",
                               CoreNotification.retryBodyKey: ["type": "dismiss", "slotId": "cart_bottom"]])
        XCTAssertEqual(sent.last, ["cart_bottom"])
    }

    /// Verifies that a slot whose automatic request failed is requested again when the network or the app comes back.
    func testFailedRequestIsRepeatedWhenNetworkOrAppComesBack() {
        manager.store.rememberSlots(["home_top"])
        transportError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        manager.applicationDidBecomeActive()

        manager.networkReachabilityDidChange()
        XCTAssertEqual(sent.count, 2)

        transportError = nil
        answers = ["home_top": nativeBanner("b1")]
        manager.applicationDidEnterBackground()
        clock.addTimeInterval(60)
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 3)
        XCTAssertEqual(shown("home_top"), "b1")

        manager.networkReachabilityDidChange()
        manager.applicationDidEnterBackground()
        manager.applicationDidBecomeActive()
        XCTAssertEqual(sent.count, 3)
    }

    /// Verifies that a cache the app cannot read yet (before the first unlock) is not overwritten and is read
    /// once it can be, keeping what came meanwhile.
    func testUnreadableCacheIsKeptAndReadLater() throws {
        let path = fileURL.path
        answers = ["home_top": nativeBanner("b1")]
        request(["home_top"])
        relaunch()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path) }

        relaunch()
        XCTAssertNil(shown("home_top"))
        answers = ["cart_bottom": nativeBanner("c1")]
        request(["cart_bottom"])
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path)
        holdAnswers = true
        manager.applicationDidBecomeActive()

        XCTAssertEqual(shown("home_top"), "b1")
        XCTAssertEqual(shown("cart_bottom"), "c1")
        relaunch()
        XCTAssertEqual(shown("home_top"), "b1")
        XCTAssertEqual(shown("cart_bottom"), "c1")
    }

    /// Verifies that a change of the application code clears the previous application's banners and requests
    /// the known slots again, and a change that keeps the code does nothing.
    func testApplicationChangeClearsBannersAndRequestsKnownSlots() {
        let center = NotificationCenter()
        PushwooshInlineImplementation.observe(self.manager, in: center)
        let changed = CoreNotification.applicationChanged
        answers = ["home_top": nativeBanner("b1")]
        request(["home_top"])

        center.post(name: changed, object: nil, userInfo: [CoreNotification.appCodeChangedKey: false])
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(shown("home_top"), "b1")

        owner = "user-a|APP-2"
        holdAnswers = true
        center.post(name: changed, object: nil, userInfo: [CoreNotification.appCodeChangedKey: true])

        XCTAssertNil(shown("home_top"))
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent.last, ["home_top"])
    }

    /// Verifies that slots whose answer was dropped because the owner changed are requested again on the next chance.
    func testSlotsOfDroppedAnswerAreRequestedAgain() {
        manager.store.rememberSlots(["home_top"])
        holdAnswers = true
        answers = ["home_top": nativeBanner("b1")]
        manager.applicationDidBecomeActive()
        owner = "user-b|APP-1"
        held.forEach { $0() }
        held = []

        owner = "user-a|APP-1"
        holdAnswers = false
        manager.networkReachabilityDidChange()

        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(shown("home_top"), "b1")
    }

    /// Verifies that an expired banner is not shown from the cache on a relaunch without network.
    func testExpiredBannerIsNotShownFromCache() {
        var banner = nativeBanner("b1")
        banner["expireDate"] = Int(clock.timeIntervalSince1970) + 60
        answers = ["home_top": banner]
        request(["home_top"])
        XCTAssertEqual(shown("home_top"), "b1")

        clock.addTimeInterval(61)
        relaunch()

        XCTAssertNil(shown("home_top"))
        XCTAssertEqual(sent.count, 1)
    }
}
#endif
