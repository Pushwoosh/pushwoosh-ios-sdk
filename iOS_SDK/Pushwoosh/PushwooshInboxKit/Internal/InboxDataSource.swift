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

    /// Full, host-transformed list — what ``PushwooshInboxKitDelegate`` sees and what
    /// ``unreadCount(forTabId:)`` counts over, regardless of the selected tab.
    private(set) var allMessages: [PWInboxMessageProtocol] = []

    /// The subset the table shows: all of ``allMessages`` when ``selectedTabId`` is nil,
    /// otherwise only the messages whose `tabId` matches it exactly.
    private(set) var messages: [PWInboxMessageProtocol] = []

    /// `nil` selects the "All" tab. Setting this recomputes ``messages`` from ``allMessages``.
    var selectedTabId: String? {
        didSet { applyTabFilter() }
    }

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
        let preservedFromLocal = allMessages.filter { msg in
            guard let code = msg.code else { return false }
            return !incomingCodes.contains(code)
        }
        allMessages = transform(raw + preservedFromLocal)
        applyTabFilter()
    }

    /// Hard reset — replaces the data source entirely with the new list.
    /// Use at `viewWillAppear` and pull-to-refresh, where the server is
    /// authoritative and any previously-merged-locally messages should be
    /// reconciled against fresh server truth.
    func replace(_ raw: [PWInboxMessageProtocol], transform: ([PWInboxMessageProtocol]) -> [PWInboxMessageProtocol]) {
        allMessages = transform(raw)
        applyTabFilter()
    }

    func message(at indexPath: IndexPath) -> PWInboxMessageProtocol? {
        guard indexPath.row >= 0 && indexPath.row < messages.count else { return nil }
        return messages[indexPath.row]
    }

    /// Removes the row at `indexPath` from both the filtered view and the full list behind it,
    /// so a deletion made while a tab is selected cannot reappear under another tab.
    func remove(at indexPath: IndexPath) -> PWInboxMessageProtocol? {
        guard indexPath.row >= 0 && indexPath.row < messages.count else { return nil }
        let removed = messages.remove(at: indexPath.row)
        if let code = removed.code {
            allMessages.removeAll { $0.code == code }
        } else {
            allMessages.removeAll { ($0 as AnyObject) === (removed as AnyObject) }
        }
        return removed
    }

    /// Unread count for one tab, or across the whole inbox when `tabId` is nil.
    func unreadCount(forTabId tabId: String?) -> Int {
        allMessages.filter { !$0.isRead && (tabId == nil || $0.safeTabId == tabId) }.count
    }

    private func applyTabFilter() {
        guard let selectedTabId = selectedTabId else {
            messages = allMessages
            return
        }
        messages = allMessages.filter { $0.safeTabId == selectedTabId }
    }
}

private extension PWInboxMessageProtocol {
    /// `tabId`, guarded for an Obj-C host object that conforms without implementing it — reads as "no tab".
    var safeTabId: String? {
        guard (self as AnyObject).responds(to: #selector(getter: PWInboxMessageProtocol.tabId)) else { return nil }
        return tabId
    }
}
#endif
