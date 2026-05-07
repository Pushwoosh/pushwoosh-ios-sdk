//
//  PWInboxFacade.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS) && os(iOS)
import Foundation
import PushwooshCore

/// Internal Swift wrapper around the inbox backend exposed by
/// `PushwooshFramework`'s `PWInbox` class via the `PWInboxBridge` protocol.
///
/// The bridge guarantees every mutation goes through `PWInboxStorage` so
/// deleted / read / action flags persist across app restarts even when the
/// network request has not yet been acknowledged. Going through the bridge
/// also fires the legacy `PWInboxMessagesDidUpdateNotification` so co-existing
/// observers (e.g. the older `PushwooshInboxUI` module, host-app subscribers)
/// stay in sync with mutations that originated in `PushwooshInboxKit`.
class PWInboxFacade {

    static let shared = PWInboxFacade()

    /// The bridge points at `PWInbox` once `PWInbox.+load` registers it.
    /// During unit tests it may be `nil` — every method here degrades to a
    /// safe no-op (or empty success in the case of `loadMessages`).
    private var bridge: PWInboxBridge.Type? {
        return PWManagerBridge.shared().inboxBridge as? PWInboxBridge.Type
    }

    /// Loads all messages through the bridge → `PWInbox.loadMessagesWithCompletion`,
    /// which merges the network response into `PWInboxStorage` (preserving
    /// locally-set deleted/read flags) and returns the storage-owned refs.
    func loadMessages(_ completion: @escaping (Result<[PWInboxMessageProtocol], Error>) -> Void) {
        guard let bridge = bridge else {
            DispatchQueue.main.async { completion(.success([])) }
            return
        }
        bridge.loadMessages { messages, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(messages ?? []))
                }
            }
        }
    }

    /// Marks the supplied messages as read — both server-side and locally
    /// (persisted to `PWInboxStorage`). Idempotent, no-ops on empty input.
    func read(messages: [PWInboxMessageProtocol]) {
        let codes = messages.compactMap { $0.code }
        guard !codes.isEmpty, let bridge = bridge else { return }
        bridge.readMessages(withCodes: codes)
    }

    /// Performs the action associated with a message — server-side action
    /// status update plus local persistence.
    func performAction(message: PWInboxMessageProtocol) {
        guard let code = message.code, let bridge = bridge else { return }
        bridge.performActionForMessage(withCode: code)
    }

    /// Deletes the supplied messages. The bridge persists the deleted flag
    /// to `PWInboxStorage` before sending the network request, so a
    /// process restart before the backend acknowledges the delete will not
    /// resurrect the message in the feed.
    func delete(messages: [PWInboxMessageProtocol]) {
        let codes = messages.compactMap { $0.code }
        guard !codes.isEmpty, let bridge = bridge else { return }
        bridge.deleteMessages(withCodes: codes)
    }

    /// Marks every currently-stored unread message as read in one batch.
    /// Goes through the bridge → `PWInbox.markAllMessagesAsRead`.
    func markAllAsRead() {
        bridge?.markAllMessagesAsRead()
    }

    /// Deletes every read message in one batch. Pinned messages and unread
    /// messages are preserved.
    func deleteAllRead() {
        bridge?.deleteAllReadMessages()
    }
}
#endif
