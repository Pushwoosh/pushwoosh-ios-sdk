//
//  PWInAppConfigParser.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import PushwooshCore

/// Decodes the raw config dictionary (`native-config.json` from a resource ZIP)
/// into a typed `PWInAppMessageModel`.
///
/// Implements the editor contract (`NativeRichMediaPreview/types.ts`, repo copy:
/// `llm/docs/native-rich-media-config.md`) in **fail-closed** mode, mirroring
/// Android's `typed-config-contract` spec: a config is invalid — the in-app is
/// not shown and the failing key is logged — when the `displayType` is unknown,
/// the same-name block is missing, a required array is empty, or any known
/// field is missing or of the wrong type. There are no coercions: `"5"` is not
/// a number, `"true"` is not a bool, enum values outside their set are invalid,
/// colors are CSS hex (`#RGB`/`#RGBA`/`#RRGGBB`/`#RRGGBBAA`, `#` required).
/// Unknown keys are ignored on every level (forward-compat).
///
/// The root envelope (`inAppId`, `maxDisplays`, `cooldown`, `expireDate`, `ttl`)
/// is a deliberate extension over the contract (delivery is configured outside
/// rich media) and keeps its tolerant parsing — numbers may arrive as strings.
enum PWInAppConfigParser {

    private enum Fail: Error {
        case key(String)
    }

    static func parse(_ config: [AnyHashable: Any]) -> PWInAppMessageModel? {
        guard let displayType = config["displayType"] as? String else {
            return warnAndDrop("displayType")
        }

        let id = envelopeString(config["inAppId"])
        let maxDisplays = envelopeNumber(config["maxDisplays"])?.intValue
        let cooldown = envelopeNumber(config["cooldown"])?.doubleValue
        let expireDate: Date? = {
            if let timestamp = envelopeNumber(config["expireDate"])?.doubleValue {
                return Date(timeIntervalSince1970: timestamp)
            }
            if let ttl = envelopeNumber(config["ttl"])?.doubleValue, ttl > 0 {
                return Date(timeIntervalSinceNow: ttl)
            }
            return nil
        }()

        do {
            let layout: PWInAppLayout
            switch displayType.lowercased() {
            case "modal":
                layout = .modal(try parseModal(try block(config, "modal")))
            case "sheet":
                layout = .sheet(try parseSheet(try block(config, "sheet")))
            case "carousel":
                layout = .carousel(try parseCarousel(try block(config, "carousel")))
            case "stories":
                layout = .stories(try parseStories(try block(config, "stories")))
            case "banner":
                layout = .banner(try parseBanner(try block(config, "banner")))
            case "fullscreen":
                layout = .fullscreen(try parseFullscreen(try block(config, "fullscreen")))
            case "video":
                layout = .video(try parseVideo(try block(config, "video")))
            case "pip":
                layout = .pip(try parsePip(try block(config, "pip")))
            case "scratchcard":
                layout = .scratchCard(try parseScratchCard(try block(config, "scratchcard")))
            case "spinwheel":
                layout = .spinWheel(try parseSpinWheel(try block(config, "spinwheel")))
            default:
                return warnAndDrop("displayType \"\(displayType)\"")
            }
            return PWInAppMessageModel(id: id, layout: layout,
                                       maxDisplays: maxDisplays, cooldown: cooldown, expireDate: expireDate)
        } catch Fail.key(let key) {
            return warnAndDrop(key)
        } catch {
            return warnAndDrop("unexpected")
        }
    }

    private static func warnAndDrop(_ key: String) -> PWInAppMessageModel? {
        PushwooshLog.pushwooshLog(.PW_LL_WARN, className: "PWInAppConfigParser",
                                  message: "Invalid native in-app config, dropped at: \(key)")
        return nil
    }

    // MARK: - Layouts

    private static func parseModal(_ dict: [AnyHashable: Any]) throws -> PWInAppModalContent {
        PWInAppModalContent(
            backgroundColor: try color(dict, "background", "modal.background"),
            title: try optionalText(dict, "title", "modal.title"),
            message: try optionalText(dict, "message", "modal.message"),
            imageURL: try optionalURL(dict, "image", "modal.image"),
            showCloseButton: try bool(dict, "showClose", "modal.showClose"),
            buttons: try buttons(dict, "modal.buttons"),
            dimsBackground: try bool(dict, "dimBackground", "modal.dimBackground")
        )
    }

    private static func parseSheet(_ dict: [AnyHashable: Any]) throws -> PWInAppSheetContent {
        PWInAppSheetContent(
            backgroundColor: try color(dict, "background", "sheet.background"),
            title: try optionalText(dict, "title", "sheet.title"),
            message: try optionalText(dict, "message", "sheet.message"),
            imageURL: try optionalURL(dict, "image", "sheet.image"),
            showCloseButton: try bool(dict, "showClose", "sheet.showClose"),
            buttons: try buttons(dict, "sheet.buttons"),
            dimsBackground: try bool(dict, "dimBackground", "sheet.dimBackground")
        )
    }

    private static func parseCarousel(_ dict: [AnyHashable: Any]) throws -> PWInAppCarouselContent {
        let showClose = try bool(dict, "showClose", "carousel.showClose")
        guard let rawItems = dict["items"] as? [[AnyHashable: Any]], !rawItems.isEmpty else {
            throw Fail.key("carousel.items")
        }
        let items = try rawItems.enumerated().map { index, item in
            PWInAppCarouselItem(
                imageURL: try optionalURL(item, "image", "carousel.items[\(index)].image"),
                title: try optionalText(item, "title", "carousel.items[\(index)].title"),
                subtitle: try optionalText(item, "message", "carousel.items[\(index)].message"),
                action: try optionalAction(item, "action", "carousel.items[\(index)].action")
            )
        }
        return PWInAppCarouselContent(items: items, showCloseButton: showClose)
    }

    private static func parseStories(_ dict: [AnyHashable: Any]) throws -> PWInAppStoriesContent {
        let showClose = try bool(dict, "showClose", "stories.showClose")
        let loops = try bool(dict, "loop", "stories.loop")
        guard let rawItems = dict["items"] as? [[AnyHashable: Any]], !rawItems.isEmpty else {
            throw Fail.key("stories.items")
        }
        let items = try rawItems.enumerated().map { index, item -> PWInAppStoryItem in
            let label = "stories.items[\(index)]"
            let rawDuration = try number(item, "duration", "\(label).duration")
            guard rawDuration.isFinite, rawDuration > 0 else {
                throw Fail.key("\(label).duration")
            }
            return PWInAppStoryItem(
                imageURL: try optionalURL(item, "image", "\(label).image"),
                title: try optionalText(item, "title", "\(label).title"),
                subtitle: try optionalText(item, "message", "\(label).message"),
                buttons: try buttons(item, "\(label).buttons"),
                duration: min(rawDuration, PWInAppStoryItem.maxDuration)
            )
        }
        return PWInAppStoriesContent(items: items, loops: loops, showCloseButton: showClose)
    }

    private static func parseBanner(_ dict: [AnyHashable: Any]) throws -> PWInAppBannerContent {
        let position: PWInAppBannerContent.Position
        switch try string(dict, "position", "banner.position").lowercased() {
        case "top":
            position = .top
        case "bottom":
            position = .bottom
        default:
            throw Fail.key("banner.position")
        }

        let autoDismiss: TimeInterval
        if presentValue(dict, "autoDismiss") != nil {
            let value = try number(dict, "autoDismiss", "banner.autoDismiss")
            guard value.isFinite, value > 0 else {
                throw Fail.key("banner.autoDismiss")
            }
            autoDismiss = value
        } else {
            autoDismiss = 0
        }

        return PWInAppBannerContent(
            position: position,
            imageURL: try optionalURL(dict, "image", "banner.image"),
            title: try optionalText(dict, "title", "banner.title"),
            message: try optionalText(dict, "message", "banner.message"),
            backgroundColor: try color(dict, "background", "banner.background"),
            action: try action(dict["action"], "banner.action"),
            autoDismiss: autoDismiss,
            showCloseButton: try bool(dict, "showClose", "banner.showClose")
        )
    }

    private static func parseFullscreen(_ dict: [AnyHashable: Any]) throws -> PWInAppFullscreenContent {
        let cover = try self.cover(dict["cover"], "fullscreen.cover")
        return PWInAppFullscreenContent(
            imageURL: cover.imageURL,
            backgroundColor: cover.background,
            title: try optionalText(dict, "title", "fullscreen.title"),
            message: try optionalText(dict, "message", "fullscreen.message"),
            buttons: try buttons(dict, "fullscreen.buttons"),
            showCloseButton: try bool(dict, "showClose", "fullscreen.showClose")
        )
    }

    private static func parseVideo(_ dict: [AnyHashable: Any]) throws -> PWInAppVideoContent {
        PWInAppVideoContent(
            videoURL: try url(dict, "url", "video.url"),
            posterURL: try optionalURL(dict, "poster", "video.poster"),
            fallbackImageURL: try optionalURL(dict, "fallback", "video.fallback"),
            title: try optionalText(dict, "title", "video.title"),
            message: try optionalText(dict, "message", "video.message"),
            buttons: try buttons(dict, "video.buttons"),
            loop: try bool(dict, "loop", "video.loop"),
            muted: try bool(dict, "muted", "video.muted"),
            showCloseButton: try bool(dict, "showClose", "video.showClose")
        )
    }

    private static func parsePip(_ dict: [AnyHashable: Any]) throws -> PWInAppPipContent {
        let position: PWInAppPipPosition
        switch try string(dict, "position", "pip.position").lowercased() {
        case "top-left":
            position = .topLeft
        case "top-right":
            position = .topRight
        case "bottom-left":
            position = .bottomLeft
        case "bottom-right":
            position = .bottomRight
        default:
            throw Fail.key("pip.position")
        }

        // Contract: percent of the screen width clamped 15–70; values ≤ 1 are a fraction.
        let rawWidth = try number(dict, "width", "pip.width")
        guard rawWidth.isFinite, rawWidth > 0 else {
            throw Fail.key("pip.width")
        }
        let widthFraction = CGFloat(min(max(rawWidth > 1 ? rawWidth / 100 : rawWidth, 0.15), 0.7))

        let aspectRatio = try number(dict, "aspectRatio", "pip.aspectRatio")
        guard aspectRatio.isFinite, aspectRatio > 0 else {
            throw Fail.key("pip.aspectRatio")
        }

        let cornerRadius: CGFloat
        if presentValue(dict, "borderRadius") != nil {
            let rawRadius = try number(dict, "borderRadius", "pip.borderRadius")
            guard rawRadius.isFinite, rawRadius >= 0 else { throw Fail.key("pip.borderRadius") }
            cornerRadius = CGFloat(rawRadius)
        } else {
            cornerRadius = 16
        }

        return PWInAppPipContent(
            videoURL: try url(dict, "url", "pip.url"),
            posterURL: try optionalURL(dict, "poster", "pip.poster"),
            fallbackImageURL: try optionalURL(dict, "fallback", "pip.fallback"),
            position: position,
            widthFraction: widthFraction,
            aspectRatio: CGFloat(aspectRatio),
            cornerRadius: cornerRadius,
            loop: try bool(dict, "loop", "pip.loop"),
            muted: try bool(dict, "muted", "pip.muted"),
            action: try optionalAction(dict, "action", "pip.action"),
            showCloseButton: try bool(dict, "showClose", "pip.showClose")
        )
    }

    private static func parseScratchCard(_ dict: [AnyHashable: Any]) throws -> PWInAppScratchCardContent {
        let threshold = try number(dict, "revealThreshold", "scratchcard.revealThreshold")
        guard threshold.isFinite, threshold > 0, threshold <= 1 else {
            throw Fail.key("scratchcard.revealThreshold")
        }
        let cover = try self.cover(dict["cover"], "scratchcard.cover")
        let background = try surfaceBackground(dict, "scratchcard.background")
        return PWInAppScratchCardContent(
            backgroundColor: background.solid,
            backgroundGradient: background.gradient,
            title: try optionalText(dict, "title", "scratchcard.title"),
            message: try optionalText(dict, "message", "scratchcard.message"),
            coverImageURL: cover.imageURL,
            coverColor: cover.background,
            revealThreshold: min(max(CGFloat(threshold), 0.1), 0.9),
            revealButton: try optionalActionlessButton(dict, "revealButton", "scratchcard.revealButton"),
            reward: try reward(dict["reward"], "scratchcard.reward"),
            showCloseButton: try bool(dict, "showClose", "scratchcard.showClose")
        )
    }

    private static func parseSpinWheel(_ dict: [AnyHashable: Any]) throws -> PWInAppSpinWheelContent {
        guard let rawSegments = dict["segments"] as? [[AnyHashable: Any]] else {
            throw Fail.key("spinwheel.segments")
        }
        guard (2...12).contains(rawSegments.count) else {
            throw Fail.key("spinwheel.segments (2–12)")
        }
        let segments = try rawSegments.enumerated().map { index, segment -> PWInAppWheelSegment in
            let label = "spinwheel.segments[\(index)]"
            let message = try text(segment["message"], "\(label).message")
            let weight = try number(segment, "weight", "\(label).weight")
            guard weight.isFinite, weight >= 0 else {
                throw Fail.key("\(label).weight")
            }
            return PWInAppWheelSegment(
                text: message.text,
                color: try optionalColor(segment, "color", "\(label).color"),
                textColor: message.color,
                weight: weight,
                reward: try optionalReward(segment, "reward", "\(label).reward")
            )
        }

        let rawWinIndex = try number(dict, "winIndex", "spinwheel.winIndex")
        guard rawWinIndex.isFinite else {
            throw Fail.key("spinwheel.winIndex")
        }
        let winIndex = Int(min(max(rawWinIndex, 0), Double(segments.count - 1)))

        let background = try surfaceBackground(dict, "spinwheel.background")
        return PWInAppSpinWheelContent(
            backgroundColor: background.solid,
            backgroundGradient: background.gradient,
            title: try optionalText(dict, "title", "spinwheel.title"),
            message: try optionalText(dict, "message", "spinwheel.message"),
            segments: segments,
            winIndex: winIndex,
            spinButton: try actionlessButton(dict["spinButton"], "spinwheel.spinButton"),
            reward: try reward(dict["reward"], "spinwheel.reward"),
            loseTitle: try optionalText(dict, "loseTitle", "spinwheel.loseTitle"),
            showCloseButton: try bool(dict, "showClose", "spinwheel.showClose")
        )
    }

    // MARK: - Sub-types

    private static func block(_ config: [AnyHashable: Any], _ key: String) throws -> [AnyHashable: Any] {
        guard let dict = config[key] as? [AnyHashable: Any] else {
            throw Fail.key(key)
        }
        return dict
    }

    private static func text(_ raw: Any?, _ label: String) throws -> PWInAppText {
        guard let dict = raw as? [AnyHashable: Any], let value = dict["text"] as? String, !value.isEmpty else {
            throw Fail.key("\(label).text")
        }
        guard let color = colorValue(dict["color"]) else {
            throw Fail.key("\(label).color")
        }
        return PWInAppText(text: value, color: color)
    }

    /// A key counts as absent when it is missing OR carries an explicit JSON null
    /// (`NSNull`, how NSJSONSerialization decodes `null`). Optional fields must treat
    /// null as "no value" — the same as an omitted key — instead of fail-closing the
    /// whole config on it (parity with Android's `isNull` handling).
    private static func presentValue(_ dict: [AnyHashable: Any], _ key: String) -> Any? {
        guard let value = dict[key], !(value is NSNull) else {
            return nil
        }
        return value
    }

    private static func optionalText(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> PWInAppText? {
        guard let raw = presentValue(dict, key) else {
            return nil
        }
        return try text(raw, label)
    }

    private static func action(_ raw: Any?, _ label: String) throws -> PWInAppAction {
        guard let dict = raw as? [AnyHashable: Any], let type = dict["type"] as? String else {
            throw Fail.key("\(label).type")
        }
        switch type.lowercased() {
        case "close":
            return .close
        case "url":
            guard let urlString = dict["url"] as? String, !urlString.isEmpty,
                  let url = resolveURL(urlString) else {
                throw Fail.key("\(label).url")
            }
            return .url(url)
        default:
            throw Fail.key("\(label).type")
        }
    }

    private static func optionalAction(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> PWInAppAction? {
        guard let raw = presentValue(dict, key) else {
            return nil
        }
        return try action(raw, label)
    }

    private static func button(_ raw: Any?, _ label: String, requiresAction: Bool) throws -> PWInAppButton {
        guard let dict = raw as? [AnyHashable: Any] else {
            throw Fail.key(label)
        }
        let text = try self.text(dict["text"], "\(label).text")
        guard let background = colorValue(dict["background"]) else {
            throw Fail.key("\(label).background")
        }
        guard let border = dict["border"] as? [AnyHashable: Any] else {
            throw Fail.key("\(label).border")
        }
        guard let borderColor = colorValue(border["color"]) else {
            throw Fail.key("\(label).border.color")
        }
        guard let radius = border["radius"] as? NSNumber, !isBoolean(radius),
              radius.doubleValue.isFinite, radius.doubleValue >= 0 else {
            throw Fail.key("\(label).border.radius")
        }
        let action: PWInAppAction = requiresAction ? try self.action(dict["action"], "\(label).action") : .close
        return PWInAppButton(
            text: text,
            backgroundColor: background,
            borderColor: borderColor,
            cornerRadius: CGFloat(radius.doubleValue),
            action: action
        )
    }

    private static func buttons(_ dict: [AnyHashable: Any], _ label: String) throws -> [PWInAppButton] {
        guard let raw = dict["buttons"] as? [Any] else {
            throw Fail.key(label)
        }
        return try raw.enumerated().map { index, element in
            try button(element, "\(label)[\(index)]", requiresAction: true)
        }
    }

    private static func actionlessButton(_ raw: Any?, _ label: String) throws -> PWInAppButton {
        try button(raw, label, requiresAction: false)
    }

    private static func optionalActionlessButton(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> PWInAppButton? {
        guard let raw = presentValue(dict, key) else {
            return nil
        }
        return try actionlessButton(raw, label)
    }

    private static func cover(_ raw: Any?, _ label: String) throws -> (imageURL: URL?, background: UIColor) {
        guard let dict = raw as? [AnyHashable: Any] else {
            throw Fail.key(label)
        }
        guard let background = colorValue(dict["background"]) else {
            throw Fail.key("\(label).background")
        }
        return (try optionalURL(dict, "image", "\(label).image"), background)
    }

    private static func reward(_ raw: Any?, _ label: String) throws -> PWInAppReward {
        guard let dict = raw as? [AnyHashable: Any] else {
            throw Fail.key(label)
        }
        let title = try optionalText(dict, "title", "\(label).title")
        var promoCode: String?
        if let rawCode = presentValue(dict, "code") {
            guard let code = rawCode as? String else {
                throw Fail.key("\(label).code")
            }
            promoCode = code.isEmpty ? nil : code
        }
        guard title != nil || promoCode != nil else {
            throw Fail.key("\(label) (title|code)")
        }
        var button: PWInAppButton?
        if let rawButton = presentValue(dict, "button") {
            button = try self.button(rawButton, "\(label).button", requiresAction: true)
        }
        return PWInAppReward(
            title: title,
            message: try optionalText(dict, "message", "\(label).message"),
            promoCode: promoCode,
            button: button
        )
    }

    private static func optionalReward(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> PWInAppReward? {
        guard let raw = presentValue(dict, key) else {
            return nil
        }
        return try reward(raw, label)
    }

    /// Scratchcard/spinwheel `background`: a single color or gradient stops.
    private static func surfaceBackground(_ dict: [AnyHashable: Any], _ label: String) throws -> (solid: UIColor?, gradient: [UIColor]?) {
        let raw = dict["background"]
        if let string = raw as? String {
            guard let color = colorValue(string) else {
                throw Fail.key(label)
            }
            return (color, nil)
        }
        if let array = raw as? [String], !array.isEmpty {
            let colors = try array.enumerated().map { index, element -> UIColor in
                guard let color = colorValue(element) else {
                    throw Fail.key("\(label)[\(index)]")
                }
                return color
            }
            return (colors.first, colors.count >= 2 ? colors : nil)
        }
        throw Fail.key(label)
    }

    // MARK: - Strict primitives

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func bool(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> Bool {
        guard let number = dict[key] as? NSNumber, isBoolean(number) else {
            throw Fail.key(label)
        }
        return number.boolValue
    }

    private static func number(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> Double {
        guard let number = dict[key] as? NSNumber, !isBoolean(number) else {
            throw Fail.key(label)
        }
        return number.doubleValue
    }

    private static func string(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> String {
        guard let value = dict[key] as? String else {
            throw Fail.key(label)
        }
        return value
    }

    private static func colorValue(_ raw: Any?) -> UIColor? {
        guard let string = raw as? String, string.hasPrefix("#") else {
            return nil
        }
        return UIColor.pw_fromHex(string)
    }

    private static func color(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> UIColor {
        guard let value = colorValue(dict[key]) else {
            throw Fail.key(label)
        }
        return value
    }

    private static func optionalColor(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> UIColor? {
        guard presentValue(dict, key) != nil else {
            return nil
        }
        return try color(dict, key, label)
    }

    private static func url(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> URL {
        guard let value = try optionalURL(dict, key, label) else {
            throw Fail.key(label)
        }
        return value
    }

    private static func optionalURL(_ dict: [AnyHashable: Any], _ key: String, _ label: String) throws -> URL? {
        guard let raw = presentValue(dict, key) else {
            return nil
        }
        guard let string = raw as? String, !string.isEmpty else {
            throw Fail.key(label)
        }
        // A present non-empty value that does not parse as a URL yields nil rather than
        // dropping the whole config (Android parity: a bad image URL leaves the asset
        // empty, it does not invalidate the message). Required media (video/pip url) still
        // fails, because url() rejects a nil result.
        return resolveURL(string)
    }

    /// Recovers a link the editor let through (a space, a custom scheme) instead of dropping the
    /// message. `%` stays allowed so an existing `%XX` escape is not encoded a second time.
    private static func resolveURL(_ string: String) -> URL? {
        if let url = URL(string: string) {
            return url
        }
        let allowed = CharacterSet.urlFragmentAllowed.union(CharacterSet(charactersIn: "%"))
        guard let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: encoded)
    }

    /// Envelope numbers keep the pre-contract tolerance: a JSON number or a
    /// stringified one ("5") — dashboards sometimes deliver scalars as strings.
    /// Booleans (a JSON `true` is an NSNumber) and non-finite values (nan/inf)
    /// are treated as absent, not coerced.
    private static func envelopeNumber(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber, !isBoolean(number), number.doubleValue.isFinite {
            return number
        }
        if let string = value as? String, let double = Double(string), double.isFinite {
            return NSNumber(value: double)
        }
        return nil
    }

    private static func envelopeString(_ value: Any?) -> String? {
        if let string = value as? String {
            return string.isEmpty ? nil : string
        }
        if let number = value as? NSNumber, !isBoolean(number) {
            return number.stringValue
        }
        return nil
    }
}
#endif
