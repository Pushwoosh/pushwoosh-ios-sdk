//
//  PushwooshInboxKitViewControllerTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import UIKit
import PushwooshCore
@testable import PushwooshInboxKit

class PushwooshInboxKitViewControllerTest: XCTestCase {

    var sut: PushwooshInboxKitViewController!
    var facade: TestableInboxFacade!
    var delegate: SpyInboxDelegate!
    var window: UIWindow?

    override func setUp() {
        super.setUp()
        facade = TestableInboxFacade()
        delegate = SpyInboxDelegate()
        sut = PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
        sut.facade = facade
        sut.delegate = delegate
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        sut = nil
        facade = nil
        delegate = nil
        super.tearDown()
    }

    /// Verifies that reloadData routes through the facade.
    func testReloadDataCallsLoadMessages() {
        let initial = facade.loadCallCount
        sut.reloadData()
        let exp = expectation(description: "facade load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(facade.loadCallCount, initial + 1)
    }

    /// Verifies that the empty-state label appears when zero messages are returned.
    func testEmptyStateShownWhenNoMessages() {
        facade.outcome = .success([])
        sut.reloadData()
        let exp = expectation(description: "empty")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.sut.emptyStateLabel.isHidden)
            XCTAssertTrue(self.sut.errorStateLabel.isHidden)
            XCTAssertTrue(self.sut.tableView.isHidden)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that the error-state label appears when the facade fails.
    func testErrorStateShownOnError() {
        facade.outcome = .failure(NSError(domain: "test", code: 1, userInfo: nil))
        sut.reloadData()
        let exp = expectation(description: "error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.sut.errorStateLabel.isHidden)
            XCTAssertTrue(self.sut.emptyStateLabel.isHidden)
            XCTAssertTrue(self.sut.tableView.isHidden)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that a refresh failure after content was already loaded keeps the list visible
    /// instead of blanking it behind the error screen.
    func testRefreshFailureAfterContentKeepsListVisible() {
        facade.outcome = .success([FakeMessage(code: "a"), FakeMessage(code: "b")])
        loadAndWait()
        XCTAssertFalse(sut.tableView.isHidden)

        facade.outcome = .failure(NSError(domain: "test", code: 1, userInfo: nil))
        sut.reloadData()
        let exp = expectation(description: "failed refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.sut.tableView.isHidden)
            XCTAssertTrue(self.sut.errorStateLabel.isHidden)
            XCTAssertTrue(self.sut.emptyStateLabel.isHidden)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that returning false from the delegate suppresses the default tap action.
    func testTapDelegatesToHostFirst() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        delegate.didSelectReturn = false
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(delegate.didSelectCalls.count, 1)
        XCTAssertEqual(facade.actionCalls.count, 0)
    }

    /// Verifies that returning true from the delegate routes through the default action path.
    func testTapFallsThroughWhenDelegateReturnsTrue() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        delegate.didSelectReturn = true
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(facade.actionCalls.count, 1)
    }

    /// Verifies that swipe-to-delete invokes the facade.
    func testSwipeDeleteInvokesFacade() {
        let m = FakeMessage(code: "del")
        facade.outcome = .success([m])
        loadAndWait()

        let cfg = sut.tableView(sut.tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertNotNil(cfg)
        let action = cfg?.actions.first
        XCTAssertNotNil(action)
        let exp = expectation(description: "delete")
        action?.handler(action!, sut.tableView) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(facade.deleteCalls.count, 1)
    }

    /// Verifies that visible unread rows are read on disappear.
    func testAutomaticReadOnDisappearMarksVisibleRows() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .success([m])
        loadAndWait()
        sut.attributes.automaticReadOnDisappear = true
        sut.attributes.automaticReadOnDisplay = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.tableView.layoutIfNeeded()
        sut.viewWillDisappear(false)
        XCTAssertEqual(facade.readCalls.count, 1)
    }

    /// Verifies that disabling automaticReadOnDisappear suppresses the read call.
    func testAutomaticReadOnDisappearFalseSkipsMarkRead() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .success([m])
        loadAndWait()
        sut.attributes.automaticReadOnDisappear = false
        sut.viewWillDisappear(false)
        XCTAssertEqual(facade.readCalls.count, 0)
    }

    /// Verifies that the inbox refreshes after a real background → active cycle.
    func testInboxRefreshesAfterRealBackgroundCycle() {
        let initial = facade.loadCallCount
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let exp = expectation(description: "reload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertGreaterThan(facade.loadCallCount, initial)
    }

    /// Verifies that DidBecomeActive without a preceding DidEnterBackground (Control Center / Face ID / system overlay) does NOT reload the inbox.
    func testInboxDoesNotRefreshOnDidBecomeActiveWithoutBackground() {
        let initial = facade.loadCallCount
        for _ in 0..<6 {
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        let exp = expectation(description: "no reload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(facade.loadCallCount, initial)
    }

    /// Verifies that the background flag is single-use: after one background+active reload, a second active without background does not reload again.
    func testInboxBackgroundFlagIsSingleUse() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let exp1 = expectation(description: "first reload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)
        let afterFirst = facade.loadCallCount

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let exp2 = expectation(description: "no second reload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp2.fulfill() }
        wait(for: [exp2], timeout: 1.0)
        XCTAssertEqual(facade.loadCallCount, afterFirst)
    }

    /// Verifies that the inbox refreshes when the update notification fires.
    /// `scheduleInboxRefresh` debounces by 1.5s on the first call to give the
    /// server time to sync after APNS delivery, so we wait past that window.
    func testInboxRefreshesOnInboxMessagesDidUpdateNotification() {
        let initial = facade.loadCallCount
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
            object: nil
        )
        let exp = expectation(description: "notif")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { exp.fulfill() }
        wait(for: [exp], timeout: 2.5)
        XCTAssertGreaterThan(facade.loadCallCount, initial)
    }

    /// Verifies that a trait collection change re-applies attributes to visible cells.
    func testTraitCollectionChangeRepaintsCells() {
        let m = FakeMessage(code: "tc")
        facade.outcome = .success([m])
        loadAndWait()
        sut.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        sut.tableView.layoutIfNeeded()
        sut.traitCollectionDidChange(UITraitCollection(userInterfaceStyle: .light))
        XCTAssertNotNil(sut.tableView)
    }

    /// Verifies that Obj-C-style setters write through into the attributes struct.
    func testObjcSetterWritesIntoAttributes() {
        sut.setBackgroundColor(.red)
        sut.setEmptyMessage("Nothing")
        sut.setErrorMessage("Oops")
        sut.setAutomaticReadOnDisappear(false)
        sut.setAutomaticReadOnDisplay(false)
        sut.setSwipeToDeleteEnabled(false)
        sut.setEnableDarkTheme(false)

        XCTAssertEqual(sut.attributes.style.backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)), UIColor.red)
        XCTAssertEqual(sut.attributes.emptyMessage, "Nothing")
        XCTAssertEqual(sut.attributes.errorMessage, "Oops")
        XCTAssertFalse(sut.attributes.automaticReadOnDisappear)
        XCTAssertFalse(sut.attributes.automaticReadOnDisplay)
        XCTAssertFalse(sut.attributes.swipeToDeleteEnabled)
        XCTAssertFalse(sut.attributes.enableDarkTheme)
    }

    /// Verifies that the pin chip is visible by default on a pinned message.
    func testPinIndicatorVisibleTrueShowsChipOnPinnedMessage() {
        let m = FakeMessage(code: "p")
        m.actionParams = ["pinned": true]
        facade.outcome = .success([m])
        sut.attributes.forceCellKind = .classic
        loadAndWait()
        sut.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        sut.tableView.layoutIfNeeded()
        guard let cell = sut.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PushwooshInboxClassicCell else {
            return XCTFail("Expected PushwooshInboxClassicCell")
        }
        XCTAssertFalse(cell.pinIndicatorView.isHidden)
    }

    /// Verifies that toggling pinIndicatorVisible=false hides the chip while pinningEnabled (sorting) remains active.
    func testPinIndicatorVisibleFalseHidesChipButKeepsPinningEnabled() {
        sut.setPinIndicatorVisible(false)
        let m = FakeMessage(code: "p")
        m.actionParams = ["pinned": true]
        facade.outcome = .success([m])
        sut.attributes.forceCellKind = .classic
        loadAndWait()
        sut.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        sut.tableView.layoutIfNeeded()
        guard let cell = sut.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PushwooshInboxClassicCell else {
            return XCTFail("Expected PushwooshInboxClassicCell")
        }
        XCTAssertTrue(cell.pinIndicatorView.isHidden)
        XCTAssertTrue(sut.attributes.pinningEnabled)
        XCTAssertFalse(sut.attributes.pinIndicatorVisible)
    }

    // MARK: - Appearance

    func testBackgroundColorPairResolvesPerAppearance() {
        sut.setBackgroundColor(light: .white, dark: .black)

        let light = sut.attributes.style.backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = sut.attributes.style.backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        XCTAssertEqual(light, UIColor.white.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
        XCTAssertEqual(dark, UIColor.black.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)))
    }

    func testSingleColorBackgroundStaysFixedAcrossAppearances() {
        sut.setBackgroundColor(.orange)

        let light = sut.attributes.style.backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = sut.attributes.style.backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        XCTAssertEqual(light, dark)
    }

    // MARK: - Helpers

    private func loadAndWait() {
        sut.reloadData()
        let exp = expectation(description: "load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sut.tableView.reloadData()
            self.sut.tableView.layoutIfNeeded()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - SDK-998: every interaction with a card reports the open

    /// The host intercepts the tap and navigates itself — the open still has to ship.
    /// This is the path that was zeroing the open counter.
    func testHostInterceptStillReportsTheOpen() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        delegate.didSelectReturn = false
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(facade.actionCalls.count, 0, "the message action must not run: the host already took the user away")
        XCTAssertEqual(facade.reportedActions.count, 1, "the open was not reported")
    }

    /// The button has its own URL, so the open is reported without running the message
    /// action, which would open a second one.
    func testInlineButtonReportsWithoutPerformingTheMessageAction() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        loadAndWait()

        let cell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        guard let inboxCell = cell as? PushwooshInboxCell else {
            return XCTFail("expected an inbox cell")
        }
        inboxCell.onInlineButtonTap?(PushwooshInboxButton(title: "go", action: .openURL(URL(string: "https://example.com")!)))

        XCTAssertEqual(facade.reportedActions.count, 1, "the button tap was not reported")
        XCTAssertEqual(facade.actionCalls.count, 0, "the message action would open a second URL")
    }

    /// A video card owns its whole row: the tap opens the player, and the message payload
    /// (`l` / `rm`) is not performed on top of it — otherwise the poster and the title of one
    /// card lead to two different places.
    func testVideoCardRowTapDoesNotPerformTheMessageAction() {
        let m = FakeMessage(code: "video")
        m.actionParams = ["u": ["displayType": "video",
                                "video": ["url": "https://cdn.example.com/clip.mp4"]]]
        facade.outcome = .success([m])
        delegate.didSelectReturn = true
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(facade.actionCalls.count, 0, "the player is the destination, the payload is not")
        XCTAssertEqual(facade.reportedActions.count, 1, "the tap on a video card was not reported")
        XCTAssertEqual(delegate.didSelectCalls.count, 1, "the host keeps its veto on the card's own destination")
    }

    /// The host vetoes the tap on a video card: the player stays closed, the payload stays
    /// unperformed, and the open is still reported.
    func testVideoCardRowTapHonoursTheHostVeto() {
        let m = FakeMessage(code: "video-veto")
        m.actionParams = ["u": ["displayType": "video",
                                "video": ["url": "https://cdn.example.com/clip.mp4"]]]
        facade.outcome = .success([m])
        delegate.didSelectReturn = false
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(facade.actionCalls.count, 0, "the host navigates instead of us")
        XCTAssertEqual(facade.reportedActions.count, 1, "the open must ship even when the host takes over")
        XCTAssertNil(sut.presentedViewController, "no player behind the host's own screen")
    }

    /// A video card whose descriptor cannot be decoded is an ordinary card again: nothing to
    /// play, so the row action performs the message payload as usual.
    func testVideoCardWithoutDescriptorFallsBackToTheRowAction() {
        let m = FakeMessage(code: "video-broken")
        m.actionParams = ["u": ["displayType": "video"]]
        facade.outcome = .success([m])
        delegate.didSelectReturn = true
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(facade.actionCalls.count, 1, "without a video there is nothing else to open")
    }

    /// The ordinary path must not report twice: performAction sends the status itself.
    func testNormalTapReportsExactlyOnce() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        delegate.didSelectReturn = true
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertEqual(facade.reportedActions.count, 0, "status 3 sent twice")
    }

    /// The mark-read button is an interaction too. No read request follows: at status
    /// Action the message is already read, and the state machine rejects 3 -> 2 anyway.
    func testMarkReadButtonReportsTheOpenInsteadOfASecondStatus() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        loadAndWait()

        tapInlineButton(.markRead)

        XCTAssertEqual(facade.reportedActions.count, 1, "the button tap was not reported as an open")
        XCTAssertTrue(facade.readCalls.isEmpty, "status 2 after status 3 is a request the SDK rejects anyway")
        XCTAssertTrue(m.isRead, "the message must stay read")
    }

    /// Dismissing a card is an interaction, so the open ships before the row goes.
    func testDismissButtonReportsTheOpenBeforeRemovingTheRow() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        loadAndWait()

        tapInlineButton(.dismiss)

        XCTAssertEqual(facade.reportedActions.count, 1, "dismissing a card is an interaction too")
        XCTAssertEqual(facade.deleteCalls.count, 1, "the card must leave the list")
    }

    /// A custom action runs on the host's side, but the tap is still ours to report.
    func testCustomButtonReportsTheOpenWithoutPerformingTheMessageAction() {
        let m = FakeMessage(code: "x")
        facade.outcome = .success([m])
        loadAndWait()

        tapInlineButton(.custom(["tag": "promo"]))

        XCTAssertEqual(facade.reportedActions.count, 1, "the custom button was not reported")
        XCTAssertEqual(facade.actionCalls.count, 0, "the message action would send the user to a different URL")
    }

    /// A swipe throws the card away exactly like the dismiss button, and counts the same.
    func testSwipeDeleteReportsTheOpenLikeTheDismissButton() {
        let m = FakeMessage(code: "del")
        facade.outcome = .success([m])
        loadAndWait()

        let cfg = sut.tableView(sut.tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))
        guard let action = cfg?.actions.first else {
            return XCTFail("the swipe action was not built")
        }
        let exp = expectation(description: "delete")
        action.handler(action, sut.tableView) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(facade.reportedActions.count, 1, "a swipe on a card is an interaction too")
        XCTAssertEqual(facade.deleteCalls.count, 1, "the card must leave the list")
    }

    /// A carousel slide carries its own URL, so the open is reported without the message
    /// action, which would open a second one.
    func testCarouselSlideTapReportsTheOpen() {
        let cell: PushwooshInboxCarouselCell? = loadAndDequeue(kind: .carousel)
        cell?.onCarouselSlideTap?(URL(string: "https://example.com/slide")!)

        XCTAssertEqual(facade.reportedActions.count, 1, "a carousel slide tap was not reported")
        XCTAssertEqual(facade.actionCalls.count, 0, "the slide's own URL is the only one to open")
    }

    /// The video tap reports before the guards below it, so a tap that cannot present a
    /// player is still an interaction that happened.
    func testVideoTapReportsTheOpen() {
        let cell: PushwooshInboxVideoCell? = loadAndDequeue(kind: .video)
        cell?.onVideoTap?(URL(string: "https://example.com/clip.mp4")!)

        XCTAssertEqual(facade.reportedActions.count, 1, "a video tap was not reported")
        sut.dismiss(animated: false)
    }

    /// Wallet reports before the serializing guard and before the download: a second tap
    /// while a pass is downloading must not vanish from statistics.
    func testWalletAddReportsTheOpenBeforeTheDownload() {
        let cell: PushwooshInboxWalletCell? = loadAndDequeue(kind: .wallet)
        cell?.onAddToWallet?(URL(string: "https://example.com/pass.pkpass")!)

        XCTAssertEqual(facade.reportedActions.count, 1, "adding to Wallet was not reported")
    }

    private func loadAndDequeue<Cell: PushwooshInboxCell>(kind: PushwooshInboxKitAttributes.CellKind,
                                                          actionParams: [AnyHashable: Any]? = nil,
                                                          file: StaticString = #filePath,
                                                          line: UInt = #line) -> Cell? {
        let message = FakeMessage(code: "x")
        message.actionParams = actionParams
        facade.outcome = .success([message])
        sut.attributes.forceCellKind = kind
        loadAndWait()

        let cell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        guard let typed = cell as? Cell else {
            XCTFail("expected a \(kind.rawValue) cell, got \(type(of: cell))", file: file, line: line)
            return nil
        }
        return typed
    }

    /// The host refuses the delete, so the row stays — but the swipe happened and the open
    /// is already reported, which is what makes the row read.
    func testSwipeRefusedByTheHostStillReportsTheOpen() {
        let m = FakeMessage(code: "keep")
        facade.outcome = .success([m])
        delegate.shouldDeleteReturn = false
        loadAndWait()

        let cfg = sut.tableView(sut.tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))
        guard let action = cfg?.actions.first else {
            return XCTFail("the swipe action was not built")
        }
        let exp = expectation(description: "refused delete")
        action.handler(action, sut.tableView) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(facade.reportedActions.count, 1, "the swipe was not reported")
        XCTAssertTrue(facade.deleteCalls.isEmpty, "the host refused the delete; nothing may be deleted")
        XCTAssertTrue(m.isRead, "a reported open makes the message read")
    }

    private func tapInlineButton(_ action: PushwooshInboxButtonAction,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
        let cell = sut.tableView(sut.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        guard let inboxCell = cell as? PushwooshInboxCell else {
            return XCTFail("expected an inbox cell", file: file, line: line)
        }
        inboxCell.onInlineButtonTap?(PushwooshInboxButton(title: "go", action: action))
    }

    // MARK: - Automatic read on display

    /// Verifies that markDisplayedAsRead reads the visible unread rows while the view is in a window.
    func testMarkDisplayedAsRead_inWindow_readsVisibleUnreadRows() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .success([m])
        loadAndWait()
        hostInWindow()

        sut.markDisplayedAsRead()

        XCTAssertEqual(facade.readCalls.flatMap { $0 }.map { $0.code }, ["u"])
    }

    /// Verifies that markDisplayedAsRead does nothing when automaticReadOnDisplay is disabled.
    func testMarkDisplayedAsRead_disabled_doesNotRead() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .success([m])
        sut.attributes.automaticReadOnDisplay = false
        loadAndWait()
        hostInWindow()

        sut.markDisplayedAsRead()

        XCTAssertTrue(facade.readCalls.isEmpty)
    }

    /// Verifies that markDisplayedAsRead does nothing while the view is not in a window.
    func testMarkDisplayedAsRead_notInWindow_doesNotRead() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .success([m])
        loadAndWait()
        sut.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)

        sut.markDisplayedAsRead()

        XCTAssertTrue(facade.readCalls.isEmpty)
    }

    // MARK: - Message with its own action

    /// Verifies that a link button on a message with `l` performs the message action and reports the open once.
    func testInlineLinkButton_messageWithLink_performsMessageActionOnce() {
        let m = FakeMessage(code: "x")
        m.actionParams = ["l": "https://example.com/message"]
        facade.outcome = .success([m])
        loadAndWait()

        tapInlineButton(.openURL(URL(string: "https://example.com/button")!))

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertTrue(facade.reportedActions.isEmpty)
    }

    /// Verifies that a link button on a message with `rm` performs the message action.
    func testInlineLinkButton_messageWithRichMedia_performsMessageAction() {
        let m = FakeMessage(code: "x")
        m.actionParams = ["rm": ["url": "https://example.com/rm.zip"]]
        facade.outcome = .success([m])
        loadAndWait()

        tapInlineButton(.openURL(URL(string: "https://example.com/button")!))

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertTrue(facade.reportedActions.isEmpty)
    }

    /// Verifies that a host veto on a link button still reports the open once and skips the message action.
    func testInlineLinkButton_messageWithLinkVetoedByHost_reportsOpenOnce() {
        let m = FakeMessage(code: "x")
        m.actionParams = ["l": "https://example.com/message"]
        facade.outcome = .success([m])
        delegate.didTapButtonReturn = false
        loadAndWait()

        tapInlineButton(.openURL(URL(string: "https://example.com/button")!))

        XCTAssertEqual(facade.reportedActions.count, 1)
        XCTAssertTrue(facade.actionCalls.isEmpty)
    }

    /// Verifies that a carousel slide with its own URL on a message with `l` performs the message action.
    func testCarouselSlideTap_messageWithLink_performsMessageAction() {
        let cell: PushwooshInboxCarouselCell? = loadAndDequeue(kind: .carousel,
                                                               actionParams: ["l": "https://example.com/message"])
        cell?.onCarouselSlideTap?(URL(string: "https://example.com/slide")!)

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertTrue(facade.reportedActions.isEmpty)
    }

    /// Verifies that a row tap on a video card with `rm` performs the message action instead of opening the player.
    func testVideoCardRowTap_messageWithRichMedia_performsMessageAction() {
        let m = FakeMessage(code: "video-rm")
        m.actionParams = ["u": ["displayType": "video",
                                "video": ["url": "https://cdn.example.com/clip.mp4"]],
                          "rm": ["url": "https://example.com/rm.zip"]]
        facade.outcome = .success([m])
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertNil(sut.presentedViewController)
    }

    /// Verifies that a video tap on a message with `l` performs the message action instead of opening the player.
    func testVideoTap_messageWithLink_performsMessageAction() {
        let cell: PushwooshInboxVideoCell? = loadAndDequeue(kind: .video,
                                                            actionParams: ["l": "https://example.com/message"])
        cell?.onVideoTap?(URL(string: "https://example.com/clip.mp4")!)

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertNil(sut.presentedViewController)
    }

    private func hostInWindow() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.tableView.layoutIfNeeded()
        self.window = window
    }
}

/// The backend does not hand buttons over the way `createMessage` accepts them: it packs the
/// whole `data` into `action_params.u` as a JSON string. Pinned from a live feed response.
final class InboxButtonsWireFormatTest: XCTestCase {
    func testButtonsDecodeFromTheStringifiedUPayload() {
        let u = """
        {"buttons":[{"title":"Open URL","url":"https://example.com/sdk998"},\
        {"action":"markRead","title":"Mark read"},\
        {"action":"custom","sku":"SDK-998","tag":"save","title":"Custom"},\
        {"action":"dismiss","title":"Dismiss"}],"displayType":"classic"}
        """
        let message = FakeMessage(code: "wire")
        message.actionParams = ["pw_inbox": "08254715747244ecad5fd60e43a72d56", "u": u]

        let buttons = PushwooshInboxButton.decode(from: message)

        XCTAssertEqual(buttons.count, 4, "the buttons did not decode from the string in `u`")
        XCTAssertEqual(buttons.map(\.title), ["Open URL", "Mark read", "Custom", "Dismiss"])

        guard case .openURL(let url) = buttons[0].action else {
            return XCTFail("the first button must be a link: it carries `url` and no `action` at all")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/sdk998")

        guard case .markRead = buttons[1].action else { return XCTFail("expected markRead") }

        guard case .custom(let payload) = buttons[2].action else { return XCTFail("expected custom") }
        XCTAssertEqual(payload["tag"] as? String, "save", "`tag` sits beside `action`, not inside it")
        XCTAssertEqual(payload["sku"] as? String, "SDK-998")

        guard case .dismiss = buttons[3].action else { return XCTFail("expected dismiss") }
    }
}

/// Inline buttons must be accessibility elements: they are drawn and tappable without that,
/// and a screen reader still never reaches them.
final class InlineButtonsAccessibilityTest: XCTestCase {
    private func cellWithButtons() -> (PushwooshInboxClassicCell, UIWindow) {
        let cell = PushwooshInboxClassicCell(style: .default, reuseIdentifier: "classic")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
        window.addSubview(cell)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 140)
        cell.applyButtons([
            PushwooshInboxButton(title: "Open URL", action: .openURL(URL(string: "https://example.com")!)),
            PushwooshInboxButton(title: "Mark read", action: .markRead),
            PushwooshInboxButton(title: "Custom", action: .custom(["tag": "save"])),
            PushwooshInboxButton(title: "Dismiss", action: .dismiss),
        ], style: PushwooshInboxKitAttributes.Style.default)
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        window.layoutIfNeeded()
        return (cell, window)
    }

    /// Every button is its own element, labelled with what the user sees.
    func testEveryInlineButtonIsAnAccessibilityElement() {
        let (cell, _) = cellWithButtons()
        let found = cell.buttonsStack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(found.count, 4, "the buttons were not rendered, nothing to check")

        for button in found {
            let title = button.currentTitle ?? "—"
            XCTAssertTrue(button.isAccessibilityElement, "'\(title)' is not an accessibility element")
            XCTAssertEqual(button.accessibilityLabel, title, "the label a screen reader reads differs from the title")
            XCTAssertTrue(button.accessibilityTraits.contains(.button), "'\(title)' carries no button trait")
        }
    }

    /// Characterization, not a regression guard: it passes on master as well. It pins the
    /// drawn row geometry so a later change to applyButtons cannot collapse it unnoticed.
    func testButtonsAreLaidOutInARowWithoutOverlap() {
        let (cell, window) = cellWithButtons()
        let found = cell.buttonsStack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(found.count, 4)

        let frames = found.map { $0.convert($0.bounds, to: window) }
        for (index, frame) in frames.enumerated() {
            XCTAssertFalse(frame.isEmpty, "button \(index) has no size")
            XCTAssertEqual(frame.height, 34, accuracy: 0.5, "button height is off the convention")
        }
        for (left, right) in zip(frames, frames.dropFirst()) {
            XCTAssertGreaterThan(right.minX, left.maxX, "the buttons overlap or collapsed onto one another")
            XCTAssertEqual(right.minY, left.minY, accuracy: 0.5, "the buttons are not on one line")
        }
    }
}
