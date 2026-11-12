//
//  PWInlineParser.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import PushwooshCore

/// Decodes one banner of a slots response into a store banner. Fail-closed: a banner with any unknown
/// node, format or enum value or a wrongly typed known key is dropped and the failing path is logged;
/// unknown keys are ignored.
enum PWInlineParser {

    private enum Fail: Error {
        case key(String)
    }

    private static let maxDepth = 16

    /// Largest size, spacing, padding, radius, border, shadow or height in points a banner may ask for; a
    /// banner with a larger one is dropped, as such values overflow Auto Layout.
    static let maxLength: Double = 4096
    static let maxFontSize: Double = 256

    /// The banner the server put into `slotId`; `nil` when the slot is empty or the banner breaks the contract.
    static func banner(from raw: Any?, slotId: String, receivedAt: Date) -> PWInlineBanner? {
        guard let raw = raw, !(raw is NSNull) else {
            return nil
        }
        do {
            return try parseBanner(raw, slotId: slotId, receivedAt: receivedAt)
        } catch Fail.key(let path) {
            warn("Invalid inline banner for slot '\(slotId)', dropped at: \(path)")
        } catch {
            warn("Invalid inline banner for slot '\(slotId)': \(error)")
        }
        return nil
    }

    private static func parseBanner(_ raw: Any, slotId: String, receivedAt: Date) throws -> PWInlineBanner {
        guard let dict = raw as? [String: Any], JSONSerialization.isValidJSONObject(dict) else {
            throw Fail.key("banner")
        }
        guard let bannerId = try optionalString(dict, "bannerId", "bannerId"), !bannerId.isEmpty else {
            throw Fail.key("bannerId")
        }
        guard let version = try optionalInteger(dict, "version", "version"), version >= 0 else {
            throw Fail.key("version")
        }
        let maxHeight = try optionalLength(dict, "maxHeight", "maxHeight")
        if let maxHeight = maxHeight, maxHeight <= 0 {
            throw Fail.key("maxHeight")
        }
        let expireDate = try optionalInteger(dict, "expireDate", "expireDate")
        let content: PWInlineBanner.Content
        if try optionalBool(dict, "control", "control") ?? false {
            content = .control
        } else {
            content = try bannerContent(dict)
        }
        return PWInlineBanner(slotId: slotId,
                              bannerId: bannerId,
                              version: version,
                              receivedAt: receivedAt,
                              expireDate: expireDate.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                              maxHeight: maxHeight.map { CGFloat($0) },
                              content: content,
                              action: try PWInAppConfigParser.presentValue(dict, "action").flatMap { try bannerAction($0) },
                              close: try PWInAppConfigParser.presentValue(dict, "close").flatMap { try close($0) },
                              isTest: try optionalBool(dict, "test", "test") ?? false,
                              payload: payload(dict, bannerId: bannerId),
                              raw: dict)
    }

    /// Keeps the string values; a value of another type drops only its own key.
    private static func payload(_ dict: [String: Any], bannerId: String) -> [String: String] {
        guard let raw = PWInAppConfigParser.presentValue(dict, "payload") else {
            return [:]
        }
        guard let object = raw as? [String: Any] else {
            warn("Inline banner '\(bannerId)' payload is not an object, ignored")
            return [:]
        }
        let payload = object.compactMapValues { $0 as? String }
        let dropped = Set(object.keys).subtracting(payload.keys).sorted()
        if !dropped.isEmpty {
            warn("Inline banner '\(bannerId)' payload keys \(dropped) are not strings, dropped")
        }
        return payload
    }

    private static func bannerContent(_ dict: [String: Any]) throws -> PWInlineBanner.Content {
        switch try optionalString(dict, "format", "format") {
        case "native":
            guard let native = PWInAppConfigParser.presentValue(dict, "native") else {
                throw Fail.key("native")
            }
            return .native(try node(try object(native, "native")["root"], "native.root", depth: 0))
        case "html":
            guard let html = try optionalString(dict, "html", "html"), !html.isEmpty else {
                throw Fail.key("html")
            }
            return .html(html)
        default:
            throw Fail.key("format")
        }
    }

    private static func close(_ raw: Any) throws -> PWInlineClose? {
        let dict = try object(raw, "close")
        guard try optionalBool(dict, "enabled", "close.enabled") ?? false else {
            return nil
        }
        let cornerRadius = try optionalLength(dict, "cornerRadius", "close.cornerRadius")
        let positions: [String: PWInlineClose.Position] = ["topRight": .topRight, "topLeft": .topLeft]
        return PWInlineClose(position: try optionalEnum(dict, "position", "close.position", positions) ?? .topRight,
                             color: try optionalColor(dict, "color", "close.color") ?? PWInlineClose.defaultColor,
                             background: try optionalColor(dict, "background", "close.background")
                                ?? PWInlineClose.defaultBackground,
                             cornerRadius: cornerRadius.map { CGFloat($0) } ?? PWInlineClose.size / 2)
    }

    // MARK: - Nodes

    /// Keys a node's `dark` object may override; texts, sizes and actions stay the same in both themes.
    private static let themableKeys: Set<String> = ["background", "gradient", "backgroundImage", "shadow", "border",
                                                    "glass", "color", "indicatorColor"]

    private static let weights: [String: UIFont.Weight] = [
        "regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold, "heavy": .heavy, "black": .black,
    ]

    private static func node(_ raw: Any?, _ label: String, depth: Int) throws -> PWInlineNode {
        guard depth < maxDepth else {
            throw Fail.key("\(label) (too deep)")
        }
        guard let dict = raw as? [String: Any], let type = dict["type"] as? String else {
            throw Fail.key("\(label).type")
        }
        let dark = try darkVariant(dict, label)
        let kind: PWInlineNode.Kind
        switch type {
        case "text":
            kind = .text(try text(dict, dark, label))
        case "image":
            kind = .image(try image(dict, label))
        case "button":
            kind = .button(try button(dict, dark, label))
        case "video":
            kind = .video(try video(dict, label))
        case "stack":
            kind = .stack(try stack(dict, label, depth: depth))
        case "pager":
            kind = .pager(try pager(dict, dark, label, depth: depth))
        case "spacer":
            kind = .spacer(try optionalLength(dict, "size", "\(label).size").map { CGFloat($0) })
        case "divider":
            let thickness = try optionalLength(dict, "thickness", "\(label).thickness") ?? 1
            guard thickness > 0 else {
                throw Fail.key("\(label).thickness")
            }
            kind = .divider(PWInlineDivider(color: try themedColor(dict, dark, "color", label), thickness: CGFloat(thickness)))
        default:
            throw Fail.key("\(label).type")
        }
        let positions: [String: PWInlineNode.Position] = [
            "fill": .fill, "top": .top, "bottom": .bottom, "center": .center,
            "topLeft": .topLeft, "topRight": .topRight, "bottomLeft": .bottomLeft, "bottomRight": .bottomRight,
        ]
        return PWInlineNode(id: try optionalString(dict, "id", "\(label).id") ?? type,
                            kind: kind,
                            style: try style(dict, label),
                            darkStyle: try dark.map { try style($0, "\(label).dark") },
                            action: try PWInAppConfigParser.presentValue(dict, "action").flatMap { try action($0, "\(label).action") },
                            position: try optionalEnum(dict, "position", "\(label).position", positions) ?? .fill)
    }

    /// The node with its `dark` overrides applied, or `nil` when it has none.
    private static func darkVariant(_ dict: [String: Any], _ label: String) throws -> [String: Any]? {
        guard let raw = PWInAppConfigParser.presentValue(dict, "dark") else {
            return nil
        }
        guard let dark = raw as? [String: Any] else {
            throw Fail.key("\(label).dark")
        }
        var merged = dict
        for (key, value) in dark where themableKeys.contains(key) && !(value is NSNull) {
            merged[key] = value
        }
        return merged
    }

    private static func text(_ dict: [String: Any], _ dark: [String: Any]?, _ label: String) throws -> PWInlineText {
        guard let text = dict["text"] as? String else {
            throw Fail.key("\(label).text")
        }
        let alignments: [String: NSTextAlignment] = ["left": .left, "center": .center, "right": .right]
        let lines = try optionalInteger(dict, "lines", "\(label).lines") ?? 0
        guard lines >= 0 else {
            throw Fail.key("\(label).lines")
        }
        return PWInlineText(text: text,
                            color: try themedColor(dict, dark, "color", label),
                            size: try fontSize(dict, label),
                            weight: try optionalEnum(dict, "weight", "\(label).weight", weights) ?? .regular,
                            alignment: try optionalEnum(dict, "align", "\(label).align", alignments) ?? .natural,
                            lines: lines,
                            strikethrough: try optionalBool(dict, "strike", "\(label).strike") ?? false)
    }

    private static func fontSize(_ dict: [String: Any], _ label: String) throws -> CGFloat {
        let size = try optionalLength(dict, "size", "\(label).size", in: 0...maxFontSize) ?? 15
        guard size > 0 else {
            throw Fail.key("\(label).size")
        }
        return CGFloat(size)
    }

    private static func image(_ dict: [String: Any], _ label: String) throws -> PWInlineImage {
        PWInlineImage(url: try url(dict, "url", label), aspect: try aspect(dict, label))
    }

    private static func video(_ dict: [String: Any], _ label: String) throws -> PWInlineVideo {
        PWInlineVideo(url: try url(dict, "url", label),
                      poster: try PWInAppConfigParser.presentValue(dict, "poster").map { _ in try url(dict, "poster", label) },
                      aspect: try aspect(dict, label) ?? 16 / 9)
    }

    private static func aspect(_ dict: [String: Any], _ label: String) throws -> CGFloat? {
        let aspect = try optionalNumber(dict, "aspect", "\(label).aspect").map { CGFloat($0) }
        if let aspect = aspect, !PWInlineRenderer.aspectRange.contains(aspect) {
            throw Fail.key("\(label).aspect")
        }
        return aspect
    }

    private static func url(_ dict: [String: Any], _ key: String, _ label: String) throws -> URL {
        guard let string = dict[key] as? String, !string.isEmpty, let url = PWInAppConfigParser.resolveURL(string),
              url.scheme != nil else {
            throw Fail.key("\(label).\(key)")
        }
        return url
    }

    private static func button(_ dict: [String: Any], _ dark: [String: Any]?, _ label: String) throws -> PWInlineButton {
        guard let title = dict["title"] as? String, !title.isEmpty else {
            throw Fail.key("\(label).title")
        }
        return PWInlineButton(title: title,
                              color: try themedColor(dict, dark, "color", label),
                              size: try fontSize(dict, label),
                              weight: try optionalEnum(dict, "weight", "\(label).weight", weights) ?? .semibold)
    }

    /// The action of a tap on the banner outside elements with their own; `close` belongs to nodes only.
    private static func bannerAction(_ raw: Any) throws -> PWInlineAction? {
        let action = try self.action(raw, "action")
        if case .close? = action {
            warn("action: close is allowed on nodes only, ignored")
            return nil
        }
        return action
    }

    /// `url` (web page) or `deeplink` with the target in `value`, `close`, `postEvent` (`event`, optional
    /// `attributes`) or `copy` (`text`, optional `toast`). An unknown type is ignored, the banner stays.
    private static func action(_ raw: Any, _ label: String) throws -> PWInlineAction? {
        guard let dict = raw as? [String: Any] else {
            throw Fail.key(label)
        }
        guard let type = dict["type"] as? String else {
            throw Fail.key("\(label).type")
        }
        switch type {
        case "url":
            let url = try self.url(dict, "value", label)
            guard ["http", "https"].contains(url.scheme?.lowercased()) else {
                throw Fail.key("\(label).value")
            }
            return .url(url)
        case "deeplink":
            return .deeplink(try self.url(dict, "value", label))
        case "close":
            return .close
        case "postEvent":
            guard let event = dict["event"] as? String, !event.isEmpty else {
                throw Fail.key("\(label).event")
            }
            let attributes = try PWInAppConfigParser.presentValue(dict, "attributes").map { raw -> [String: Any] in
                guard let attributes = raw as? [String: Any] else {
                    throw Fail.key("\(label).attributes")
                }
                return attributes
            }
            return .postEvent(name: event, attributes: attributes ?? [:])
        case "copy":
            guard let text = dict["text"] as? String, !text.isEmpty else {
                throw Fail.key("\(label).text")
            }
            return .copy(text: text, toast: try optionalString(dict, "toast", "\(label).toast"))
        default:
            warn("\(label): unknown type '\(type)' ignored")
            return nil
        }
    }

    private static func stack(_ dict: [String: Any], _ label: String, depth: Int) throws -> PWInlineStack {
        let layouts: [String: PWInlineStack.Layout] = ["row": .row, "column": .column, "overlay": .overlay]
        let alignments: [String: UIStackView.Alignment] = ["start": .leading, "center": .center, "end": .trailing, "fill": .fill]
        let distributions: [String: UIStackView.Distribution] = ["fill": .fill, "equal": .fillEqually]
        let spacing = try optionalLength(dict, "spacing", "\(label).spacing") ?? 0
        return PWInlineStack(
            layout: try optionalEnum(dict, "axis", "\(label).axis", layouts) ?? .column,
            spacing: CGFloat(spacing),
            alignment: try optionalEnum(dict, "align", "\(label).align", alignments) ?? .fill,
            distribution: try optionalEnum(dict, "distribution", "\(label).distribution", distributions) ?? .fill,
            children: try nodes(dict, "children", label, depth: depth))
    }

    private static func pager(_ dict: [String: Any], _ dark: [String: Any]?, _ label: String, depth: Int) throws -> PWInlinePager {
        let interval = try optionalNumber(dict, "interval", "\(label).interval")
        if let interval = interval, interval < 1 {
            throw Fail.key("\(label).interval")
        }
        return PWInlinePager(pages: try nodes(dict, "pages", label, depth: depth),
                             interval: interval,
                             indicatorColor: try themedColor(dict, dark, "indicatorColor", label))
    }

    private static func nodes(_ dict: [String: Any], _ key: String, _ label: String, depth: Int) throws -> [PWInlineNode] {
        guard let children = dict[key] as? [Any], !children.isEmpty else {
            throw Fail.key("\(label).\(key)")
        }
        return try children.enumerated().map { index, child in
            try node(child, "\(label).\(key)[\(index)]", depth: depth + 1)
        }
    }

    // MARK: - Style

    private static func style(_ dict: [String: Any], _ label: String) throws -> PWInlineStyle {
        var style = PWInlineStyle()
        style.background = try optionalColor(dict, "background", "\(label).background")
        style.cornerRadius = CGFloat(try optionalLength(dict, "cornerRadius", "\(label).cornerRadius") ?? 0)
        if let raw = PWInAppConfigParser.presentValue(dict, "padding") {
            style.padding = try padding(raw, "\(label).padding")
        }
        if let raw = PWInAppConfigParser.presentValue(dict, "gradient") {
            style.gradient = try gradient(raw, "\(label).gradient")
        }
        if PWInAppConfigParser.presentValue(dict, "backgroundImage") != nil {
            style.backgroundImage = try url(dict, "backgroundImage", label)
        }
        if let raw = PWInAppConfigParser.presentValue(dict, "shadow") {
            let shadow = try object(raw, "\(label).shadow")
            let offsets = -maxLength...maxLength
            style.shadow = PWInlineShadow(
                color: try optionalColor(shadow, "color", "\(label).shadow.color") ?? UIColor(white: 0, alpha: 0.2),
                radius: CGFloat(try optionalLength(shadow, "radius", "\(label).shadow.radius") ?? 8),
                offset: CGSize(width: try optionalLength(shadow, "x", "\(label).shadow.x", in: offsets) ?? 0,
                               height: try optionalLength(shadow, "y", "\(label).shadow.y", in: offsets) ?? 4))
        }
        if let raw = PWInAppConfigParser.presentValue(dict, "border") {
            let border = try object(raw, "\(label).border")
            let width = try optionalLength(border, "width", "\(label).border.width") ?? 1
            guard width > 0, let color = try optionalColor(border, "color", "\(label).border.color") else {
                throw Fail.key("\(label).border")
            }
            style.border = PWInlineBorder(color: color, width: CGFloat(width))
        }
        if let raw = PWInAppConfigParser.presentValue(dict, "glass") {
            if let enabled = raw as? NSNumber, PWInAppConfigParser.isBoolean(enabled) {
                style.glass = enabled.boolValue ? PWInlineGlass(tint: nil) : nil
            } else {
                let glass = try object(raw, "\(label).glass")
                style.glass = PWInlineGlass(tint: try optionalColor(glass, "tint", "\(label).glass.tint"))
            }
        }
        return style
    }

    /// `{"colors": ["#RRGGBB", ...], "angle": 90}`: at least two colors, angle in degrees (0 = left to right).
    private static func gradient(_ raw: Any, _ label: String) throws -> PWInlineGradient {
        let dict = try object(raw, label)
        guard let list = dict["colors"] as? [Any], list.count >= 2 else {
            throw Fail.key("\(label).colors")
        }
        let colors = try list.map { item -> UIColor in
            guard let string = item as? String, let color = PWInAppConfigParser.colorValue(string) else {
                throw Fail.key("\(label).colors")
            }
            return color
        }
        return PWInlineGradient(colors: colors, angle: CGFloat(try optionalNumber(dict, "angle", "\(label).angle") ?? 90))
    }

    private static func object(_ raw: Any, _ label: String) throws -> [String: Any] {
        guard let dict = raw as? [String: Any] else {
            throw Fail.key(label)
        }
        return dict
    }

    /// The light color, switching to the `dark` override in dark mode.
    private static func themedColor(_ dict: [String: Any], _ dark: [String: Any]?, _ key: String,
                                    _ label: String) throws -> UIColor? {
        let light = try optionalColor(dict, key, "\(label).\(key)")
        guard let dark = dark, let darkColor = try optionalColor(dark, key, "\(label).dark.\(key)") else {
            return light
        }
        let lightColor = light ?? .label
        return UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor }
    }

    /// `8`, `[vertical, horizontal]` or `[top, right, bottom, left]` (CSS order).
    private static func padding(_ raw: Any, _ label: String) throws -> UIEdgeInsets {
        let values: [Double]
        if let number = raw as? NSNumber {
            values = [try validNumber(number, label)]
        } else if let list = raw as? [Any] {
            values = try list.map { item in
                guard let number = item as? NSNumber else {
                    throw Fail.key(label)
                }
                return try validNumber(number, label)
            }
        } else {
            throw Fail.key(label)
        }
        guard values.allSatisfy({ (0...maxLength).contains($0) }) else {
            throw Fail.key(label)
        }
        let insets = values.map { CGFloat($0) }
        switch insets.count {
        case 1:
            return UIEdgeInsets(top: insets[0], left: insets[0], bottom: insets[0], right: insets[0])
        case 2:
            return UIEdgeInsets(top: insets[0], left: insets[1], bottom: insets[0], right: insets[1])
        case 4:
            return UIEdgeInsets(top: insets[0], left: insets[3], bottom: insets[2], right: insets[1])
        default:
            throw Fail.key(label)
        }
    }

    // MARK: - Values

    /// `nil` when the key is absent or null; a value of another type fails the banner.
    private static func optionalValue<T>(_ dict: [String: Any], _ key: String, _ label: String) throws -> T? {
        guard let raw = PWInAppConfigParser.presentValue(dict, key) else {
            return nil
        }
        guard let value = raw as? T else {
            throw Fail.key(label)
        }
        return value
    }

    private static func validNumber(_ number: NSNumber, _ label: String) throws -> Double {
        guard !PWInAppConfigParser.isBoolean(number), number.doubleValue.isFinite else {
            throw Fail.key(label)
        }
        return number.doubleValue
    }

    private static func optionalNumber(_ dict: [String: Any], _ key: String, _ label: String) throws -> Double? {
        try (optionalValue(dict, key, label) as NSNumber?).map { try validNumber($0, label) }
    }

    /// A length in points; `nil` when absent, outside `range` the banner is dropped.
    private static func optionalLength(_ dict: [String: Any], _ key: String, _ label: String,
                                       in range: ClosedRange<Double> = 0...maxLength) throws -> Double? {
        guard let length = try optionalNumber(dict, key, label) else {
            return nil
        }
        guard range.contains(length) else {
            throw Fail.key(label)
        }
        return length
    }

    private static func optionalInteger(_ dict: [String: Any], _ key: String, _ label: String) throws -> Int? {
        guard let number = try optionalNumber(dict, key, label) else {
            return nil
        }
        guard let integer = Int(exactly: number) else {
            throw Fail.key(label)
        }
        return integer
    }

    private static func optionalString(_ dict: [String: Any], _ key: String, _ label: String) throws -> String? {
        try optionalValue(dict, key, label)
    }

    private static func optionalBool(_ dict: [String: Any], _ key: String, _ label: String) throws -> Bool? {
        guard let number: NSNumber = try optionalValue(dict, key, label) else {
            return nil
        }
        guard PWInAppConfigParser.isBoolean(number) else {
            throw Fail.key(label)
        }
        return number.boolValue
    }

    private static func optionalEnum<T>(_ dict: [String: Any], _ key: String, _ label: String,
                                        _ values: [String: T]) throws -> T? {
        guard let string = try optionalString(dict, key, label) else {
            return nil
        }
        guard let value = values[string] else {
            throw Fail.key(label)
        }
        return value
    }

    private static func optionalColor(_ dict: [String: Any], _ key: String, _ label: String) throws -> UIColor? {
        guard let string = try optionalString(dict, key, label) else {
            return nil
        }
        guard let color = PWInAppConfigParser.colorValue(string) else {
            throw Fail.key(label)
        }
        return color
    }

    private static func warn(_ message: String) {
        PushwooshLog.pushwooshLog(.PW_LL_WARN, className: "PWInlineParser", message: message)
    }
}
#endif
