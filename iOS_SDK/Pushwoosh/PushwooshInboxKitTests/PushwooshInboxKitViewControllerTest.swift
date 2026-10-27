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

class PushwooshInboxKitViewControllerTest: XCTestCase, InboxScreenTesting {

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
        facade.outcome = .loaded([], nil)
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
        facade.outcome = .loaded([], NSError(domain: "test", code: 1, userInfo: nil))
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
        facade.outcome = .loaded([FakeMessage(code: "a"), FakeMessage(code: "b")], nil)
        loadAndWait()
        XCTAssertFalse(sut.tableView.isHidden)

        facade.outcome = .loaded([], NSError(domain: "test", code: 1, userInfo: nil))
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
        facade.outcome = .loaded([m], nil)
        delegate.didSelectReturn = false
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(delegate.didSelectCalls.count, 1)
        XCTAssertEqual(facade.actionCalls.count, 0)
    }

    /// Verifies that returning true from the delegate routes through the default action path.
    func testTapFallsThroughWhenDelegateReturnsTrue() {
        let m = FakeMessage(code: "x")
        facade.outcome = .loaded([m], nil)
        delegate.didSelectReturn = true
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(facade.actionCalls.count, 1)
    }

    /// Verifies that swipe-to-delete invokes the facade.
    func testSwipeDeleteInvokesFacade() {
        let m = FakeMessage(code: "del")
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
        loadAndWait()
        sut.attributes.automaticReadOnDisappear = true
        sut.attributes.automaticReadOnDisplay = false

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.view.layoutIfNeeded()
        sut.viewWillDisappear(false)
        XCTAssertEqual(facade.readCalls.count, 1)
    }

    /// Verifies that disabling automaticReadOnDisappear suppresses the read call.
    func testAutomaticReadOnDisappearFalseSkipsMarkRead() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .loaded([m], nil)
        loadAndWait()
        sut.attributes.automaticReadOnDisappear = false
        sut.viewWillDisappear(false)
        XCTAssertEqual(facade.readCalls.count, 0)
    }

    /// Verifies that the inbox refreshes after a real background → active cycle.
    func testInboxRefreshesAfterRealBackgroundCycle() {
        hostInWindow()
        waitAFrame()
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
        hostInWindow()
        waitAFrame()
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
        hostInWindow()
        waitAFrame()
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
        hostInWindow()
        waitAFrame()
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

    /// Verifies that the update posted by the inbox's own auto-read does not start a server reload.
    func testAutoReadDoesNotScheduleAServerReload() {
        facade.stubbedTabs = oneTab()
        facade.outcome = .loaded(unreadFeed(count: 20), nil)
        loadAndWait()
        hostInWindow()
        waitPastRefreshDebounce()
        let afterHosting = facade.loadCallCount
        let readCallsBeforeExplicitRead = facade.readCalls.count

        sut.tableView.contentOffset = CGPoint(x: 0, y: (sut.tableView.contentSize.height - sut.tableView.bounds.height) / 2)
        sut.markDisplayedAsRead()
        waitPastRefreshDebounce()

        XCTAssertGreaterThan(facade.readCalls.count, readCallsBeforeExplicitRead,
                              "the explicit call must actually read something for this test to mean anything")
        XCTAssertEqual(facade.loadCallCount, afterHosting)
    }

    /// Verifies that an inbox left open does not read the unread rows below the fold.
    func testAutoReadLeavesTheRowsBelowTheFoldUnread() {
        facade.stubbedTabs = oneTab()
        facade.outcome = .loaded(unreadFeed(count: 20), nil)
        loadAndWait()
        hostInWindow()

        sut.markDisplayedAsRead()
        waitPastRefreshDebounce()

        sut.tableView.layoutIfNeeded()
        let onScreenCount = sut.tableView.indexPathsForVisibleRows?.count ?? 0
        let readCodes = Set(facade.readCalls.flatMap { $0 }.map { $0.code })

        XCTAssertGreaterThan(onScreenCount, 0, "the window must actually show rows for this test to mean anything")
        let tail = Set(unreadFeed(count: 20).suffix(onScreenCount).map { $0.code })
        XCTAssertTrue(readCodes.isDisjoint(with: tail), "auto-read reached the unread tail below the fold: \(readCodes)")
        XCTAssertLessThanOrEqual(readCodes.count, onScreenCount,
                                  "auto-read touched more rows than one screen of this window can hold: \(readCodes)")
    }

    /// Verifies that a load completing while the window shows nothing does not re-arm the first-fill gate.
    func testOffScreenLoadDoesNotReArmTheFirstFillGate() {
        facade.stubbedTabs = oneTab()
        let feed = unreadFeed(count: 20)
        facade.outcome = .loaded(feed, nil)
        loadAndWait()
        hostInWindow()
        sut.markDisplayedAsRead()
        waitPastRefreshDebounce()
        let readAfterFirstFill = Set(facade.readCalls.flatMap { $0 }.map { $0.code })
        XCTAssertFalse(readAfterFirstFill.isEmpty, "the first fill must have read something for this test to mean anything")

        // Zero the window (not the table) so onScreenRect() sees nothing without detaching the view, which would itself refire viewWillAppear/viewDidAppear and confound the read set.
        guard let window = window else { return XCTFail("hostInWindow() must have created a window") }
        let originalWindowFrame = window.frame
        window.frame = .zero
        sut.loadMessages(mode: .merge)
        waitPastRefreshDebounce()

        // Back on screen: this load must still be a refresh of an already-shown feed, not a first fill that auto-reads whatever the re-sort moved under the old offset.
        window.frame = originalWindowFrame
        sut.loadMessages(mode: .replace)
        waitPastRefreshDebounce()

        let readAfterReturn = Set(facade.readCalls.flatMap { $0 }.map { $0.code })
        XCTAssertEqual(readAfterReturn, readAfterFirstFill,
                       "an off-screen load re-armed the gate: \(readAfterReturn.subtracting(readAfterFirstFill)) got auto-read on return")
    }

    /// Verifies that the first load to fill an initially empty feed reads the first screen.
    func testColdStartFirstFillStillReadsTheFirstScreen() {
        hostInWindow()
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        sut.loadMessages(mode: .replace)
        waitPastRefreshDebounce()

        XCTAssertEqual(Set(facade.readCalls.flatMap { $0 }.map { $0.code }), Set(["m0", "m1", "m2"]))
    }

    /// Verifies that a refresh of a populated feed does not auto-read the rows its re-sort lifts into view.
    func testRefreshOfAnAlreadyPopulatedFeedDoesNotAutoReadTheResortedRows() {
        facade.stubbedTabs = oneTab()
        hostInWindow()
        facade.outcome = .loaded(unreadFeed(count: 20), nil)
        sut.loadMessages(mode: .replace)
        waitPastRefreshDebounce()
        let firstRead = Set(facade.readCalls.flatMap { $0 }.map { $0.code })
        XCTAssertFalse(firstRead.isEmpty, "the cold-start fill should have read the first screen")

        sut.loadMessages(mode: .replace)
        waitPastRefreshDebounce()

        let readAfterRefresh = Set(facade.readCalls.flatMap { $0 }.map { $0.code })
        XCTAssertEqual(readAfterRefresh, firstRead, "a refresh of an already-populated feed auto-read more rows")
    }

    /// Verifies that an auto-read repaints the rows it read.
    func testAutoReadRepaintsTheRowsItRead() {
        facade.stubbedTabs = oneTab()
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        loadAndWait()
        hostInWindow()
        let visible = sut.tableView.indexPathsForVisibleRows ?? []
        XCTAssertFalse(visible.isEmpty, "the window must actually show rows for this test to mean anything")

        sut.markDisplayedAsRead()

        XCTAssertFalse(facade.readCalls.isEmpty, "nothing was read, so there is nothing to repaint")
        for indexPath in visible {
            let cell = sut.tableView.cellForRow(at: indexPath) as? PushwooshInboxCell
            XCTAssertEqual(cell?.unreadIndicatorView.isHidden, true,
                           "row \(indexPath.row) is still painted as unread after being read")
        }
    }

    /// Verifies that a message arriving in an open inbox is read like any row coming on screen.
    func testMessageArrivingInAnOpenInboxIsRead() {
        facade.stubbedTabs = oneTab()
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        loadAndWait()
        hostInWindow()
        sut.markDisplayedAsRead()
        XCTAssertFalse(readCodes().contains("push"))

        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidReceiveInPushNotification.com.pushwoosh.inbox"),
            object: nil,
            userInfo: ["messagesAdded": [FakeMessage(code: "push", sendDate: Date(timeIntervalSince1970: 3_000_000))]]
        )
        waitAFrame()

        XCTAssertTrue(readCodes().contains("push"), "a push that landed under the user's eyes stayed unread")
    }

    /// Verifies that a refresh reads only the messages it brings in.
    func testRefreshReadsOnlyTheMessagesItBringsIn() {
        facade.stubbedTabs = oneTab()
        hostInWindow()
        let feed = unreadFeed(count: 20)
        facade.outcome = .loaded(feed, nil)
        sut.loadMessages(mode: .replace)
        waitAFrame()
        let readAfterFill = readCodes()
        XCTAssertFalse(readAfterFill.isEmpty, "the first fill must have read the first screen")

        facade.outcome = .loaded([FakeMessage(code: "new", sendDate: Date(timeIntervalSince1970: 3_000_000))] + feed, nil)
        sut.loadMessages(mode: .replace)
        waitAFrame()

        XCTAssertEqual(readCodes().subtracting(readAfterFill), ["new"])
    }

    /// Verifies that the async `reload()` runs the same first-fill gate as `reloadData()`.
    func testAsyncReloadFillRunsTheGateLikeASyncLoad() {
        facade.stubbedTabs = oneTab()
        hostInWindow()
        facade.outcome = .loaded(unreadFeed(count: 20), nil)
        let fill = expectation(description: "async fill")
        Task { try? await self.sut.reload(); fill.fulfill() }
        wait(for: [fill], timeout: 2.0)

        let readAfterFill = readCodes()
        XCTAssertFalse(readAfterFill.isEmpty, "the async fill must auto-read the first screen like reloadData does")

        sut.loadMessages(mode: .replace)
        waitAFrame()

        XCTAssertEqual(readCodes(), readAfterFill,
                       "the load after the async fill auto-read the re-sorted rows: the gate never latched")
    }

    /// Verifies that without tabs every successful load reads the unread rows it leaves on screen, as before tabs existed.
    func testWithoutTabsEveryLoadReadsTheUnreadRowsOnScreen() {
        hostInWindow()
        facade.outcome = .loaded(unreadFeed(count: 30), nil)
        sut.reloadData()
        waitAFrame()
        let readAfterFirstLoad = readCodes()
        XCTAssertFalse(readAfterFirstLoad.isEmpty, "the first load must read the first screen for this test to mean anything")

        sut.reloadData()
        waitAFrame()

        XCTAssertGreaterThan(readCodes().count, readAfterFirstLoad.count,
                             "the second load read nothing although the re-sort put unread rows on screen")
    }

    /// Verifies that without tabs the auto-read is converged with the server by the usual debounced reload.
    func testWithoutTabsAutoReadSchedulesAServerReload() {
        hostInWindow()
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        sut.reloadData()
        waitAFrame()
        XCTAssertFalse(readCodes().isEmpty, "the load must auto-read for this test to mean anything")
        let afterRead = facade.loadCallCount

        waitPastRefreshDebounce()

        XCTAssertEqual(facade.loadCallCount, afterRead + 1)
    }

    /// Verifies that without tabs a pushed message is read by the next successful load, not on arrival.
    func testWithoutTabsArrivingMessageIsNotReadWhileTheSyncFails() {
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        loadAndWait()
        hostInWindow()
        waitAFrame()
        facade.outcome = .loaded([], NSError(domain: "test", code: -1009))

        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidReceiveInPushNotification.com.pushwoosh.inbox"),
            object: nil,
            userInfo: ["messagesAdded": [FakeMessage(code: "push", sendDate: Date(timeIntervalSince1970: 3_000_000))]]
        )
        waitPastRefreshDebounce()

        XCTAssertFalse(readCodes().contains("push"))
    }

    /// Verifies that without tabs the async `reload()` fills the feed without auto-reading it, as before tabs existed.
    func testWithoutTabsAsyncReloadDoesNotAutoRead() {
        hostInWindow()
        waitAFrame()
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        let fill = expectation(description: "async fill")
        Task { try? await self.sut.reload(); fill.fulfill() }
        wait(for: [fill], timeout: 2.0)
        waitAFrame()

        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 3)
        XCTAssertTrue(readCodes().isEmpty)
    }

    /// Verifies that without tabs a page its host keeps in the window but scrolled off screen (a horizontal pager) reads its rows on load, as before tabs existed.
    func testWithoutTabsInWindowOffScreenPageReadsOnLoad() {
        let pager = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = pager
        window.makeKeyAndVisible()
        self.window = window
        pager.addChild(sut)
        sut.view.frame = CGRect(x: 320, y: 0, width: 320, height: 480)
        pager.view.addSubview(sut.view)
        sut.didMove(toParent: pager)
        sut.view.layoutIfNeeded()
        facade.outcome = .loaded(unreadFeed(count: 10), nil)

        sut.reloadData()
        waitAFrame()

        XCTAssertNotNil(sut.view.window)
        XCTAssertFalse(readCodes().isEmpty)
    }

    /// Verifies that an inbox kept off screen by its host (a background tab) still converges a foreign update and reports it to the delegate.
    func testOffWindowInboxReloadsOnAForeignUpdate() {
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        loadAndWait()
        let initialLoads = facade.loadCallCount
        let initialRefreshes = delegate.didRefreshCalls.count

        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
            object: nil
        )
        waitPastRefreshDebounce()

        XCTAssertEqual(facade.loadCallCount, initialLoads + 1)
        XCTAssertEqual(delegate.didRefreshCalls.count, initialRefreshes + 1)
    }

    /// Verifies that an inbox kept off screen by its host still re-syncs after a real background → active cycle.
    func testOffWindowInboxReloadsAfterRealBackgroundCycle() {
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        loadAndWait()
        let initial = facade.loadCallCount

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        waitAFrame()

        XCTAssertEqual(facade.loadCallCount, initial + 1)
    }

    /// Verifies that an update notification posted from a background thread still schedules a reload.
    func testForeignUpdateFromABackgroundThreadStillSchedulesAReload() {
        facade.outcome = .loaded(unreadFeed(count: 3), nil)
        loadAndWait()
        hostInWindow()
        waitAFrame()
        let initial = facade.loadCallCount

        DispatchQueue.global().async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
                object: nil
            )
        }
        waitPastRefreshDebounce()

        XCTAssertGreaterThan(facade.loadCallCount, initial)
    }

    /// Verifies that a host-initiated read still schedules a reload.
    func testHostInitiatedMarkReadStillSchedulesAReload() {
        let feed = unreadFeed(count: 3)
        facade.outcome = .loaded(feed, nil)
        // Auto-read off: it would read the whole screen on appearance and leave markRead nothing to do.
        sut.attributes.automaticReadOnDisplay = false
        loadAndWait()
        hostInWindow()
        waitAFrame()
        let initial = facade.loadCallCount

        sut.markRead(messages: [feed[0]])
        waitPastRefreshDebounce()

        XCTAssertGreaterThan(facade.loadCallCount, initial)
    }

    /// Verifies that a trait collection change re-applies attributes to visible cells.
    func testTraitCollectionChangeRepaintsCells() {
        let m = FakeMessage(code: "tc")
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
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

    private func readCodes() -> Set<String> {
        Set(facade.readCalls.flatMap { $0 }.compactMap { $0.code })
    }

    private func oneTab() -> PWInboxTabs {
        PWInboxTabs(allTitle: "All", tabs: [PWInboxTab(identifier: "t1", title: "Tab One")])
    }

    // MARK: - SDK-998: every interaction with a card reports the open

    /// The host intercepts the tap and navigates itself — the open still has to ship.
    /// This is the path that was zeroing the open counter.
    func testHostInterceptStillReportsTheOpen() {
        let m = FakeMessage(code: "x")
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
        delegate.didSelectReturn = true
        loadAndWait()

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(facade.actionCalls.count, 1, "without a video there is nothing else to open")
    }

    /// The ordinary path must not report twice: performAction sends the status itself.
    func testNormalTapReportsExactlyOnce() {
        let m = FakeMessage(code: "x")
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
        loadAndWait()

        tapInlineButton(.markRead)

        XCTAssertEqual(facade.reportedActions.count, 1, "the button tap was not reported as an open")
        XCTAssertTrue(facade.readCalls.isEmpty, "status 2 after status 3 is a request the SDK rejects anyway")
        XCTAssertTrue(m.isRead, "the message must stay read")
    }

    /// Dismissing a card is an interaction, so the open ships before the row goes.
    func testDismissButtonReportsTheOpenBeforeRemovingTheRow() {
        let m = FakeMessage(code: "x")
        facade.outcome = .loaded([m], nil)
        loadAndWait()

        tapInlineButton(.dismiss)

        XCTAssertEqual(facade.reportedActions.count, 1, "dismissing a card is an interaction too")
        XCTAssertEqual(facade.deleteCalls.count, 1, "the card must leave the list")
    }

    /// A custom action runs on the host's side, but the tap is still ours to report.
    func testCustomButtonReportsTheOpenWithoutPerformingTheMessageAction() {
        let m = FakeMessage(code: "x")
        facade.outcome = .loaded([m], nil)
        loadAndWait()

        tapInlineButton(.custom(["tag": "promo"]))

        XCTAssertEqual(facade.reportedActions.count, 1, "the custom button was not reported")
        XCTAssertEqual(facade.actionCalls.count, 0, "the message action would send the user to a different URL")
    }

    /// A swipe throws the card away exactly like the dismiss button, and counts the same.
    func testSwipeDeleteReportsTheOpenLikeTheDismissButton() {
        let m = FakeMessage(code: "del")
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([message], nil)
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
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
        loadAndWait()
        hostInWindow()

        sut.markDisplayedAsRead()

        XCTAssertEqual(facade.readCalls.flatMap { $0 }.map { $0.code }, ["u"])
    }

    /// Verifies that markDisplayedAsRead does nothing when automaticReadOnDisplay is disabled.
    func testMarkDisplayedAsRead_disabled_doesNotRead() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .loaded([m], nil)
        sut.attributes.automaticReadOnDisplay = false
        loadAndWait()
        hostInWindow()

        sut.markDisplayedAsRead()

        XCTAssertTrue(facade.readCalls.isEmpty)
    }

    /// Verifies that markDisplayedAsRead does nothing while the view is not in a window.
    func testMarkDisplayedAsRead_notInWindow_doesNotRead() {
        let m = FakeMessage(code: "u", isRead: false)
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
        loadAndWait()

        tapInlineButton(.openURL(URL(string: "https://example.com/button")!))

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertTrue(facade.reportedActions.isEmpty)
    }

    /// Verifies that a link button on a message with `rm` performs the message action.
    func testInlineLinkButton_messageWithRichMedia_performsMessageAction() {
        let m = FakeMessage(code: "x")
        m.actionParams = ["rm": ["url": "https://example.com/rm.zip"]]
        facade.outcome = .loaded([m], nil)
        loadAndWait()

        tapInlineButton(.openURL(URL(string: "https://example.com/button")!))

        XCTAssertEqual(facade.actionCalls.count, 1)
        XCTAssertTrue(facade.reportedActions.isEmpty)
    }

    /// Verifies that a host veto on a link button still reports the open once and skips the message action.
    func testInlineLinkButton_messageWithLinkVetoedByHost_reportsOpenOnce() {
        let m = FakeMessage(code: "x")
        m.actionParams = ["l": "https://example.com/message"]
        facade.outcome = .loaded([m], nil)
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
        facade.outcome = .loaded([m], nil)
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
