//
//  PWTVOSUniversalHTMLParser.swift
//  PushwooshTVOS
//
//  Created by André Kis on 14.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@available(tvOS 11.0, *)
class PWTVOSUniversalHTMLParser {

    enum RichMediaElement {
        case image(url: String, styles: ElementStyles)
        case heading(text: String, level: Int, styles: ElementStyles)
        case text(text: String, styles: ElementStyles)
        case textField(placeholder: String, fieldName: String, styles: ElementStyles)
        case button(text: String, action: ButtonAction, styles: ElementStyles)
        case container(children: [RichMediaElement], styles: ElementStyles)
    }

    struct ElementStyles {
        var color: UIColor?
        var backgroundColor: UIColor?
        var fontSize: CGFloat = 20
        var textAlign: NSTextAlignment = .left
        var padding: UIEdgeInsets = .zero
        var margin: UIEdgeInsets = .zero
        var borderColor: UIColor?
        var borderWidth: CGFloat = 0
        var borderRadius: CGFloat = 0
        var width: CGFloat?
        var height: CGFloat?
        var flex: CGFloat?
        var display: DisplayType = .block
        var flexDirection: FlexDirection = .column
        var gap: CGFloat = 0
    }

    enum DisplayType {
        case block
        case flex
    }

    enum FlexDirection {
        case row
        case column
    }

    enum ButtonAction {
        case close
        case openSettings
        case postEvent(name: String, attributes: [String: Any]?)
        case sendTags(tags: [String: Any])
        case getTags
        case setEmail(email: String)
        case getHwid
        case getVersion
        case getApplication
        case getUserId
        case getRichmediaCode
        case getDeviceType
        case getMessageHash
        case getInAppCode
        case none
    }

    func parseHTML(_ html: String, localization: [String: Any]?) -> [RichMediaElement] {
        let processedHTML = processPlaceholders(in: html, localization: localization)

        guard let bodyContent = extractBody(from: processedHTML) else {
            return []
        }

        return parseElement(html: bodyContent, parentStyles: nil)
    }

    private func extractBody(from html: String) -> String? {
        if let bodyStart = html.range(of: "<body", options: .caseInsensitive),
           let bodyTagEnd = html[bodyStart.lowerBound...].range(of: ">") {
            let afterBodyTag = html[bodyTagEnd.upperBound...]

            if let bodyEnd = afterBodyTag.range(of: "</body>", options: .caseInsensitive) {
                return String(afterBodyTag[..<bodyEnd.lowerBound])
            }
            return String(afterBodyTag)
        }

        return html
    }

    private func skipTag(in html: String, from currentIndex: String.Index) -> String.Index {
        if let tagEnd = html[currentIndex...].range(of: ">") {
            return tagEnd.upperBound
        }
        return html.index(after: currentIndex)
    }

    private func parseElement(html: String, parentStyles: ElementStyles?) -> [RichMediaElement] {
        var elements: [RichMediaElement] = []
        var currentIndex = html.startIndex

        while currentIndex < html.endIndex {
            let remaining = html[currentIndex...]

            if remaining.hasPrefix("<img") {
                if let (element, endIndex) = parseImageTag(from: html, startIndex: currentIndex) {
                    elements.append(element)
                    currentIndex = endIndex
                } else {
                    currentIndex = skipTag(in: html, from: currentIndex)
                }
            } else if remaining.hasPrefix("<h1") || remaining.hasPrefix("<h2") || remaining.hasPrefix("<h3") ||
                      remaining.hasPrefix("<h4") || remaining.hasPrefix("<h5") || remaining.hasPrefix("<h6") {
                if let (element, endIndex) = parseHeadingTag(from: html, startIndex: currentIndex) {
                    elements.append(element)
                    currentIndex = endIndex
                } else {
                    currentIndex = skipTag(in: html, from: currentIndex)
                }
            } else if remaining.hasPrefix("<p") || remaining.hasPrefix("<span") {
                if let (element, endIndex) = parseTextTag(from: html, startIndex: currentIndex, parentStyles: parentStyles) {
                    elements.append(element)
                    currentIndex = endIndex
                } else {
                    currentIndex = skipTag(in: html, from: currentIndex)
                }
            } else if remaining.hasPrefix("<input") {
                if let (element, endIndex) = parseInputTag(from: html, startIndex: currentIndex) {
                    elements.append(element)
                    currentIndex = endIndex
                } else {
                    currentIndex = skipTag(in: html, from: currentIndex)
                }
            } else if remaining.hasPrefix("<a") || remaining.hasPrefix("<button") {
                if let (element, endIndex) = parseButtonTag(from: html, startIndex: currentIndex) {
                    elements.append(element)
                    currentIndex = endIndex
                } else {
                    currentIndex = skipTag(in: html, from: currentIndex)
                }
            } else if remaining.hasPrefix("<div") {
                if let (element, endIndex) = parseDivTag(from: html, startIndex: currentIndex, parentStyles: parentStyles) {
                    if case .container(let children, let styles) = element {
                        let hasPadding = styles.padding.top > 0 || styles.padding.left > 0 ||
                                        styles.padding.bottom > 0 || styles.padding.right > 0
                        let hasContent = !children.isEmpty ||
                                        styles.backgroundColor != nil ||
                                        hasPadding ||
                                        styles.borderRadius > 0
                        if hasContent {
                            elements.append(element)
                        }
                    } else {
                        elements.append(element)
                    }
                    currentIndex = endIndex
                } else {
                    currentIndex = skipTag(in: html, from: currentIndex)
                }
            } else {
                currentIndex = html.index(after: currentIndex)
            }
        }

        return elements
    }

    private func parseImageTag(from html: String, startIndex: String.Index) -> (RichMediaElement, String.Index)? {
        guard let tagEnd = html[startIndex...].range(of: ">") else { return nil }

        let tagContent = String(html[startIndex..<tagEnd.upperBound])

        guard let src = extractAttribute(from: tagContent, attribute: "src") else {
            return nil
        }

        let styles = extractStyles(from: tagContent)

        return (.image(url: src, styles: styles), tagEnd.upperBound)
    }

    private func parseHeadingTag(from html: String, startIndex: String.Index) -> (RichMediaElement, String.Index)? {
        let tag = String(html[startIndex...].prefix(3))
        let level = Int(String(tag.last!)) ?? 1
        let closingTag = "</h\(level)>"

        guard let tagEnd = html[startIndex...].range(of: ">"),
              let closingTagRange = html[tagEnd.upperBound...].range(of: closingTag, options: .caseInsensitive) else {
            return nil
        }

        let tagContent = String(html[startIndex..<tagEnd.upperBound])
        let textContent = String(html[tagEnd.upperBound..<closingTagRange.lowerBound])
        let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)

        let styles = extractStyles(from: tagContent)

        return (.heading(text: text, level: level, styles: styles), closingTagRange.upperBound)
    }

    private func parseTextTag(from html: String, startIndex: String.Index, parentStyles: ElementStyles?) -> (RichMediaElement, String.Index)? {
        let tagName = html[startIndex...].hasPrefix("<p") ? "p" : "span"
        let closingTag = "</\(tagName)>"

        guard let tagEnd = html[startIndex...].range(of: ">"),
              let closingTagRange = html[tagEnd.upperBound...].range(of: closingTag, options: .caseInsensitive) else {
            return nil
        }

        let tagContent = String(html[startIndex..<tagEnd.upperBound])
        let textContent = String(html[tagEnd.upperBound..<closingTagRange.lowerBound])
        let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return nil
        }

        var styles = extractStyles(from: tagContent)

        if let parentStyles = parentStyles {
            let hasOwnTextAlign = extractStyleValue(from: tagContent, property: "text-align") != nil
            if !hasOwnTextAlign {
                styles.textAlign = parentStyles.textAlign
            }

            if styles.fontSize == 20 && parentStyles.fontSize != 20 {
                styles.fontSize = parentStyles.fontSize
            }

            if styles.color == nil && parentStyles.color != nil {
                styles.color = parentStyles.color
            }
        }

        return (.text(text: text, styles: styles), closingTagRange.upperBound)
    }

    private func parseInputTag(from html: String, startIndex: String.Index) -> (RichMediaElement, String.Index)? {
        guard let tagEnd = html[startIndex...].range(of: ">") else { return nil }

        let tagContent = String(html[startIndex..<tagEnd.upperBound])

        let placeholder = extractAttribute(from: tagContent, attribute: "placeholder") ?? ""
        let fieldName = extractDataAttribute(from: tagContent, attribute: "data-field-name") ?? "field"

        let styles = extractStyles(from: tagContent)

        return (.textField(placeholder: placeholder, fieldName: fieldName, styles: styles), tagEnd.upperBound)
    }

    private func parseButtonTag(from html: String, startIndex: String.Index) -> (RichMediaElement, String.Index)? {
        let isAnchor = html[startIndex...].hasPrefix("<a")
        let tagName = isAnchor ? "a" : "button"
        let closingTag = "</\(tagName)>"

        guard let tagEnd = html[startIndex...].range(of: ">"),
              let closingTagRange = html[tagEnd.upperBound...].range(of: closingTag, options: .caseInsensitive) else {
            return nil
        }

        let tagContent = String(html[startIndex..<tagEnd.upperBound])
        let textContent = String(html[tagEnd.upperBound..<closingTagRange.lowerBound])
        let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return nil
        }

        let action = extractButtonAction(from: tagContent)
        let styles = extractStyles(from: tagContent)

        return (.button(text: text, action: action, styles: styles), closingTagRange.upperBound)
    }

    private func parseDivTag(from html: String, startIndex: String.Index, parentStyles: ElementStyles?) -> (RichMediaElement, String.Index)? {
        guard let tagEnd = html[startIndex...].range(of: ">") else { return nil }

        let tagContent = String(html[startIndex..<tagEnd.upperBound])

        guard let closingIndex = findClosingTag(in: html, startIndex: tagEnd.upperBound, tagName: "div") else {
            return nil
        }

        let innerContent = String(html[tagEnd.upperBound..<closingIndex])

        let styles = extractStyles(from: tagContent)
        let children = parseElement(html: innerContent, parentStyles: styles)

        return (.container(children: children, styles: styles), closingIndex)
    }

    private func findClosingTag(in html: String, startIndex: String.Index, tagName: String) -> String.Index? {
        var depth = 1
        var currentIndex = startIndex
        let openTag = "<\(tagName)"
        let closeTag = "</\(tagName)>"

        while currentIndex < html.endIndex && depth > 0 {
            let remaining = html[currentIndex...]

            if remaining.hasPrefix(openTag) {
                depth += 1
                currentIndex = html.index(currentIndex, offsetBy: openTag.count, limitedBy: html.endIndex) ?? html.endIndex
            } else if remaining.hasPrefix(closeTag) {
                depth -= 1
                if depth == 0 {
                    return html.index(currentIndex, offsetBy: closeTag.count, limitedBy: html.endIndex) ?? html.endIndex
                }
                currentIndex = html.index(currentIndex, offsetBy: closeTag.count, limitedBy: html.endIndex) ?? html.endIndex
            } else {
                currentIndex = html.index(after: currentIndex)
            }
        }

        return nil
    }

    private func extractButtonAction(from html: String) -> ButtonAction {
        if let onclick = extractAttribute(from: html, attribute: "onclick") {
            let jsParser = PWTVOSJavaScriptParser()
            let jsCall = jsParser.parseJavaScriptCall(onclick)

            switch jsCall {
            case .postEvent(let name, let attributes):
                return .postEvent(name: name, attributes: attributes)
            case .sendTags(let tags):
                return .sendTags(tags: tags)
            case .getTags:
                return .getTags
            case .setEmail(let email):
                return .setEmail(email: email)
            case .closeInApp:
                return .close
            case .openAppSettings:
                return .openSettings
            case .getHwid:
                return .getHwid
            case .getVersion:
                return .getVersion
            case .getApplication:
                return .getApplication
            case .getUserId:
                return .getUserId
            case .getRichmediaCode:
                return .getRichmediaCode
            case .getDeviceType:
                return .getDeviceType
            case .getMessageHash:
                return .getMessageHash
            case .getInAppCode:
                return .getInAppCode
            case .registerForPushNotifications, .unregisterForPushNotifications:
                return .none
            case .unknown:
                break
            }
        }

        if html.contains("closeInApp()") {
            return .close
        }

        if let dataAction = extractDataAttribute(from: html, attribute: "data-action") {
            switch dataAction.lowercased() {
            case "opensettings":
                return .openSettings
            case "sendtags":
                if let tagsStr = extractDataAttribute(from: html, attribute: "data-tags"),
                   let data = tagsStr.data(using: .utf8),
                   let tags = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return .sendTags(tags: tags)
                }
            case "gettags":
                return .getTags
            default:
                break
            }
        }

        if let eventName = extractDataAttribute(from: html, attribute: "data-event") {
            var eventAttributes: [String: Any]?
            if let attributesStr = extractDataAttribute(from: html, attribute: "data-attributes"),
               let data = attributesStr.data(using: .utf8),
               let attributes = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                eventAttributes = attributes
            }
            return .postEvent(name: eventName, attributes: eventAttributes)
        }

        return .none
    }

    private func extractStyles(from html: String) -> ElementStyles {
        var styles = ElementStyles()

        guard let styleAttr = extractAttribute(from: html, attribute: "style") else {
            return styles
        }

        if let color = extractStyleValue(from: styleAttr, property: "color") {
            styles.color = parseColor(color)
        }

        if let bgColor = extractStyleValue(from: styleAttr, property: "background-color") {
            styles.backgroundColor = parseColor(bgColor)
        } else if let background = extractStyleValue(from: styleAttr, property: "background") {
            if let color = extractColorFromBackground(background) {
                styles.backgroundColor = parseColor(color)
            }
        }

        if let fontSize = extractStyleValue(from: styleAttr, property: "font-size") {
            styles.fontSize = parseFontSize(fontSize)
        }

        if let textAlign = extractStyleValue(from: styleAttr, property: "text-align") {
            styles.textAlign = parseTextAlignment(textAlign)
        }

        if let borderColor = extractStyleValue(from: styleAttr, property: "border-color") {
            styles.borderColor = parseColor(borderColor)
        }

        if let borderWidth = extractStyleValue(from: styleAttr, property: "border-width") {
            styles.borderWidth = parseDimension(borderWidth)
        }

        if let borderRadius = extractStyleValue(from: styleAttr, property: "border-radius") {
            styles.borderRadius = parseDimension(borderRadius)
        }

        if let border = extractStyleValue(from: styleAttr, property: "border") {
            let parts = border.components(separatedBy: " ")
            if parts.count >= 1 {
                styles.borderWidth = parseDimension(parts[0])
            }
            if parts.count >= 3, let color = parseColor(parts[2]) {
                styles.borderColor = color
            }
        }

        if let width = extractStyleValue(from: styleAttr, property: "width") {
            styles.width = parseDimension(width)
        }

        if let height = extractStyleValue(from: styleAttr, property: "height") {
            styles.height = parseDimension(height)
        }

        if let flex = extractStyleValue(from: styleAttr, property: "flex") {
            styles.flex = CGFloat(Double(flex) ?? 1)
        }

        if let display = extractStyleValue(from: styleAttr, property: "display") {
            if display.lowercased() == "flex" {
                styles.display = .flex
                styles.flexDirection = .row
            }
        }

        if let flexDirection = extractStyleValue(from: styleAttr, property: "flex-direction") {
            if flexDirection.lowercased() == "column" {
                styles.flexDirection = .column
            } else if flexDirection.lowercased() == "row" {
                styles.flexDirection = .row
            }
        }

        if let gap = extractStyleValue(from: styleAttr, property: "gap") {
            styles.gap = parseDimension(gap)
        }

        styles.padding = parsePadding(from: styleAttr)
        styles.margin = parseMargin(from: styleAttr)

        return styles
    }

    private func parsePadding(from styleAttr: String) -> UIEdgeInsets {
        var padding = UIEdgeInsets.zero

        if let paddingValue = extractStyleValue(from: styleAttr, property: "padding") {
            let values = paddingValue.components(separatedBy: " ").map { parseDimension($0) }

            switch values.count {
            case 1:
                let value = values[0]
                padding = UIEdgeInsets(top: value, left: value, bottom: value, right: value)
            case 2:
                padding = UIEdgeInsets(top: values[0], left: values[1], bottom: values[0], right: values[1])
            case 3:
                padding = UIEdgeInsets(top: values[0], left: values[1], bottom: values[2], right: values[1])
            case 4:
                padding = UIEdgeInsets(top: values[0], left: values[3], bottom: values[2], right: values[1])
            default:
                break
            }
        }

        if let paddingTop = extractStyleValue(from: styleAttr, property: "padding-top") {
            padding.top = parseDimension(paddingTop)
        }

        if let paddingRight = extractStyleValue(from: styleAttr, property: "padding-right") {
            padding.right = parseDimension(paddingRight)
        }

        if let paddingBottom = extractStyleValue(from: styleAttr, property: "padding-bottom") {
            padding.bottom = parseDimension(paddingBottom)
        }

        if let paddingLeft = extractStyleValue(from: styleAttr, property: "padding-left") {
            padding.left = parseDimension(paddingLeft)
        }

        return padding
    }

    private func parseMargin(from styleAttr: String) -> UIEdgeInsets {
        var margin = UIEdgeInsets.zero

        if let marginValue = extractStyleValue(from: styleAttr, property: "margin") {
            let values = marginValue.components(separatedBy: " ").map { parseDimension($0) }

            switch values.count {
            case 1:
                let value = values[0]
                margin = UIEdgeInsets(top: value, left: value, bottom: value, right: value)
            case 2:
                margin = UIEdgeInsets(top: values[0], left: values[1], bottom: values[0], right: values[1])
            case 4:
                margin = UIEdgeInsets(top: values[0], left: values[3], bottom: values[2], right: values[1])
            default:
                break
            }
        }

        if let marginTop = extractStyleValue(from: styleAttr, property: "margin-top") {
            margin.top = parseDimension(marginTop)
        }

        if let marginRight = extractStyleValue(from: styleAttr, property: "margin-right") {
            margin.right = parseDimension(marginRight)
        }

        if let marginBottom = extractStyleValue(from: styleAttr, property: "margin-bottom") {
            margin.bottom = parseDimension(marginBottom)
        }

        if let marginLeft = extractStyleValue(from: styleAttr, property: "margin-left") {
            margin.left = parseDimension(marginLeft)
        }

        return margin
    }

    private func parseDimension(_ value: String) -> CGFloat {
        let cleanValue = value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "px", with: "")
            .replacingOccurrences(of: "pt", with: "")

        return CGFloat(Double(cleanValue) ?? 0)
    }

    private func parseFontSize(_ value: String) -> CGFloat {
        return parseDimension(value) * 1.2
    }

    private func parseTextAlignment(_ value: String) -> NSTextAlignment {
        switch value.lowercased().trimmingCharacters(in: .whitespaces) {
        case "center":
            return .center
        case "right":
            return .right
        case "justify":
            return .justified
        default:
            return .left
        }
    }

    private func extractColorFromBackground(_ background: String) -> String? {
        if background.contains("linear-gradient") {
            let pattern = "#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3}|rgba?\\([^)]+\\)"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: background, range: NSRange(background.startIndex..., in: background)),
                  let range = Range(match.range, in: background) else {
                return nil
            }
            return String(background[range])
        }

        if background.hasPrefix("#") || background.hasPrefix("rgb") {
            return background
        }

        return nil
    }

    private func parseColor(_ colorString: String?) -> UIColor? {
        guard let colorString = colorString else { return nil }

        let cleanColor = colorString.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanColor.hasPrefix("#") {
            let hex = String(cleanColor.dropFirst())
            var rgbValue: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgbValue)

            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0

            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        } else if cleanColor.hasPrefix("rgb") {
            let pattern = "rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([0-9.]+))?"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: cleanColor, range: NSRange(cleanColor.startIndex..., in: cleanColor)) else {
                return nil
            }

            let r = (cleanColor as NSString).substring(with: match.range(at: 1))
            let g = (cleanColor as NSString).substring(with: match.range(at: 2))
            let b = (cleanColor as NSString).substring(with: match.range(at: 3))

            var alpha: CGFloat = 1.0
            if match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound {
                let a = (cleanColor as NSString).substring(with: match.range(at: 4))
                alpha = CGFloat(Double(a) ?? 1.0)
            }

            return UIColor(red: CGFloat(Double(r) ?? 0) / 255.0,
                          green: CGFloat(Double(g) ?? 0) / 255.0,
                          blue: CGFloat(Double(b) ?? 0) / 255.0,
                          alpha: alpha)
        }

        return nil
    }

    private func extractStyleValue(from styles: String, property: String) -> String? {
        let pattern = "(?:^|;|\\s)\\s*\(property)\\s*:\\s*([^;\"]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: styles, range: NSRange(styles.startIndex..., in: styles)),
              let range = Range(match.range(at: 1), in: styles) else {
            return nil
        }
        return String(styles[range]).trimmingCharacters(in: .whitespaces)
    }

    private func extractAttribute(from html: String, attribute: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    private func extractDataAttribute(from html: String, attribute: String) -> String? {
        return extractAttribute(from: html, attribute: attribute)
    }

    private func stripHTML(_ html: String) -> String {
        var result = html

        let pattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        result = regex.stringByReplacingMatches(in: result,
                                               range: NSRange(result.startIndex..., in: result),
                                               withTemplate: "")

        return result.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    private func processPlaceholders(in html: String, localization: [String: Any]?) -> String {
        var result = html

        let pattern = "\\{\\{([^|]+)\\|text\\|([^}]*)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let keyRange = Range(match.range(at: 1), in: result),
                  let defaultRange = Range(match.range(at: 2), in: result) else {
                continue
            }

            let key = String(result[keyRange])
            let defaultValue = String(result[defaultRange])

            var replacementValue = defaultValue
            if let localization = localization, let value = localization[key] as? String {
                replacementValue = value
            }

            result.replaceSubrange(fullRange, with: replacementValue)
        }

        return result
    }
}
