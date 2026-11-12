//
//  PWInlineEventsTest.swift
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

private final class PWInlineEventsRecorder: NSObject, PWInlineDelegate {
    var shown: [String] = []
    var clicks: [String] = []
    var dismissed: [String] = []
    var updates: [String] = []

    func inlineSlot(_ slotId: String, didShow banner: PushwooshInlineBanner) {
        shown.append("\(slotId)=\(banner.bannerId)")
    }

    func inlineSlot(_ slotId: String, didClick banner: PushwooshInlineBanner, elementId: String?) {
        clicks.append("\(banner.bannerId)/\(elementId ?? "banner")")
    }

    func inlineSlot(_ slotId: String, didDismiss banner: PushwooshInlineBanner) {
        dismissed.append("\(slotId)=\(banner.bannerId)")
    }

    func inlineSlot(_ slotId: String, didUpdate banner: PushwooshInlineBanner?) {
        updates.append("\(slotId)=\(banner?.bannerId ?? "empty")")
    }
}

private final class PWInlinePresentingController: UIViewController {
    var presented: UIViewController?

    override var presentedViewController: UIViewController? {
        presented
    }
}

class PWInlineEventsTest: XCTestCase {

    private var fileURL: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var owner: String? = "user-a|APP-1"
    private var sent: [[String]] = []
    private var answers: [String: Any] = [:]
    private var events: [[String: Any]] = []
    private var eventError: Error?
    private var manager: PWInlineManager!
    private var recorder: PWInlineEventsRecorder!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("banners.json")
        recorder = PWInlineEventsRecorder()
        manager = makeManager()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func makeManager() -> PWInlineManager {
        let store = PWInlineStore(fileURL: fileURL, owner: { [unowned self] in self.owner },
                                  now: { [unowned self] in self.clock })
        let manager = PWInlineManager(store: store, now: { [unowned self] in self.clock },
                                      scheduler: { _, _ in },
                                      transport: { [unowned self] request, completion in
            self.sent.append(request.slots)
            request.parseResponse(["slots": self.answers])
            completion(nil)
        }, eventSender: { [unowned self] event, completion in
            self.events.append(event)
            completion(self.eventError)
        })
        manager.delegate = recorder
        return manager
    }

    private func relaunch() {
        manager = makeManager()
    }

    private func nativeBanner(_ id: String, version: Int = 1, extra: [String: Any] = [:]) -> [String: Any] {
        ["bannerId": id, "version": version, "format": "native",
         "native": ["root": ["type": "text", "text": id]]].merging(extra) { _, new in new }
    }

    private func deliver(_ banner: [String: Any], to slotId: String = "home_top") {
        manager.applyEventSlots(["slots": [slotId: banner]], owner: owner)
    }

    private func stored(_ slotId: String = "home_top") -> PWInlineBanner? {
        manager.store.banner(for: slotId)
    }

    private func shown(_ slotId: String = "home_top") -> String? {
        manager.banner(forSlot: slotId)?.bannerId
    }

    private var types: [String] {
        events.map { $0["type"] as? String ?? "" }
    }

    // MARK: - Show

    /// Verifies that a banner version is reported as shown once, across repeats, manual reports and relaunch.
    func testShowIsReportedOncePerBannerVersion() throws {
        deliver(nativeBanner("b1"))
        let banner = try XCTUnwrap(stored())

        manager.bannerDidBecomeVisible(banner)
        manager.bannerDidBecomeVisible(banner)
        manager.trackShown(slotId: "home_top", bannerId: "b1")
        relaunch()
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))

        XCTAssertEqual(types, ["show"])
        XCTAssertEqual(recorder.shown, ["home_top=b1"])

        deliver(nativeBanner("b1", version: 2))
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))

        XCTAssertEqual(types, ["show", "show"])
        XCTAssertEqual(events.last?["version"] as? Int, 2)
    }

    /// Verifies that another user gets the show of a banner the previous user already saw.
    func testShowIsReportedAgainForAnotherUser() throws {
        deliver(nativeBanner("b1"))
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))

        owner = "user-b|APP-1"
        manager.store.rememberSlots(["home_top"])
        answers = ["home_top": nativeBanner("b1")]
        manager.userDidChange()
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))

        XCTAssertEqual(types, ["show", "show"])
    }

    /// Verifies the fields of an event: a fresh UUID, the banner, the moment it happened and the test flag.
    func testManualShowSendsEventOfThatMoment() throws {
        deliver(nativeBanner("b1", version: 3, extra: ["test": true]))
        clock.addTimeInterval(42)

        manager.trackShown(slotId: "home_top", bannerId: "other")
        manager.trackShown(slotId: "home_top", bannerId: "b1")

        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertNotNil(UUID(uuidString: event["eventId"] as? String ?? ""))
        XCTAssertEqual(event["type"] as? String, "show")
        XCTAssertEqual(event["slotId"] as? String, "home_top")
        XCTAssertEqual(event["bannerId"] as? String, "b1")
        XCTAssertEqual(event["version"] as? Int, 3)
        XCTAssertEqual(event["timestamp"] as? Int, 1_800_000_042)
        XCTAssertEqual(event["test"] as? Bool, true)
        XCTAssertNil(event["elementId"])
        XCTAssertEqual(recorder.shown, ["home_top=b1"])
    }

    // MARK: - Click

    /// Verifies that every click is sent with the tapped element, or without it for the banner itself.
    func testClickCarriesTappedElement() throws {
        deliver(nativeBanner("b1"))

        manager.didClick(try XCTUnwrap(stored()), elementId: "cta_buy")
        manager.trackClick(slotId: "home_top", bannerId: "b1", elementId: nil)

        XCTAssertEqual(types, ["click", "click"])
        XCTAssertEqual(events[0]["elementId"] as? String, "cta_buy")
        XCTAssertNil(events[1]["elementId"])
        XCTAssertNotEqual(events[0]["eventId"] as? String, events[1]["eventId"] as? String)
        XCTAssertEqual(recorder.clicks, ["b1/cta_buy", "b1/banner"])
    }

    /// Verifies that a tap on a banner the slot showed before a confirmed user change sends no click and tells no delegate.
    func testTapOnPreviousUsersBannerIsNotClick() throws {
        deliver(nativeBanner("b1", extra: ["action": ["type": "copy", "text": "PROMO"]]))
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let body = try XCTUnwrap(views(PWInlineBoxView.self, in: slot).first { $0.onTap != nil })
        _ = body.accessibilityActivate()

        owner = "user-b|APP-1"
        manager.userDidChange()
        _ = body.accessibilityActivate()

        XCTAssertEqual(types, ["click"])
        XCTAssertEqual(recorder.clicks, ["b1/banner"])
    }

    /// Verifies that a banner shown before a user change keeps its show, click and close until the server
    /// confirms the new user, and they are sent for the user the banner was shown to.
    func testBannerEventsInUserChangeWindowGoToPreviousUser() throws {
        deliver(nativeBanner("b1"))
        let banner = try XCTUnwrap(stored())

        owner = "user-b|APP-1"
        manager.bannerDidBecomeVisible(banner)
        manager.didClick(banner, elementId: nil)
        manager.dismiss(slotId: "home_top", bannerId: "b1")

        XCTAssertEqual(types, ["show", "click", "dismiss"])
        XCTAssertEqual(events.map { $0["userId"] as? String }, ["user-a", "user-a", "user-a"])
        XCTAssertEqual(recorder.clicks, ["b1/banner"])
        XCTAssertEqual(recorder.dismissed, ["home_top=b1"])
    }

    /// Verifies that the postEvent action of a banner tapped before the server confirms a new user is not posted
    /// for the new user, while its click still goes to the previous user.
    func testPostEventActionIsNotPostedForUnconfirmedUser() throws {
        deliver(nativeBanner("b1", extra: ["action": ["type": "postEvent", "event": "promo_tap"]]))
        var posted: [String] = []
        manager.postEvent = { name, _ in posted.append(name) }
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let body = try XCTUnwrap(views(PWInlineBoxView.self, in: slot).first { $0.onTap != nil })

        _ = body.accessibilityActivate()
        owner = "user-b|APP-1"
        _ = body.accessibilityActivate()

        XCTAssertEqual(posted, ["promo_tap"])
        XCTAssertEqual(types, ["click", "click"])
        XCTAssertEqual(events.map { $0["userId"] as? String }, [nil, "user-a"])
    }

    /// Verifies that `pushwoosh.postEvent()` of an HTML banner is allowed for a confirmed user and held back
    /// until the server confirms a new one.
    func testHTMLPostEventIsHeldForUnconfirmedUser() throws {
        deliver(htmlBanner(version: 1))
        let (slot, _, content) = try htmlSlot()
        let shouldPostEvent = try XCTUnwrap(content.shouldPostEvent)

        XCTAssertTrue(shouldPostEvent())
        owner = "user-b|APP-1"
        XCTAssertFalse(shouldPostEvent())
        withExtendedLifetime(slot) {}
    }

    // MARK: - Dismiss

    /// Verifies that a dismissed banner is sent to the server and the slot then gets the next banner.
    func testDismissIsSentAndSlotGetsNextBanner() {
        deliver(nativeBanner("b1"))
        answers = ["home_top": nativeBanner("b2")]

        manager.dismiss(slotId: "home_top", bannerId: "b1")

        XCTAssertEqual(types, ["dismiss"])
        XCTAssertEqual(events.first?["bannerId"] as? String, "b1")
        XCTAssertEqual(recorder.dismissed, ["home_top=b1"])
        XCTAssertEqual(sent, [["home_top"]])
        XCTAssertEqual(shown(), "b2")
    }

    /// Verifies that a dismiss the server did not get leaves the slot empty without asking for the next banner.
    func testUndeliveredDismissLeavesSlotEmpty() {
        deliver(nativeBanner("b1"))
        eventError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        manager.dismiss(slotId: "home_top", bannerId: "b1")

        XCTAssertEqual(types, ["dismiss"])
        XCTAssertTrue(sent.isEmpty)
        XCTAssertNil(shown())
    }

    /// Verifies that a dismiss the retry queue delivers later still gets the slot its next banner.
    func testDismissDeliveredByRetryGetsNextBanner() {
        deliver(nativeBanner("b1"))
        eventError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        manager.dismiss(slotId: "home_top", bannerId: "b1")
        XCTAssertTrue(sent.isEmpty)

        answers = ["home_top": nativeBanner("b2")]
        manager.retriedEventDelivered(events[0])

        XCTAssertEqual(sent, [["home_top"]])
        XCTAssertEqual(shown(), "b2")
    }

    /// Verifies that a dismissed banner stays hidden after relaunch until its expireDate, then shows again.
    func testDismissedBannerStaysHiddenUntilItExpires() {
        let expireDate = Int(clock.timeIntervalSince1970) + 3600
        deliver(nativeBanner("b1", extra: ["expireDate": expireDate]))
        manager.dismiss(slotId: "home_top", bannerId: "b1")
        relaunch()

        deliver(nativeBanner("b1", extra: ["expireDate": expireDate + 3600]))
        XCTAssertNil(shown())

        clock.addTimeInterval(3601)
        deliver(nativeBanner("b1", extra: ["expireDate": expireDate + 3600]))
        XCTAssertEqual(shown(), "b1")
    }

    /// Verifies that a banner dismissed by one user is shown to another user.
    func testDismissedBannerShowsForAnotherUser() {
        deliver(nativeBanner("b1"))
        manager.dismiss(slotId: "home_top", bannerId: "b1")

        owner = "user-b|APP-1"
        manager.store.rememberSlots(["home_top"])
        answers = ["home_top": nativeBanner("b1")]
        manager.userDidChange()

        XCTAssertEqual(shown(), "b1")
    }

    // MARK: - Control group

    /// Verifies that a control banner read as data comes back empty and is reported as control once.
    func testControlBannerReadAsDataIsEmptyAndReportedOnce() {
        deliver(["bannerId": "c1", "version": 1, "control": true])

        XCTAssertNil(shown())
        XCTAssertNil(shown())

        XCTAssertEqual(types, ["control"])
        XCTAssertEqual(events.first?["bannerId"] as? String, "c1")
        XCTAssertEqual(recorder.updates, ["home_top=empty"])
        XCTAssertTrue(recorder.shown.isEmpty)
    }

    /// Verifies that a visible control slot reports control, not a show, once per banner version.
    func testVisibleControlSlotReportsControlOnce() throws {
        deliver(["bannerId": "c1", "version": 1, "control": true])
        let banner = try XCTUnwrap(stored())

        manager.bannerDidBecomeVisible(banner)
        manager.bannerDidBecomeVisible(banner)
        _ = manager.banner(forSlot: "home_top")

        XCTAssertEqual(types, ["control"])
        XCTAssertTrue(recorder.shown.isEmpty)
    }

    // MARK: - Banner as data

    /// Verifies that an app rendering the banner itself gets a JSON snapshot and reports by strings as the view does.
    func testBannerAsDataIsJSONAndReportsLikeTheView() throws {
        deliver(nativeBanner("b1", extra: ["payload": ["campaign": "autumn"], "close": ["enabled": true]]))
        answers = ["home_top": nativeBanner("b2")]

        let banner = try XCTUnwrap(manager.banner(forSlot: "home_top"))
        let json = try JSONSerialization.data(withJSONObject: banner.dictionary)
        let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(snapshot["bannerId"] as? String, "b1")
        XCTAssertEqual(snapshot["payload"] as? [String: String], ["campaign": "autumn"])

        manager.trackShown(slotId: "home_top", bannerId: banner.bannerId)
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))
        manager.trackClick(slotId: "home_top", bannerId: banner.bannerId, elementId: "cta_buy")
        manager.dismiss(slotId: "home_top", bannerId: banner.bannerId)

        XCTAssertEqual(types, ["show", "click", "dismiss"])
        XCTAssertEqual(events[1]["elementId"] as? String, "cta_buy")
        XCTAssertEqual(shown(), "b2")
    }

    // MARK: - Test banners

    /// Verifies that a test banner covers the live banner of its slot, live updates included, until relaunch.
    func testTestBannerCoversLiveBannerUntilRelaunch() {
        deliver(nativeBanner("live1"))
        deliver(nativeBanner("draft", extra: ["test": true]))

        XCTAssertEqual(shown(), "draft")
        XCTAssertEqual(manager.banner(forSlot: "home_top")?.isTest, true)

        deliver(nativeBanner("live2"))
        XCTAssertEqual(shown(), "draft")

        relaunch()
        XCTAssertEqual(shown(), "live2")
    }

    /// Verifies that a test banner in an empty slot is gone after relaunch.
    func testTestBannerIsNotKeptAcrossRelaunch() {
        deliver(nativeBanner("draft", extra: ["test": true]))
        XCTAssertEqual(shown(), "draft")

        relaunch()

        XCTAssertNil(shown())
    }

    /// Verifies that dismissing a test banner sends a test event and uncovers the live banner.
    func testDismissedTestBannerUncoversLiveBanner() {
        deliver(nativeBanner("live1"))
        deliver(nativeBanner("draft", extra: ["test": true]))
        answers = ["home_top": nativeBanner("live1")]

        manager.dismiss(slotId: "home_top", bannerId: "draft")

        XCTAssertEqual(types, ["dismiss"])
        XCTAssertEqual(events.first?["test"] as? Bool, true)
        XCTAssertEqual(shown(), "live1")
        XCTAssertEqual(recorder.updates.last, "home_top=live1")
    }

    /// Verifies that a dismissed test banner does not come back in a later answer of the same launch.
    func testDismissedTestBannerStaysHidden() {
        deliver(nativeBanner("draft", extra: ["test": true]))
        answers = ["home_top": nativeBanner("draft", extra: ["test": true])]

        manager.dismiss(slotId: "home_top", bannerId: "draft")

        XCTAssertNil(shown())
    }

    /// Verifies that a test banner shown before is reported again as the live banner with the same id and version.
    func testTestShowDoesNotHideLiveShow() throws {
        deliver(nativeBanner("b1", extra: ["test": true]))
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))
        relaunch()

        deliver(nativeBanner("b1"))
        manager.bannerDidBecomeVisible(try XCTUnwrap(stored()))

        XCTAssertEqual(types, ["show", "show"])
        XCTAssertEqual(events.map { $0["test"] as? Bool }, [true, false])
    }

    /// Verifies that a payload value that is not a string drops only its own key.
    func testPayloadKeepsStringValuesBesideOthers() {
        deliver(nativeBanner("b1", extra: ["payload": ["campaign": "autumn", "discount": 15, "tier": "gold"]]))

        XCTAssertEqual(manager.banner(forSlot: "home_top")?.payload, ["campaign": "autumn", "tier": "gold"])
    }

    /// Verifies that another user does not see the previous user's test banner.
    func testTestBannerIsClearedForAnotherUser() {
        deliver(nativeBanner("draft", extra: ["test": true]))

        owner = "user-b|APP-1"
        manager.store.rememberSlots(["home_top"])
        manager.userDidChange()

        XCTAssertNil(shown())
    }

    // MARK: - Slot view

    /// Verifies that the close button of a banner hides it in the slot view and sends the dismiss.
    func testCloseButtonHidesBannerInSlot() throws {
        deliver(nativeBanner("b1", extra: ["close": ["enabled": true, "position": "topLeft"]]))
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        slot.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(slot)
        NSLayoutConstraint.activate([
            slot.topAnchor.constraint(equalTo: window.topAnchor),
            slot.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            slot.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])
        window.layoutIfNeeded()

        let close = try XCTUnwrap(button(labelled: "Close", in: slot))
        XCTAssertLessThan(close.convert(close.bounds, to: slot).midX, slot.bounds.midX)
        tap(close)
        window.layoutIfNeeded()

        XCTAssertEqual(types, ["dismiss"])
        XCTAssertEqual(slot.frame.height, 0)
    }

    /// Verifies that an HTML control running registerForPushNotifications or openAppSettings, which close the
    /// banner, is a click and then a dismiss, whichever comes first: the close or the tapped control.
    func testHTMLClosingActionIsClickThenDismiss() throws {
        for (version, closeFirst) in [(1, true), (2, false)] {
            events = []
            recorder.dismissed = []
            deliver(htmlBanner(version: version))
            let (slot, html, content) = try htmlSlot()

            html.beginTap()
            if !closeFirst {
                html.handleHit("own")
            }
            content.closingActionDidRun?()
            content.closeInApp?()
            if closeFirst {
                html.handleHit("own")
            }

            XCTAssertEqual(types, ["click", "dismiss"], "close first: \(closeFirst)")
            XCTAssertNil(events.first?["elementId"])
            XCTAssertEqual(recorder.dismissed, ["home_top=story"])
            XCTAssertNotNil(slot)
        }
    }

    /// Verifies that an HTML control calling closeInApp, at once or within a second of the tap, is only a dismiss.
    func testHTMLCloseInAppAfterTapIsOnlyDismiss() throws {
        for (version, delay) in [(1, nil), (2, 0.3)] as [(Int, TimeInterval?)] {
            events = []
            deliver(htmlBanner(version: version))
            let (slot, html, content) = try htmlSlot()

            html.beginTap()
            if let delay = delay {
                html.handleHit("own")
                spin(delay)
                content.closeInApp?()
            } else {
                content.closeInApp?()
                html.handleHit("own")
            }
            spin(1.2)

            XCTAssertEqual(types, ["dismiss"], "close after \(delay ?? 0) s")
            XCTAssertNotNil(slot)
        }
    }

    /// Verifies that a tap on an HTML element with its own action but no data-pw-id is a click of the banner,
    /// without running the banner's own action.
    func testTapOnUnmarkedHTMLElementIsClick() throws {
        deliver(["bannerId": "story", "version": 1, "format": "html",
                 "html": "<html><body><button onclick=\"void 0\">Buy</button></body></html>",
                 "action": ["type": "copy", "text": "PROMO"]])
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let html = try XCTUnwrap(views(PWInlineHTMLBannerView.self, in: slot).first)
        let pasteboardChanges = UIPasteboard.general.changeCount

        html.beginTap()
        html.handleHit("own")
        spin(1.2)

        XCTAssertEqual(types, ["click"])
        XCTAssertNil(events.first?["elementId"])
        XCTAssertEqual(recorder.clicks, ["story/banner"])
        XCTAssertEqual(UIPasteboard.general.changeCount, pasteboardChanges)
    }

    /// Verifies that a banner without the close object or with it disabled has no close button.
    func testCloseButtonOnlyWhenEnabled() {
        XCTAssertNil(PWInlineParser.banner(from: nativeBanner("b1"), slotId: "s", receivedAt: clock)?.close)
        XCTAssertNil(PWInlineParser.banner(from: nativeBanner("b1", extra: ["close": ["enabled": false]]),
                                           slotId: "s", receivedAt: clock)?.close)
        XCTAssertNil(PWInlineParser.banner(from: nativeBanner("b1", extra: ["close": ["enabled": true, "position": "bottom"]]),
                                           slotId: "s", receivedAt: clock))
    }

    /// Verifies that a banner below the screen is reported as shown only after it stays in view for 0.3 s.
    func testBannerIsShownOnlyAfterScrolledIntoView() {
        deliver(nativeBanner("b1"))
        let (window, scroll, slot) = makeSlotBelowScreen()

        spin(0.5)
        XCTAssertTrue(types.isEmpty)

        scroll.contentOffset = CGPoint(x: 0, y: 900)
        spin(1.0)

        XCTAssertEqual(types, ["show"])
        XCTAssertEqual(recorder.shown, ["home_top=b1"])
        XCTAssertGreaterThan(slot.frame.height, 0)
        XCTAssertNotNil(window)
    }

    /// Verifies that a banner on screen from the start is reported as shown once it stays there for 0.3 s.
    func testBannerOnScreenIsShownAfterThreeTenthsOfASecond() {
        deliver(nativeBanner("b1"))
        let window = makeWindow(with: PushwooshInlineView(slotId: "home_top", manager: manager))

        spin(0.2)
        XCTAssertTrue(types.isEmpty)
        spin(0.25)

        XCTAssertEqual(types, ["show"])
        XCTAssertNotNil(window)
    }

    /// Verifies that an html banner on screen counts as shown only 0.3 s after its document has drawn, not while it
    /// is a placeholder.
    func testHTMLBannerIsShownOnlyOnceItsDocumentHasDrawn() throws {
        deliver(["bannerId": "story", "version": 1, "format": "html",
                 "html": "<html style=\"height:0;overflow:hidden\"><body style=\"margin:0;height:0\"></body></html>"])
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let window = makeWindow(with: slot)
        let html = try XCTUnwrap(views(PWInlineHTMLBannerView.self, in: slot).first)

        spin(0.6)
        XCTAssertTrue(types.isEmpty)

        html.documentHeightChanged(200)
        spin(0.2)
        XCTAssertTrue(types.isEmpty)
        spin(0.3)

        XCTAssertEqual(types, ["show"])
        XCTAssertNotNil(window)
    }

    /// Verifies that a banner scrolled into view for 0.35 s is shown and one in view for 0.25 s is not.
    func testScrolledBannerCountsOnlyThreeTenthsInView() {
        for (inView, expected) in [(0.25, [String]()), (0.35, ["show"])] {
            events = []
            deliver(nativeBanner("b1"))
            let (window, scroll, _) = makeSlotBelowScreen()
            spin(0.5)

            scroll.contentOffset = CGPoint(x: 0, y: 900)
            spin(inView)
            scroll.contentOffset = .zero
            spin(0.5)

            XCTAssertEqual(types, expected, "in view \(inView) s")
            XCTAssertNotNil(window)
        }
    }

    /// Verifies that a control slot stays empty and reports control once its place is on screen.
    func testControlSlotReportsControlWhenItsPlaceIsOnScreen() {
        deliver(["bannerId": "c1", "version": 1, "control": true])
        let (window, scroll, slot) = makeSlotBelowScreen()

        spin(0.5)
        XCTAssertTrue(types.isEmpty)

        scroll.contentOffset = CGPoint(x: 0, y: 900)
        spin(1.0)

        XCTAssertEqual(types, ["control"])
        XCTAssertEqual(slot.frame.height, 0)
        XCTAssertNotNil(window)
    }

    /// Verifies that a banner cropped in width (a carousel page) counts as shown once its whole height is on screen.
    func testBannerCroppedInWidthIsShown() {
        deliver(nativeBanner("b1"))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let carousel = UIScrollView(frame: window.bounds)
        carousel.contentSize = CGSize(width: 1200, height: 800)
        window.addSubview(carousel)
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        slot.translatesAutoresizingMaskIntoConstraints = false
        carousel.addSubview(slot)
        NSLayoutConstraint.activate([
            slot.topAnchor.constraint(equalTo: carousel.contentLayoutGuide.topAnchor, constant: 100),
            slot.leadingAnchor.constraint(equalTo: carousel.contentLayoutGuide.leadingAnchor, constant: 234),
            slot.widthAnchor.constraint(equalToConstant: 390),
        ])
        window.layoutIfNeeded()

        spin(1.0)

        XCTAssertEqual(types, ["show"])
        XCTAssertGreaterThan(slot.frame.height, 0)
    }

    /// Verifies that a banner under a presented screen (a sheet) is not counted until the screen goes away.
    func testBannerUnderPresentedScreenIsNotShown() {
        deliver(nativeBanner("b1"))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let root = PWInlinePresentingController()
        window.rootViewController = root
        window.addSubview(root.view)
        root.view.frame = window.bounds
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        slot.translatesAutoresizingMaskIntoConstraints = false
        root.view.addSubview(slot)
        NSLayoutConstraint.activate([
            slot.topAnchor.constraint(equalTo: root.view.topAnchor, constant: 100),
            slot.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
            slot.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
        ])
        let sheet = UIViewController()
        sheet.loadViewIfNeeded()
        root.presented = sheet
        window.layoutIfNeeded()

        spin(1.0)
        XCTAssertTrue(types.isEmpty)

        root.presented = nil
        spin(1.0)
        XCTAssertEqual(types, ["show"])
    }

    // MARK: - Public API threading

    /// Verifies that calls without a result made from a queue the main thread waits on do not block on it.
    func testCallsWithoutResultDoNotWaitForMainThread() {
        let delegate = PushwooshInlineImplementation.delegate
        let colorScheme = PushwooshInlineImplementation.colorScheme
        let done = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            PushwooshInlineImplementation.trackShown(slotId: "threading_slot", bannerId: "none")
            PushwooshInlineImplementation.trackClick(slotId: "threading_slot", bannerId: "none", elementId: nil)
            PushwooshInlineImplementation.dismiss(slotId: "threading_slot", bannerId: "none")
            PushwooshInlineImplementation.requestSlots([], completion: nil)
            PushwooshInlineImplementation.delegate = delegate
            PushwooshInlineImplementation.colorScheme = colorScheme
            done.signal()
        }

        XCTAssertEqual(done.wait(timeout: .now() + 1), .success)
        spin(0.2)
    }

    private func makeSlotBelowScreen() -> (UIWindow, UIScrollView, PushwooshInlineView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let scroll = UIScrollView(frame: window.bounds)
        scroll.contentSize = CGSize(width: 390, height: 2400)
        window.addSubview(scroll)
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        slot.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(slot)
        NSLayoutConstraint.activate([
            slot.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 1200),
            slot.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            slot.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        window.layoutIfNeeded()
        return (window, scroll, slot)
    }

    private func tap(_ button: UIButton) {
        for case let target as NSObject in button.allTargets {
            button.actions(forTarget: target, forControlEvent: .touchUpInside)?.forEach { target.perform(Selector($0)) }
        }
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func htmlBanner(version: Int) -> [String: Any] {
        ["bannerId": "story", "version": version, "format": "html",
         "html": "<html><body><button onclick=\"void 0\">Go</button></body></html>"]
    }

    private func htmlSlot() throws -> (PushwooshInlineView, PWInlineHTMLBannerView, PWInlineHTMLView) {
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let html = try XCTUnwrap(views(PWInlineHTMLBannerView.self, in: slot).first)
        let content = try XCTUnwrap(views(PWInlineHTMLView.self, in: html).first)
        return (slot, html, content)
    }

    private func makeWindow(with slot: PushwooshInlineView) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        slot.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(slot)
        NSLayoutConstraint.activate([
            slot.topAnchor.constraint(equalTo: window.topAnchor, constant: 100),
            slot.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            slot.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])
        window.layoutIfNeeded()
        return window
    }

    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ([view as? T].compactMap { $0 }) + view.subviews.flatMap { views(type, in: $0) }
    }

    private func button(labelled label: String, in view: UIView) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityLabel == label {
            return button
        }
        return view.subviews.lazy.compactMap { self.button(labelled: label, in: $0) }.first
    }
}
#endif
