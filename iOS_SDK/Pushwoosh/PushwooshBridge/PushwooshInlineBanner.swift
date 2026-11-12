//
//  PushwooshInlineBanner.swift
//  PushwooshBridge
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// A banner of an inline slot as data.
@objc(PushwooshInlineBanner)
public final class PushwooshInlineBanner: NSObject {
    @objc public let slotId: String
    @objc public let bannerId: String
    /// Grows when the banner content changes.
    @objc public let version: Int
    /// `"html"` or `"native"`.
    @objc public let format: String
    /// The HTML document of an `"html"` banner.
    @objc public let html: String?
    /// Campaign data set in the Control Panel.
    @objc public let payload: [String: String]
    /// The banner is not shown from this moment on; `nil` = never expires.
    @objc public let expireDate: Date?
    /// A draft sent to a test device.
    @objc public let isTest: Bool
    /// The banner exactly as the server sent it, for bridges that pass JSON.
    @objc public let dictionary: [String: Any]

    public init(slotId: String, bannerId: String, version: Int, format: String, html: String?,
                payload: [String: String], expireDate: Date?, isTest: Bool, dictionary: [String: Any]) {
        self.slotId = slotId
        self.bannerId = bannerId
        self.version = version
        self.format = format
        self.html = html
        self.payload = payload
        self.expireDate = expireDate
        self.isTest = isTest
        self.dictionary = dictionary
    }
}
