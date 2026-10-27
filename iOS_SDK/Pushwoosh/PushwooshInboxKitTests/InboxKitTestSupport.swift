//
//  InboxKitTestSupport.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import UIKit
import XCTest
import PushwooshCore
@testable import PushwooshInboxKit

/// Lightweight `PWInboxMessageProtocol` fake for unit tests.
final class FakeMessage: NSObject, PWInboxMessageProtocol {
    var code: String
    var tabId: String?
    var title: String
    var imageUrl: String?
    var message: String
    var sendDate: Date?
    var type: PWInboxMessageType
    var isRead: Bool
    var isActionPerformed: Bool
    var actionParams: [AnyHashable: Any]?
    var attachmentUrl: String?

    init(
        code: String = UUID().uuidString,
        tabId: String? = nil,
        title: String = "Title",
        message: String = "Body",
        imageUrl: String? = nil,
        sendDate: Date = Date(),
        type: PWInboxMessageType = .plain,
        isRead: Bool = false,
        isActionPerformed: Bool = false
    ) {
        self.code = code
        self.tabId = tabId
        self.title = title
        self.message = message
        self.imageUrl = imageUrl
        self.sendDate = sendDate
        self.type = type
        self.isRead = isRead
        self.isActionPerformed = isActionPerformed
        self.actionParams = nil
        self.attachmentUrl = nil
    }
}

/// Test double swapped in via `PushwooshInboxKitViewController.facade`.
final class TestableInboxFacade: PWInboxFacade {
    enum Outcome {
        case loaded([PWInboxMessageProtocol], Error?)
    }
    var outcome: Outcome = .loaded([], nil)
    var stubbedTabs: PWInboxTabs?
    /// Posts a successful load's messages as `messagesAdded` before the completion, the way `PWInbox` reports a sync.
    var announcesLoadedMessages = false
    private(set) var loadCallCount = 0
    private(set) var tabsCallCount = 0
    private(set) var readCalls: [[PWInboxMessageProtocol]] = []
    private(set) var deleteCalls: [[PWInboxMessageProtocol]] = []
    private(set) var actionCalls: [PWInboxMessageProtocol] = []
    private(set) var reportedActions: [PWInboxMessageProtocol] = []
    private(set) var markAllAsReadCallCount = 0
    private(set) var deleteAllReadCallCount = 0

    override func loadMessages(_ completion: @escaping (InboxLoadResult) -> Void) {
        loadCallCount += 1
        switch outcome {
        case .loaded(let messages, let error):
            if announcesLoadedMessages, error == nil {
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
                    object: nil,
                    userInfo: ["messagesAdded": messages, "messagesDeleted": [], "messagesUpdated": []]
                )
            }
            DispatchQueue.main.async { completion(InboxLoadResult(messages: messages, error: error)) }
        }
    }

    override func tabs() -> PWInboxTabs? {
        tabsCallCount += 1
        return stubbedTabs
    }

    override func read(messages: [PWInboxMessageProtocol]) {
        readCalls.append(messages)
        for case let message as FakeMessage in messages {
            message.isRead = true
        }
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
            object: nil,
            userInfo: ["messagesAdded": [], "messagesDeleted": [], "messagesUpdated": messages]
        )
    }

    override func delete(messages: [PWInboxMessageProtocol]) {
        deleteCalls.append(messages)
    }

    override func performAction(message: PWInboxMessageProtocol) {
        actionCalls.append(message)
    }

    override func markAllAsRead() {
        markAllAsReadCallCount += 1
        // What the bridge does: the storage-owned objects the table holds flip to read in place.
        for case let message as FakeMessage in loadedMessages {
            message.isRead = true
        }
    }

    override func deleteAllRead() {
        deleteAllReadCallCount += 1
    }

    private var loadedMessages: [PWInboxMessageProtocol] {
        switch outcome {
        case .loaded(let messages, _): return messages
        }
    }

    override func reportAction(message: PWInboxMessageProtocol) {
        reportedActions.append(message)
        // What storage does: a message at status Action is already read and acted on.
        // The view's branches key off exactly that, so the double has to do it too.
        if let fake = message as? FakeMessage {
            fake.isRead = true
            fake.isActionPerformed = true
        }
    }
}

/// Spy delegate for ``PushwooshInboxKitDelegate`` callbacks.
final class SpyInboxDelegate: PushwooshInboxKitDelegate {
    var didSelectReturn: Bool = true
    var shouldDeleteReturn: Bool = true
    var didTapButtonReturn: Bool = true
    private(set) var willDisplayCalls: [(IndexPath, PWInboxMessageProtocol)] = []
    private(set) var didSelectCalls: [PWInboxMessageProtocol] = []
    private(set) var shouldDeleteCalls: [PWInboxMessageProtocol] = []
    private(set) var didRefreshCalls: [(Int, Error?)] = []
    private(set) var didDismissCallCount = 0

    func inboxKit(_ vc: PushwooshInboxKitViewController, willDisplay message: PWInboxMessageProtocol, at indexPath: IndexPath) {
        willDisplayCalls.append((indexPath, message))
    }

    func inboxKit(_ vc: PushwooshInboxKitViewController, didSelect message: PWInboxMessageProtocol) -> Bool {
        didSelectCalls.append(message)
        return didSelectReturn
    }

    func inboxKit(_ vc: PushwooshInboxKitViewController, shouldDelete message: PWInboxMessageProtocol) -> Bool {
        shouldDeleteCalls.append(message)
        return shouldDeleteReturn
    }

    func inboxKit(_ vc: PushwooshInboxKitViewController, didRefreshWith messages: [PWInboxMessageProtocol], error: Error?) {
        didRefreshCalls.append((messages.count, error))
    }

    func inboxKit(didDismiss vc: PushwooshInboxKitViewController) {
        didDismissCallCount += 1
    }

    func inboxKit(_ vc: PushwooshInboxKitViewController,
                  didTapButton button: PushwooshInboxButton,
                  onMessage message: PWInboxMessageProtocol) -> Bool {
        didTapButtonReturn
    }
}

/// Run-loop and hosting helpers for the inbox screen tests; the 5 s timeouts leave room for a loaded CI machine.
protocol InboxScreenTesting: XCTestCase {
    var sut: PushwooshInboxKitViewController! { get }
    var window: UIWindow? { get set }
}

extension InboxScreenTesting {
    func loadAndWait() {
        sut.reloadData()
        let exp = expectation(description: "load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sut.tableView.reloadData()
            self.sut.tableView.layoutIfNeeded()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    /// Spins the run loop for one frame, so a load completion or a merge can run.
    func waitAFrame() {
        let exp = expectation(description: "frame")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 5.0)
    }

    /// Spins the run loop past `scheduleInboxRefresh`'s 1.5s debounce window.
    func waitPastRefreshDebounce() {
        let exp = expectation(description: "debounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { exp.fulfill() }
        wait(for: [exp], timeout: 5.0)
    }

    /// Hosts `sut` in a real window so `markDisplayedAsRead` sees it as on-screen.
    func hostInWindow() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.view.layoutIfNeeded()
        self.window = window
    }
}

/// `count` unread messages with descending send dates, so the default transform keeps `m0` on row 0.
func unreadFeed(count: Int, tabId: String? = nil) -> [FakeMessage] {
    (0..<count).map { FakeMessage(code: "m\($0)", tabId: tabId, sendDate: Date(timeIntervalSince1970: 2_000_000 - Double($0))) }
}
