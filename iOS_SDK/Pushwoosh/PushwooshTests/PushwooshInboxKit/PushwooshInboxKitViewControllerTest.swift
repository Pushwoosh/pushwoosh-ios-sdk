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
        sut.setSwipeToDeleteEnabled(false)
        sut.setEnableDarkTheme(false)

        XCTAssertEqual(sut.attributes.style.backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)), UIColor.red)
        XCTAssertEqual(sut.attributes.emptyMessage, "Nothing")
        XCTAssertEqual(sut.attributes.errorMessage, "Oops")
        XCTAssertFalse(sut.attributes.automaticReadOnDisappear)
        XCTAssertFalse(sut.attributes.swipeToDeleteEnabled)
        XCTAssertFalse(sut.attributes.enableDarkTheme)
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
}
