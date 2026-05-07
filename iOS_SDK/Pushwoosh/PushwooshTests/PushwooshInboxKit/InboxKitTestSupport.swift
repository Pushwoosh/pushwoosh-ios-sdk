//
//  InboxKitTestSupport.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
@testable import PushwooshInboxKit

/// Lightweight `PWInboxMessageProtocol` fake for unit tests.
final class FakeMessage: NSObject, PWInboxMessageProtocol {
    var code: String
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
        title: String = "Title",
        message: String = "Body",
        imageUrl: String? = nil,
        sendDate: Date = Date(),
        type: PWInboxMessageType = .plain,
        isRead: Bool = false,
        isActionPerformed: Bool = false
    ) {
        self.code = code
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
        case success([PWInboxMessageProtocol])
        case failure(Error)
    }
    var outcome: Outcome = .success([])
    private(set) var loadCallCount = 0
    private(set) var readCalls: [[PWInboxMessageProtocol]] = []
    private(set) var deleteCalls: [[PWInboxMessageProtocol]] = []
    private(set) var actionCalls: [PWInboxMessageProtocol] = []

    override func loadMessages(_ completion: @escaping (Result<[PWInboxMessageProtocol], Error>) -> Void) {
        loadCallCount += 1
        switch outcome {
        case .success(let messages):
            DispatchQueue.main.async { completion(.success(messages)) }
        case .failure(let error):
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }

    override func read(messages: [PWInboxMessageProtocol]) {
        readCalls.append(messages)
    }

    override func delete(messages: [PWInboxMessageProtocol]) {
        deleteCalls.append(messages)
    }

    override func performAction(message: PWInboxMessageProtocol) {
        actionCalls.append(message)
    }
}

/// Spy delegate for ``PushwooshInboxKitDelegate`` callbacks.
final class SpyInboxDelegate: PushwooshInboxKitDelegate {
    var didSelectReturn: Bool = true
    var shouldDeleteReturn: Bool = true
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
}
