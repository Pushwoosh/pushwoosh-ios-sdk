//
//  PushwooshInboxVideoContent.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import PushwooshCore

/// Video payload for a ``PushwooshInboxVideoCell``.
///
/// Like the carousel slides, the video descriptor cannot live in the standard message fields, so
/// it arrives in `actionParams["video"]` and is decoded by ``decode(from:)``. The cell shows the
/// poster with a play badge; tapping it opens a full-screen player.
public struct PushwooshInboxVideoContent {

    /// Remote URL of the video stream / file played full-screen on tap. Required.
    public let videoURL: URL

    /// Optional poster image shown in the cell as the preview.
    public let posterURL: String?

    public init(videoURL: URL, posterURL: String? = nil) {
        self.videoURL = videoURL
        self.posterURL = posterURL
    }

    /// Decodes the video descriptor from a message's `actionParams`. Expected shapes (mirrors
    /// ``PushwooshInboxButton`` / ``PushwooshInboxCarouselSlide``):
    /// ```
    /// { "video": { "url": "https://…/clip.mp4", "poster": "https://…/p.jpg" } }
    /// { "u": { "video": { … } } }
    /// { "u": "{\"video\":{…}}" }   // JSON-encoded `u` string
    /// ```
    public static func decode(from message: PWInboxMessageProtocol) -> PushwooshInboxVideoContent? {
        guard let params = message.actionParams as NSDictionary? else { return nil }

        if let dict = params["video"] as? [String: Any] {
            return content(from: dict)
        }
        if let uValue = params["u"] {
            if let uDict = uValue as? NSDictionary, let dict = uDict["video"] as? [String: Any] {
                return content(from: dict)
            }
            if let uString = uValue as? String,
               let data = uString.data(using: .utf8),
               let parsed = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary,
               let dict = parsed["video"] as? [String: Any] {
                return content(from: dict)
            }
        }
        return nil
    }

    private static func content(from dict: [String: Any]) -> PushwooshInboxVideoContent? {
        // Restrict to network schemes: the URL is fed to AVPlayer, which — unlike UIApplication.open —
        // will happily load `file://` and other local schemes from a payload-controlled string.
        guard let urlString = dict["url"] as? String, !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        let poster = (dict["poster"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return PushwooshInboxVideoContent(videoURL: url, posterURL: poster)
    }
}
#endif
