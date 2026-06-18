//
//  PushwooshInboxCarouselSlide.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import PushwooshCore

/// A single slide inside a ``PushwooshInboxCarouselCell``.
///
/// Unlike the other card kinds — which render the message's single `imageUrl` —
/// a carousel shows several images from one message. Those slides cannot live in
/// the standard message fields (there is only one `imageUrl`), so they arrive in
/// `actionParams["carousel"]` and are decoded by ``decode(from:)``, mirroring how
/// ``PushwooshInboxButton`` decodes its buttons.
public struct PushwooshInboxCarouselSlide {

    /// Remote image URL string for the slide. Required — a slide without an image
    /// is dropped during decoding.
    public let imageUrl: String

    /// Optional caption rendered as an overlay at the bottom of the slide.
    public let title: String?

    /// Optional destination opened when the slide is tapped. When `nil`, a tap
    /// falls through to the message's default row action.
    public let url: URL?

    public init(imageUrl: String, title: String? = nil, url: URL? = nil) {
        self.imageUrl = imageUrl
        self.title = title
        self.url = url
    }

    /// Decodes the slide list from a message's `actionParams`. The expected shape
    /// is one of:
    /// ```
    /// { "carousel": [
    ///     { "image": "https://…/1.jpg", "title": "New in", "url": "myapp://p/1" },
    ///     { "image": "https://…/2.jpg", "title": "On sale", "url": "myapp://p/2" }
    /// ] }
    /// { "u": { "carousel": [...] } }
    /// { "u": "{\"carousel\":[...]}" }   // JSON-encoded `u` string
    /// ```
    public static func decode(from message: PWInboxMessageProtocol) -> [PushwooshInboxCarouselSlide] {
        guard let params = message.actionParams as NSDictionary? else { return [] }

        if let raw = params["carousel"] as? [Any] {
            return parse(raw)
        }
        if let uValue = params["u"] {
            if let uDict = uValue as? NSDictionary, let raw = uDict["carousel"] as? [Any] {
                return parse(raw)
            }
            if let uString = uValue as? String,
               let data = uString.data(using: .utf8),
               let parsed = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary,
               let raw = parsed["carousel"] as? [Any] {
                return parse(raw)
            }
        }
        return []
    }

    private static func parse(_ raw: [Any]) -> [PushwooshInboxCarouselSlide] {
        raw.compactMap { item -> PushwooshInboxCarouselSlide? in
            guard let dict = item as? [String: Any] else { return nil }
            guard let image = dict["image"] as? String, !image.isEmpty else { return nil }
            let title = (dict["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let url = (dict["url"] as? String)
                .flatMap { $0.isEmpty ? nil : $0 }
                .flatMap(URL.init(string:))
                .flatMap { $0.scheme != nil ? $0 : nil }
            return PushwooshInboxCarouselSlide(imageUrl: image, title: title, url: url)
        }
    }
}
#endif
