//
//  PushwooshInboxKitAttributes.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

/// Configuration container for ``PushwooshInboxKitViewController``.
///
/// Use a value-typed `Attributes` to drive cell registration, transform pipeline,
/// behavior toggles, and visual style. The default configuration ships with a
/// single polished cell, dynamic dark-mode-aware colors, automatic mark-as-read
/// on disappear, and swipe-to-delete enabled.
public struct PushwooshInboxKitAttributes {

    /// Built-in cell kinds. Use these constants for type-safe code-driven
    /// overrides via ``forceCellKind`` or directly in your `cellKindResolver`.
    public enum CellKind: String {
        case banner
        case captioned
        case classic
        case `default`
    }

    /// When `true`, all messages currently visible on screen are marked as read
    /// when the controller disappears (single batch, idempotent server-side).
    public var automaticReadOnDisappear: Bool = true

    /// When `true`, dynamic colors resolve against the current trait collection.
    /// When `false`, the controller and cells force light-mode color resolution.
    public var enableDarkTheme: Bool = true

    /// Pull-to-refresh control on the table view.
    public var pullToRefreshEnabled: Bool = true

    /// Swipe-to-delete trailing action on each row.
    public var swipeToDeleteEnabled: Bool = true

    /// When `true`, messages whose `actionParams["pinned"] == true` are
    /// floated to the top of the feed by the default transform. Disable to
    /// fall back to the plain unread-first / recent-first ordering.
    ///
    /// Toggling this flag after `init` regenerates ``transform`` from the
    /// default. If you assigned a custom transform, re-assign it after
    /// changing `pinningEnabled`, or your override will be replaced.
    public var pinningEnabled: Bool = true {
        didSet {
            self.transform = Self.defaultTransform(pinningEnabled: pinningEnabled)
        }
    }

    /// When `true`, the pin indicator (chip / glyph) is rendered on pinned
    /// messages. When `false`, the indicator is hidden but pinned-first
    /// sorting is preserved (still controlled by ``pinningEnabled``).
    /// Useful when integrators want the ordering behaviour without the
    /// visual chip.
    public var pinIndicatorVisible: Bool = true

    /// When `true`, cells render up to N inline CTA buttons parsed from
    /// `actionParams["buttons"]`. Disable to ignore the server-supplied
    /// buttons regardless of payload.
    public var inlineButtonsEnabled: Bool = true

    /// When set, this value short-circuits the resolver — every message
    /// renders with this kind. Use it to force a uniform layout from code
    /// without disabling the server-driven resolver entirely.
    public var forceCellKind: CellKind?

    /// Mapping of cell-kind identifiers to cell classes.
    ///
    /// The default registry ships **four entries** matching Braze's content-card
    /// shapes:
    /// - `"banner"` → ``PushwooshInboxBannerCell`` — full-bleed image, no text.
    /// - `"captioned"` → ``PushwooshInboxCaptionedCell`` — image on top, title + body below.
    /// - `"classic"` → ``PushwooshInboxClassicCell`` — coloured initial avatar + title + body.
    /// - `"default"` → ``PushwooshInboxClassicCell`` — fallback when the resolver returns an unknown kind.
    public var cells: [String: PushwooshInboxCell.Type]

    /// Resolves a cell-kind identifier for a given message. The result must be
    /// a key in `cells`.
    ///
    /// The default resolver is **server-driven first**, with a heuristic fallback:
    /// 1. Reads `actionParams["displayType"]` from the inbox message payload.
    ///    If it equals `"banner"`, `"captioned"`, or `"classic"` (case-insensitive),
    ///    that kind is used.
    /// 2. Otherwise falls back to image/title presence:
    ///    - image + no title → `"banner"`
    ///    - image + title    → `"captioned"`
    ///    - else             → `"classic"`
    ///
    /// Override this closure to drive variants from your own server-side
    /// fields or to add custom cell kinds.
    public var cellKindResolver: (PWInboxMessageProtocol) -> String = PushwooshInboxKitAttributes.defaultCellKindResolver

    /// Pipeline applied to the raw inbox payload before reload. Use to sort,
    /// filter, or group messages.
    ///
    /// The default transform sorts pinned messages first
    /// (`actionParams["pinned"] == true`, when ``pinningEnabled`` is `true`),
    /// then unread before read, then most recent first.
    public var transform: ([PWInboxMessageProtocol]) -> [PWInboxMessageProtocol] = PushwooshInboxKitAttributes.defaultTransform(pinningEnabled: true)

    /// Visual styling for the controller and the default cell.
    public var style: Style = .default

    /// Empty-state message rendered when the inbox returns zero messages.
    public var emptyMessage: String = "Your inbox is empty"

    /// Error-state message rendered when the inbox load fails.
    public var errorMessage: String = "Couldn't load messages"

    public init() {
        self.cells = [
            "banner": PushwooshInboxBannerCell.self,
            "captioned": PushwooshInboxCaptionedCell.self,
            "classic": PushwooshInboxClassicCell.self,
            "default": PushwooshInboxClassicCell.self
        ]
    }

    /// Default resolver — reads `actionParams["displayType"]` first, falls back
    /// to imageUrl/title heuristic. See ``cellKindResolver`` for details.
    ///
    /// Degrade rules:
    /// - `banner` and `captioned` both require a non-empty `imageUrl`. If the
    ///   message has no image, the resolver degrades the kind to `classic` so
    ///   we never render an empty image placeholder card.
    public static let defaultCellKindResolver: (PWInboxMessageProtocol) -> String = { message in
        let serverType = readDisplayType(from: message)
        let hasImage = !(message.imageUrl?.isEmpty ?? true)

        let requested: String
        if let serverType = serverType, ["banner", "captioned", "classic"].contains(serverType) {
            requested = serverType
        } else {
            switch (hasImage, !(message.title?.isEmpty ?? true)) {
            case (true, false): requested = "banner"
            case (true, true): requested = "captioned"
            default: requested = "classic"
            }
        }

        let resolved: String
        switch requested {
        case "banner", "captioned":
            resolved = hasImage ? requested : "classic"
        default:
            resolved = requested
        }

        let degradedNote = (resolved != requested) ? " (degraded from \(requested) — no imageUrl)" : ""
        PushwooshLog.pushwooshLog(
            .PW_LL_INFO,
            className: "PushwooshInboxKit",
            message: "Inbox cell resolve — code=\(message.code ?? "?") "
                   + "displayType=\(serverType ?? "nil") "
                   + "→ kind=\(resolved)\(degradedNote)"
        )

        return resolved
    }

    /// Default transform — pinned-first (when `pinningEnabled` is `true`),
    /// then unread-first, then recent-first. Override `attributes.transform`
    /// to supply your own pipeline.
    public static func defaultTransform(pinningEnabled: Bool) -> ([PWInboxMessageProtocol]) -> [PWInboxMessageProtocol] {
        return { messages in
            messages.sorted { lhs, rhs in
                if pinningEnabled {
                    let lp = isPinned(lhs)
                    let rp = isPinned(rhs)
                    if lp != rp { return lp && !rp }
                }
                if lhs.isRead != rhs.isRead { return !lhs.isRead && rhs.isRead }
                let l = lhs.sendDate ?? .distantPast
                let r = rhs.sendDate ?? .distantPast
                return l > r
            }
        }
    }

    /// `true` if the message carries `actionParams["pinned"] == true` at the
    /// root, inside `u`, or inside `userdata`. Tolerant to the same wire
    /// shapes as ``readDisplayType(from:)``.
    public static func isPinned(_ message: PWInboxMessageProtocol) -> Bool {
        guard let params = message.actionParams as NSDictionary? else { return false }
        if let direct = params["pinned"] as? Bool { return direct }
        if let direct = params["pinned"] as? NSNumber { return direct.boolValue }
        if let uValue = params["u"] {
            if let uDict = uValue as? NSDictionary {
                if let v = uDict["pinned"] as? Bool { return v }
                if let v = uDict["pinned"] as? NSNumber { return v.boolValue }
            }
            if let uString = uValue as? String,
               let data = uString.data(using: .utf8),
               let parsed = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary {
                if let v = parsed["pinned"] as? Bool { return v }
                if let v = parsed["pinned"] as? NSNumber { return v.boolValue }
            }
        }
        if let userdata = params["userdata"] as? NSDictionary {
            if let v = userdata["pinned"] as? Bool { return v }
            if let v = userdata["pinned"] as? NSNumber { return v.boolValue }
        }
        return false
    }

    /// Looks up `displayType` in `actionParams`. Tolerant to several wire
    /// shapes Pushwoosh uses — root-level, nested `u`/`userdata` as dicts, and
    /// the common case where `u` arrives as a JSON-encoded string.
    static func readDisplayType(from message: PWInboxMessageProtocol) -> String? {
        guard let params = message.actionParams as NSDictionary? else { return nil }

        // 1) Root level: { "displayType": "banner" }
        if let direct = params["displayType"] as? String {
            return direct.lowercased()
        }

        // 2) `u` value — could be a dict or a JSON-encoded string.
        if let uValue = params["u"] {
            if let uDict = uValue as? NSDictionary,
               let t = uDict["displayType"] as? String {
                return t.lowercased()
            }
            if let uString = uValue as? String,
               let data = uString.data(using: .utf8),
               let parsed = (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary,
               let t = parsed["displayType"] as? String {
                return t.lowercased()
            }
        }

        // 3) Legacy nested userdata: { "userdata": { "displayType": "..." } }
        if let userdata = params["userdata"] as? NSDictionary,
           let t = userdata["displayType"] as? String {
            return t.lowercased()
        }

        return nil
    }
}

extension PushwooshInboxKitAttributes {

    /// Visual style applied to the controller chrome and the default cell.
    public struct Style {
        public var backgroundColor: UIColor
        public var separatorColor: UIColor
        public var titleFont: UIFont
        public var titleColorRead: UIColor
        public var titleColorUnread: UIColor
        public var bodyFont: UIFont
        public var bodyColorRead: UIColor
        public var bodyColorUnread: UIColor
        public var dateFont: UIFont
        public var dateColor: UIColor
        public var unreadBadgeColor: UIColor
        public var imageCornerRadius: CGFloat
        public var imagePlaceholder: UIImage?
        public var dateFormatter: (Date) -> String

        // MARK: Inline-button styling
        public var buttonFont: UIFont
        public var buttonTextColor: UIColor
        public var buttonBackgroundColor: UIColor
        public var buttonCornerRadius: CGFloat

        // MARK: Pin indicator styling
        public var pinIndicatorColor: UIColor
        /// Optional override for the pin glyph. Defaults to SF Symbol `pin.fill`
        /// at apply-time when `nil`.
        public var pinIndicatorImage: UIImage?

        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleFont: UIFont,
            titleColorRead: UIColor,
            titleColorUnread: UIColor,
            bodyFont: UIFont,
            bodyColorRead: UIColor,
            bodyColorUnread: UIColor,
            dateFont: UIFont,
            dateColor: UIColor,
            unreadBadgeColor: UIColor,
            imageCornerRadius: CGFloat,
            imagePlaceholder: UIImage?,
            dateFormatter: @escaping (Date) -> String,
            buttonFont: UIFont = .systemFont(ofSize: 14, weight: .semibold),
            buttonTextColor: UIColor = .systemBlue,
            buttonBackgroundColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.10),
            buttonCornerRadius: CGFloat = 10,
            pinIndicatorColor: UIColor = .systemOrange,
            pinIndicatorImage: UIImage? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
            self.titleFont = titleFont
            self.titleColorRead = titleColorRead
            self.titleColorUnread = titleColorUnread
            self.bodyFont = bodyFont
            self.bodyColorRead = bodyColorRead
            self.bodyColorUnread = bodyColorUnread
            self.dateFont = dateFont
            self.dateColor = dateColor
            self.unreadBadgeColor = unreadBadgeColor
            self.imageCornerRadius = imageCornerRadius
            self.imagePlaceholder = imagePlaceholder
            self.dateFormatter = dateFormatter
            self.buttonFont = buttonFont
            self.buttonTextColor = buttonTextColor
            self.buttonBackgroundColor = buttonBackgroundColor
            self.buttonCornerRadius = buttonCornerRadius
            self.pinIndicatorColor = pinIndicatorColor
            self.pinIndicatorImage = pinIndicatorImage
        }

        public static let `default`: Style = {
            let cardSurface = UIColor.secondarySystemGroupedBackground
            let separator = UIColor.separator
            let titleRead = UIColor.secondaryLabel
            let titleUnread = UIColor.label
            let bodyRead = UIColor.tertiaryLabel
            let bodyUnread = UIColor.secondaryLabel
            let dateColour = UIColor.secondaryLabel
            let accent = UIColor.systemBlue
            let buttonTint = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.systemBlue.withAlphaComponent(0.16)
                    : UIColor.systemBlue.withAlphaComponent(0.12)
            }

            return Style(
                backgroundColor: cardSurface,
                separatorColor: separator,
                titleFont: .systemFont(ofSize: 16, weight: .semibold),
                titleColorRead: titleRead,
                titleColorUnread: titleUnread,
                bodyFont: .systemFont(ofSize: 14, weight: .regular),
                bodyColorRead: bodyRead,
                bodyColorUnread: bodyUnread,
                dateFont: .systemFont(ofSize: 13, weight: .regular),
                dateColor: dateColour,
                unreadBadgeColor: accent,
                imageCornerRadius: 8.0,
                imagePlaceholder: nil,
                dateFormatter: Style.defaultDateFormatter,
                buttonFont: .systemFont(ofSize: 14, weight: .medium),
                buttonTextColor: accent,
                buttonBackgroundColor: buttonTint,
                buttonCornerRadius: 10,
                pinIndicatorColor: accent,
                pinIndicatorImage: nil
            )
        }()

        public static let defaultDateFormatter: (Date) -> String = { date in
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                return f.string(from: date)
            }
            if calendar.isDateInYesterday(date) {
                return "Yesterday"
            }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: date)
        }
    }
}
#endif
