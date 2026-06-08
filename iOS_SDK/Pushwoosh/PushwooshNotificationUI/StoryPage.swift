//
//  StoryPage.swift
//  PushwooshNotificationUI
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

public struct StoryPage: Equatable {
    public static let defaultDuration: TimeInterval = 5.0
    static let maxDuration: TimeInterval = 30

    public let imageURL: URL
    public let duration: TimeInterval
    public let link: URL?
    public let buttonTitle: String?
    public let title: String?
    public let subtitle: String?

    init(imageURL: URL,
         duration: TimeInterval = StoryPage.defaultDuration,
         link: URL? = nil,
         buttonTitle: String? = nil,
         title: String? = nil,
         subtitle: String? = nil) {
        self.imageURL = imageURL
        self.duration = (duration.isFinite && duration > 0)
            ? min(duration, StoryPage.maxDuration)
            : StoryPage.defaultDuration
        self.link = link
        self.buttonTitle = buttonTitle
        self.title = title
        self.subtitle = subtitle
    }
}
