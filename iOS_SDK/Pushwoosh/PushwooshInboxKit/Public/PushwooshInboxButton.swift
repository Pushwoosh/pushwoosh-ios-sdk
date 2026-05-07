//
//  PushwooshInboxButton.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 30.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import PushwooshCore

/// The action a tapped inline CTA button should perform.
///
/// The SDK handles the first three cases automatically when the host delegate
/// returns `true` from
/// ``PushwooshInboxKitDelegate/inboxKit(_:didTapButton:onMessage:)``:
/// - ``openURL(_:)`` — opens via `UIApplication.shared.open`.
/// - ``dismiss`` — removes the carrying message from the inbox feed.
/// - ``markRead`` — marks the carrying message as read.
///
/// ``custom(_:)`` carries the full server payload and is intentionally
/// passed straight through — the host must intercept it in the delegate
/// and run its own logic by inspecting the dictionary (typically keyed by
/// a `tag` field agreed with the marketer).
public enum PushwooshInboxButtonAction {
    case openURL(URL)
    case dismiss
    case markRead
    case custom([String: Any])
}

/// A single inline call-to-action button rendered inside an inbox cell.
///
/// Buttons arrive from the server inside `actionParams["buttons"]` (a JSON
/// array) and are decoded by ``decode(from:)``. The host can intercept taps
/// via ``PushwooshInboxKitDelegate/inboxKit(_:didTapButton:onMessage:)``.
public struct PushwooshInboxButton {
    /// Visible text on the button.
    public let title: String

    /// The semantic action this button represents. See
    /// ``PushwooshInboxButtonAction`` for the four supported variants.
    public let action: PushwooshInboxButtonAction

    public init(title: String, action: PushwooshInboxButtonAction) {
        self.title = title
        self.action = action
    }

    /// Convenience initializer: a non-empty parseable `url` becomes
    /// ``openURL(_:)``; anything else becomes ``custom(_:)`` carrying
    /// `payload`.
    public init(title: String, url: String? = nil, payload: [String: Any] = [:]) {
        self.title = title
        if let u = url, !u.isEmpty, let parsed = URL(string: u) {
            self.action = .openURL(parsed)
        } else {
            self.action = .custom(payload)
        }
    }

    /// The URL string when the action is ``openURL(_:)``, otherwise `nil`.
    public var url: String? {
        if case .openURL(let u) = action { return u.absoluteString }
        return nil
    }

    /// The raw payload dictionary when the action is ``custom(_:)``,
    /// otherwise empty.
    public var payload: [String: Any] {
        if case .custom(let p) = action { return p }
        return [:]
    }

    /// Decodes the button list from a message's `actionParams`. The expected
    /// shape is one of:
    /// ```
    /// { "buttons": [
    ///     { "title": "Open",   "url": "myapp://path"               },
    ///     { "title": "Read",   "action": "markRead"                },
    ///     { "title": "Close",  "action": "dismiss"                 },
    ///     { "title": "Save",   "action": "custom", "tag": "save"   }
    /// ] }
    /// { "u": { "buttons": [...] } }
    /// { "u": "{\"buttons\":[...]}" }   // JSON-encoded `u` string
    /// ```
    public static func decode(from message: PWInboxMessageProtocol) -> [PushwooshInboxButton] {
        guard let params = message.actionParams as NSDictionary? else { return [] }

        if let raw = params["buttons"] as? [Any] {
            return parse(raw)
        }
        if let uValue = params["u"] {
            if let uDict = uValue as? NSDictionary, let raw = uDict["buttons"] as? [Any] {
                return parse(raw)
            }
            if let uString = uValue as? String,
               let data = uString.data(using: .utf8),
               let parsed = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary,
               let raw = parsed["buttons"] as? [Any] {
                return parse(raw)
            }
        }
        return []
    }

    private static func parse(_ raw: [Any]) -> [PushwooshInboxButton] {
        raw.compactMap { item -> PushwooshInboxButton? in
            guard let dict = item as? [String: Any] else { return nil }
            guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
            return PushwooshInboxButton(title: title, action: resolveAction(from: dict))
        }
    }

    /// Resolves the wire shape into a typed ``PushwooshInboxButtonAction``.
    ///
    /// Priority:
    /// 1. Explicit `action` token: `dismiss`, `markRead` (case-insensitive).
    /// 2. Non-empty `url` field — wrapped in ``openURL(_:)``.
    /// 3. Anything else falls into ``custom(_:)`` carrying the full payload
    ///    minus `title` and `action` keys.
    private static func resolveAction(from dict: [String: Any]) -> PushwooshInboxButtonAction {
        let actionToken = (dict["action"] as? String)?.lowercased()
        switch actionToken {
        case "dismiss":
            return .dismiss
        case "markread":
            return .markRead
        default:
            if let urlString = dict["url"] as? String,
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                return .openURL(url)
            }
            var payload = dict
            payload.removeValue(forKey: "title")
            payload.removeValue(forKey: "action")
            return .custom(payload)
        }
    }
}
#endif
