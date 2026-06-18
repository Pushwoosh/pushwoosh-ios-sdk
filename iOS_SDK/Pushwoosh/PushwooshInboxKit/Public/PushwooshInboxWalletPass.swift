//
//  PushwooshInboxWalletPass.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import PushwooshCore

/// Apple Wallet pass descriptor for a ``PushwooshInboxWalletCell``.
///
/// The card shows the standard "Add to Apple Wallet" button; tapping it downloads
/// the `.pkpass` at ``passURL`` and presents the system add-passes sheet. The
/// descriptor arrives in `actionParams["wallet"]` and is decoded by ``decode(from:)``.
///
/// This type is intentionally PassKit-free so it compiles on every platform the
/// module supports; only ``PushwooshInboxWalletCell`` (iOS-only) pulls in PassKit.
public struct PushwooshInboxWalletPass {

    /// Remote URL of the `.pkpass` bundle. Required.
    public let passURL: URL

    public init(passURL: URL) {
        self.passURL = passURL
    }

    /// Decodes the pass descriptor from a message's `actionParams`. Accepts both a
    /// bare URL string and an object form, plus the usual `u` / JSON-string nesting:
    /// ```
    /// { "wallet": "https://…/coupon.pkpass" }
    /// { "wallet": { "pass": "https://…/coupon.pkpass" } }
    /// { "u": { "wallet": { "pass": "…" } } }
    /// { "u": "{\"wallet\":\"…\"}" }   // JSON-encoded `u` string
    /// ```
    public static func decode(from message: PWInboxMessageProtocol) -> PushwooshInboxWalletPass? {
        guard let params = message.actionParams as NSDictionary? else { return nil }

        if let url = passURL(from: params["wallet"]) {
            return PushwooshInboxWalletPass(passURL: url)
        }
        if let uValue = params["u"] {
            if let uDict = uValue as? NSDictionary, let url = passURL(from: uDict["wallet"]) {
                return PushwooshInboxWalletPass(passURL: url)
            }
            if let uString = uValue as? String,
               let data = uString.data(using: .utf8),
               let parsed = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary,
               let url = passURL(from: parsed["wallet"]) {
                return PushwooshInboxWalletPass(passURL: url)
            }
        }
        return nil
    }

    /// Extracts a pass URL from a value that may be a bare string or an object
    /// carrying a `pass` field.
    private static func passURL(from value: Any?) -> URL? {
        if let string = value as? String, let url = networkURL(from: string) {
            return url
        }
        if let dict = value as? [String: Any],
           let string = dict["pass"] as? String, let url = networkURL(from: string) {
            return url
        }
        return nil
    }

    /// Accepts only `http(s)` URLs: the pass bytes are fetched with `URLSession`, which — unlike
    /// `UIApplication.open` — would read a `file://` resource from a payload-controlled string.
    private static func networkURL(from string: String) -> URL? {
        guard !string.isEmpty, let url = URL(string: string),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }
}
#endif
