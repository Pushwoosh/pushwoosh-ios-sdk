//
//  StoryPayloadParser.swift
//  PushwooshNotificationUI
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

enum StoryPayloadParser {

    private static let rootKey = "pw_stories"
    private static let pagesKey = "pages"
    private static let imageKey = "image"
    private static let durationKey = "duration"
    private static let linkKey = "link"
    private static let buttonTitleKey = "button_title"
    private static let titleKey = "title"
    private static let subtitleKey = "subtitle"
    private static let customDataKey = "u"
    private static let userdataKey = "userdata"

    static func parse(userInfo: [AnyHashable: Any]) -> [StoryPage] {
        guard let block = storiesBlock(from: userInfo),
              let rawPages = block[pagesKey] as? [[String: Any]] else {
            return []
        }
        return rawPages.compactMap(page(from:))
    }

    /// Locates the `pw_stories` block. It may sit at the payload root (legacy `ios_root_params`
    /// delivery) or inside the custom-data container `u` / `userdata` (the `data` API field,
    /// delivered either as a dictionary or as a JSON-encoded string).
    private static func storiesBlock(from userInfo: [AnyHashable: Any]) -> [String: Any]? {
        if let root = userInfo[rootKey] as? [String: Any] {
            return root
        }
        for container in [userInfo[customDataKey], userInfo[userdataKey]] {
            if let dict = customDataDictionary(container),
               let block = dict[rootKey] as? [String: Any] {
                return block
            }
        }
        return nil
    }

    /// Normalises a custom-data value that may arrive as a dictionary or a JSON-encoded string.
    private static func customDataDictionary(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return nil
    }

    private static func page(from raw: [String: Any]) -> StoryPage? {
        guard let imageString = raw[imageKey] as? String,
              let imageURL = URL(string: imageString),
              imageURL.scheme != nil else {
            return nil
        }

        let duration: TimeInterval
        if let number = raw[durationKey] as? NSNumber {
            duration = number.doubleValue
        } else {
            duration = StoryPage.defaultDuration
        }

        let link = (raw[linkKey] as? String)
            .flatMap(URL.init(string:))
            .flatMap { $0.scheme != nil ? $0 : nil }
        let buttonTitle = (raw[buttonTitleKey] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let title = (raw[titleKey] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let subtitle = (raw[subtitleKey] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return StoryPage(imageURL: imageURL,
                         duration: duration,
                         link: link,
                         buttonTitle: buttonTitle,
                         title: title,
                         subtitle: subtitle)
    }
}
