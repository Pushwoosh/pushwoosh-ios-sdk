//
//  PWInlineModel.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import PushwooshBridge

/// The banner stored for one slot. `raw` is the banner object as the server sent it, kept to persist it as is.
struct PWInlineBanner {
    let slotId: String
    let bannerId: String
    let version: Int
    let receivedAt: Date
    /// The banner is not shown from this moment on (`nil` = never expires).
    let expireDate: Date?
    /// The slot never grows taller than this; the rest of the banner is clipped.
    let maxHeight: CGFloat?
    let content: Content
    /// Runs on a tap anywhere on the banner outside elements with their own action.
    let action: PWInlineAction?
    /// Close button drawn over the banner; `nil` = none.
    let close: PWInlineClose?
    /// A test banner: its events are not counted in the campaign statistics.
    let isTest: Bool
    /// The banner's custom data: string values only.
    let payload: [String: String]
    let raw: [String: Any]

    enum Content {
        case native(PWInlineNode)
        /// A self-contained HTML document drawn by the rich media web view.
        case html(String)
        /// Control group: the slot stays empty and only reports that the banner would have been shown.
        case control
    }

    var isControl: Bool {
        if case .control = content {
            return true
        }
        return false
    }

    var html: String? {
        if case .html(let html) = content {
            return html
        }
        return nil
    }
}

struct PWInlineClose {
    enum Position {
        case topRight
        case topLeft
    }

    static let defaultColor = UIColor.white
    static let defaultBackground = UIColor.black.withAlphaComponent(0.5)
    static let size: CGFloat = 28

    let position: Position
    let color: UIColor
    let background: UIColor
    let cornerRadius: CGFloat
}

extension PWInlineColorScheme {
    /// `overrideUserInterfaceStyle` of a banner; `.unspecified` lets it follow the slot's own traits.
    func interfaceStyle(system: UIUserInterfaceStyle) -> UIUserInterfaceStyle {
        switch self {
        case .app:
            return .unspecified
        case .system:
            return system
        case .light:
            return .light
        case .dark:
            return .dark
        @unknown default:
            return .unspecified
        }
    }
}

enum PWInlineAction {
    /// A web page, opened in Safari; the banner stays in its slot.
    case url(URL)
    /// An app link, handed to the system so the app's own URL handling opens it.
    case deeplink(URL)
    case close
    case postEvent(name: String, attributes: [String: Any])
    case copy(text: String, toast: String?)
}

struct PWInlineNode {
    enum Kind {
        case text(PWInlineText)
        case image(PWInlineImage)
        case button(PWInlineButton)
        case video(PWInlineVideo)
        case stack(PWInlineStack)
        case pager(PWInlinePager)
        /// Fixed length along the parent stack axis; `nil` takes the free space.
        case spacer(CGFloat?)
        case divider(PWInlineDivider)
    }

    /// Where a child sits inside an overlay stack; the first child sizes the overlay.
    enum Position {
        case fill, top, bottom, center, topLeft, topRight, bottomLeft, bottomRight
    }

    /// The node's `id` from the payload, or its type when it has none; reported with its clicks.
    let id: String
    let kind: Kind
    let style: PWInlineStyle
    /// Style with the node's `dark` overrides applied; `nil` = the same in both themes.
    let darkStyle: PWInlineStyle?
    let action: PWInlineAction?
    let position: Position
}

struct PWInlineStyle {
    var padding: UIEdgeInsets = .zero
    var background: UIColor?
    var gradient: PWInlineGradient?
    var backgroundImage: URL?
    var cornerRadius: CGFloat = 0
    var shadow: PWInlineShadow?
    var border: PWInlineBorder?
    /// Liquid Glass on iOS 26, a blur before; the optional tint colors it.
    var glass: PWInlineGlass?

    var isPlain: Bool {
        padding == .zero && background == nil && gradient == nil && backgroundImage == nil && cornerRadius == 0
            && shadow == nil && border == nil && glass == nil
    }
}

struct PWInlineGradient {
    let colors: [UIColor]
    /// Degrees clockwise from left-to-right: 90 runs top to bottom.
    let angle: CGFloat
}

struct PWInlineShadow {
    let color: UIColor
    let radius: CGFloat
    let offset: CGSize
}

struct PWInlineBorder {
    let color: UIColor
    let width: CGFloat
}

struct PWInlineGlass {
    let tint: UIColor?
}

struct PWInlineText {
    let text: String
    let color: UIColor?
    let size: CGFloat
    let weight: UIFont.Weight
    let alignment: NSTextAlignment
    let lines: Int
    let strikethrough: Bool
}

struct PWInlineImage {
    let url: URL
    /// Width / height. `nil` = take the ratio of the loaded image.
    let aspect: CGFloat?
}

struct PWInlineButton {
    let title: String
    let color: UIColor?
    let size: CGFloat
    let weight: UIFont.Weight
}

/// Muted, looping, plays while at least half of its height is on screen.
struct PWInlineVideo {
    let url: URL
    let poster: URL?
    let aspect: CGFloat
}

struct PWInlineStack {
    enum Layout {
        case row, column, overlay
    }

    let layout: Layout
    let spacing: CGFloat
    let alignment: UIStackView.Alignment
    let distribution: UIStackView.Distribution
    let children: [PWInlineNode]
}

struct PWInlinePager {
    let pages: [PWInlineNode]
    /// Seconds between automatic page turns; `nil` = only the user turns pages.
    let interval: TimeInterval?
    let indicatorColor: UIColor?
}

struct PWInlineDivider {
    let color: UIColor?
    let thickness: CGFloat
}
#endif
