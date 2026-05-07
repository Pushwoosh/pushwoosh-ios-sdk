//
//  InboxDataSource.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import PushwooshCore

/// Backing store for ``PushwooshInboxKitViewController``.
///
/// Owns the array of messages currently displayed by the table view and
/// applies the host-supplied transform pipeline before publishing.
final class InboxDataSource {

    private(set) var messages: [PWInboxMessageProtocol] = []

    var isEmpty: Bool { messages.isEmpty }

    var count: Int { messages.count }

    /// Merges the incoming list into the existing data source by message
    /// `code`. Server values win for shared codes; locally-added messages
    /// (e.g. arrivals merged from a push notification before the server has
    /// caught up) are preserved.
    ///
    /// Use this for notification-driven reloads where the local state may
    /// already contain entries the server hasn't synced yet.
    func update(_ raw: [PWInboxMessageProtocol], transform: ([PWInboxMessageProtocol]) -> [PWInboxMessageProtocol]) {
        let incomingCodes = Set(raw.compactMap { $0.code })
        let preservedFromLocal = messages.filter { msg in
            guard let code = msg.code else { return false }
            return !incomingCodes.contains(code)
        }
        messages = transform(raw + preservedFromLocal)
    }

    /// Hard reset — replaces the data source entirely with the new list.
    /// Use at `viewWillAppear` and pull-to-refresh, where the server is
    /// authoritative and any previously-merged-locally messages should be
    /// reconciled against fresh server truth.
    func replace(_ raw: [PWInboxMessageProtocol], transform: ([PWInboxMessageProtocol]) -> [PWInboxMessageProtocol]) {
        messages = transform(raw)
    }

    func message(at indexPath: IndexPath) -> PWInboxMessageProtocol? {
        guard indexPath.row >= 0 && indexPath.row < messages.count else { return nil }
        return messages[indexPath.row]
    }

    func remove(at indexPath: IndexPath) -> PWInboxMessageProtocol? {
        guard indexPath.row >= 0 && indexPath.row < messages.count else { return nil }
        return messages.remove(at: indexPath.row)
    }
}
#endif
