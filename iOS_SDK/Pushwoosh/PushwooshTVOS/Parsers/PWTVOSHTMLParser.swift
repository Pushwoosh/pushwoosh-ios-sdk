//
//  PWTVOSHTMLParser.swift
//  PushwooshTVOS
//
//  Created by André Kis on 13.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@available(tvOS 11.0, *)
class PWTVOSHTMLParser {

    enum RichMediaElement {
        case image(url: String)
        case heading(text: String, fontSize: CGFloat, color: UIColor?, textAlignment: NSTextAlignment)
        case text(text: String, fontSize: CGFloat, color: UIColor?, textAlignment: NSTextAlignment)
        case textField(placeholder: String, fieldName: String, fontSize: CGFloat, textColor: UIColor?, bgColor: UIColor?, borderColor: UIColor?, textAlignment: NSTextAlignment)
        case button(text: String, bgColor: UIColor, textColor: UIColor, borderColor: UIColor?, isClose: Bool, isOpenSettings: Bool, isSendTags: Bool, isGetTags: Bool, eventName: String?, eventAttributes: [String: Any]?, tags: [String: Any]?)
        case container(children: [RichMediaElement], layout: ContainerLayout)
    }

    struct ContainerLayout {
        var direction: LayoutDirection = .vertical
        var distribution: LayoutDistribution = .fill
        var spacing: CGFloat = 0
        var padding: UIEdgeInsets = .zero
        var flexChildren: [CGFloat] = []
        var backgroundColor: UIColor? = nil
    }

    enum LayoutDirection {
        case horizontal
        case vertical
    }

    enum LayoutDistribution {
        case fill
        case fillEqually
        case fillProportionally
    }

    class DOMNode {
        var tagName: String
        var id: String?
        var className: String?
        var style: String?
        var attributes: [String: String] = [:]
        var children: [DOMNode] = []
        var textContent: String?

        init(tagName: String) {
            self.tagName = tagName
        }
    }

    func parseHTML(_ html: String, localization: [String: Any]?) -> [RichMediaElement] {
        let processedHTML = processPlaceholders(in: html, localization: localization)
        return parseWithDOMTree(processedHTML)
    }

    private func parseWithDOMTree(_ html: String) -> [RichMediaElement] {
        let u_column_1Content = extractU_Column1Content(from: html)
        guard !u_column_1Content.isEmpty else {
            return parseUnlayerFormat(html)
        }

        let hasFlexRow = u_column_1Content.range(of: "flex-direction:\\s*row", options: .regularExpression) != nil

        if hasFlexRow {
            var columnDivs = extractTopLevelDivs(from: u_column_1Content)

            if columnDivs.count == 1 {
                if columnDivs[0].contains("u_content_html") {
                    if let innerHTML = extractInnerHTMLFromContentDiv(columnDivs[0]) {
                        let innerU_column_1Content = extractU_Column1Content(from: innerHTML)
                        if !innerU_column_1Content.isEmpty {
                            columnDivs = extractTopLevelDivs(from: innerU_column_1Content)
                        } else {
                            columnDivs = extractTopLevelDivs(from: innerHTML)
                        }
                    }
                } else {
                    let innerDivs = extractTopLevelDivs(from: columnDivs[0])
                    if innerDivs.count >= 2 {
                        columnDivs = innerDivs
                    }
                }
            }

            if columnDivs.count >= 2 {
                let leftElements = parseNodeChildren(DOMNode(tagName: "div"), html: columnDivs[0])
                let rightElements = parseNodeChildren(DOMNode(tagName: "div"), html: columnDivs[1])

                if !leftElements.isEmpty || !rightElements.isEmpty {
                    let bgColor = extractBackgroundColor(from: html)

                    var layout = ContainerLayout(direction: .horizontal, distribution: .fillEqually, spacing: 20)
                    layout.backgroundColor = bgColor

                    return [.container(children: [
                        .container(children: leftElements, layout: ContainerLayout(direction: .vertical, spacing: 10)),
                        .container(children: rightElements, layout: ContainerLayout(direction: .vertical, spacing: 10))
                    ], layout: layout)]
                }
            }
        }
        let children = parseNodeChildren(DOMNode(tagName: "div"), html: html)
        if !children.isEmpty {
            return [.container(children: children, layout: ContainerLayout())]
        }

        return parseUnlayerFormat(html)
    }

    private func extractInnerHTMLFromContentDiv(_ divHTML: String) -> String? {
        guard let contentStart = divHTML.range(of: "u_content_html") else {
            return nil
        }

        let fromContent = divHTML[contentStart.lowerBound...]
        guard let tagEnd = fromContent.range(of: ">") else {
            return nil
        }

        let afterTag = fromContent[tagEnd.upperBound...]
        guard let divStart = afterTag.range(of: "<div>") else {
            return nil
        }

        let contentAfterDiv = afterTag[divStart.upperBound...]

        var depth = 1
        var currentIndex = contentAfterDiv.startIndex

        while currentIndex < contentAfterDiv.endIndex && depth > 0 {
            let remaining = contentAfterDiv[currentIndex...]

            if remaining.hasPrefix("<div") {
                depth += 1
                currentIndex = contentAfterDiv.index(currentIndex, offsetBy: 4)
            } else if remaining.hasPrefix("</div>") {
                depth -= 1
                if depth == 0 {
                    return String(contentAfterDiv[..<currentIndex])
                }
                currentIndex = contentAfterDiv.index(currentIndex, offsetBy: 6)
            } else {
                currentIndex = contentAfterDiv.index(after: currentIndex)
            }
        }

        return nil
    }

    private func extractU_Column1Content(from html: String) -> String {
        guard let startRange = html.range(of: "id=\"u_column_1\"") else {
            return ""
        }

        let fromStart = html[startRange.lowerBound...]
        guard let tagEnd = fromStart.range(of: ">") else {
            return ""
        }

        let afterTag = fromStart[tagEnd.upperBound...]
        var depth = 1
        var currentIndex = afterTag.startIndex

        while currentIndex < afterTag.endIndex && depth > 0 {
            let remaining = afterTag[currentIndex...]

            if remaining.hasPrefix("<div") {
                depth += 1
                currentIndex = afterTag.index(currentIndex, offsetBy: 4)
            } else if remaining.hasPrefix("</div>") {
                depth -= 1
                if depth == 0 {
                    return String(afterTag[..<currentIndex])
                }
                currentIndex = afterTag.index(currentIndex, offsetBy: 6)
            } else {
                currentIndex = afterTag.index(after: currentIndex)
            }
        }

        return ""
    }

    private func extractTopLevelDivs(from content: String) -> [String] {
        var divs: [String] = []
        var currentIndex = content.startIndex

        while currentIndex < content.endIndex {
            let remaining = content[currentIndex...]

            if remaining.hasPrefix("<div") {
                let divStart = currentIndex
                var depth = 0
                var searchIndex = currentIndex

                while searchIndex < content.endIndex {
                    let searchRemaining = content[searchIndex...]

                    if searchRemaining.hasPrefix("<div") {
                        depth += 1
                        searchIndex = content.index(searchIndex, offsetBy: 4, limitedBy: content.endIndex) ?? content.endIndex
                    } else if searchRemaining.hasPrefix("</div>") {
                        depth -= 1
                        if depth == 0 {
                            let divEnd = content.index(searchIndex, offsetBy: 6, limitedBy: content.endIndex) ?? content.endIndex
                            let divContent = String(content[divStart..<divEnd])
                            divs.append(divContent)
                            currentIndex = divEnd
                            break
                        }
                        searchIndex = content.index(searchIndex, offsetBy: 6, limitedBy: content.endIndex) ?? content.endIndex
                    } else {
                        searchIndex = content.index(after: searchIndex)
                    }
                }

                if depth != 0 {
                    currentIndex = content.index(after: currentIndex)
                }
            } else {
                currentIndex = content.index(after: currentIndex)
            }
        }

        return divs
    }


    private func parseNodeChildren(_ node: DOMNode, html: String) -> [RichMediaElement] {
        var elements: [RichMediaElement] = []

        if let bgImageURL = extractBodyBackgroundImage(from: html) {
            elements.append(.image(url: bgImageURL))
        }

        let contentPattern = "id=\"(u_content_[^\"]+)\""
        guard let contentRegex = try? NSRegularExpression(pattern: contentPattern) else {
            return elements
        }

        let matches = contentRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var processedIds = Set<String>()

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let contentId = String(html[range])

            if processedIds.contains(contentId) {
                continue
            }
            processedIds.insert(contentId)

            if contentId.contains("_divider_") {
                continue
            } else if contentId.contains("_image_") {
                if let content = extractContentForId(html, contentId: contentId),
                   let imageURL = extractImageURL(from: content) {
                    elements.append(.image(url: imageURL))
                }
            } else if contentId.contains("_html_") {
                if let content = extractContentForId(html, contentId: contentId) {
                    if let imageURL = extractImageURL(from: content) {
                        elements.append(.image(url: imageURL))
                        if let nestedMatch = contentRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                           let nestedRange = Range(nestedMatch.range(at: 1), in: content) {
                            let nestedId = String(content[nestedRange])
                            if nestedId.contains("_image_") {
                                processedIds.insert(nestedId)
                            }
                        }
                    }
                }
            } else if contentId.contains("_heading_") {
                if let textContent = extractTextContent(html, contentId: contentId) {
                    let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let styles = extractInlineStyles(html, contentId: contentId)
                        let fontSize = parseFontSize(from: styles)
                        let colorStr = extractStyleValue(from: styles, property: "color")
                        let color = parseColor(colorStr)
                        let alignment = parseTextAlignment(from: styles)
                        elements.append(.heading(text: text, fontSize: fontSize, color: color, textAlignment: alignment))
                    }
                }
            } else if contentId.contains("_text_") {
                if let textContent = extractTextContent(html, contentId: contentId) {
                    let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let styles = extractInlineStyles(html, contentId: contentId)
                        let fontSize = parseFontSize(from: styles)
                        let textColor = extractStyleValue(from: styles, property: "color")
                        let color = parseColor(textColor)
                        let alignment = parseTextAlignment(from: styles)
                        elements.append(.text(text: text, fontSize: fontSize, color: color, textAlignment: alignment))
                    }
                }
            } else if contentId.contains("_textfield_") {
                if let content = extractContentForId(html, contentId: contentId),
                   let textFieldData = extractTextFieldContent(content) {
                    let styles = extractInputStyles(from: content)
                    let fontSize = parseFontSize(from: styles)
                    let textColor = parseColor(extractStyleValue(from: styles, property: "color"))
                    let bgColor = parseColor(extractStyleValue(from: styles, property: "background-color"))
                    let borderColor = parseColor(extractStyleValue(from: styles, property: "border-color"))
                    let alignment = parseTextAlignment(from: styles)
                    elements.append(.textField(placeholder: textFieldData.placeholder, fieldName: textFieldData.fieldName, fontSize: fontSize, textColor: textColor, bgColor: bgColor, borderColor: borderColor, textAlignment: alignment))
                }
            } else if contentId.contains("_button_") {
                if let buttonContent = extractButtonContent(html, contentId: contentId) {
                    let text = stripHTML(buttonContent.text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        var bgColor = parseColor(buttonContent.bgColor) ?? UIColor(red: 0.50, green: 0.29, blue: 1.0, alpha: 1.0)
                        let textColor = parseColor(buttonContent.textColor) ?? .white
                        let borderColor = parseColor(buttonContent.borderColor)
                        let isClose = buttonContent.isClose
                        let isOpenSettings = buttonContent.isOpenSettings
                        let isSendTags = buttonContent.isSendTags
                        let isGetTags = buttonContent.isGetTags
                        let eventName = buttonContent.eventName
                        let eventAttributes = buttonContent.eventAttributes
                        let tags = buttonContent.tags

                        if let bgColorStr = buttonContent.bgColor?.lowercased(),
                           bgColorStr.contains("transparent"),
                           let _ = borderColor {
                            bgColor = .clear
                        }

                        elements.append(.button(text: text, bgColor: bgColor, textColor: textColor, borderColor: borderColor, isClose: isClose, isOpenSettings: isOpenSettings, isSendTags: isSendTags, isGetTags: isGetTags, eventName: eventName, eventAttributes: eventAttributes, tags: tags))
                    }
                }
            }
        }

        return elements
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

    private func parseUnlayerFormat(_ html: String) -> [RichMediaElement] {
        var elements: [RichMediaElement] = []

        if let bgImageURL = extractBodyBackgroundImage(from: html) {
            elements.append(.image(url: bgImageURL))
        }

        let contentPattern = "id=\"(u_content_[^\"]+)\""
        guard let contentRegex = try? NSRegularExpression(pattern: contentPattern) else {
            return elements
        }

        let matches = contentRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var processedIds = Set<String>()

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let contentId = String(html[range])

            if processedIds.contains(contentId) {
                continue
            }
            processedIds.insert(contentId)

            if contentId.contains("_divider_") {
                continue
            } else if contentId.contains("_image_") {
                if let content = extractContentForId(html, contentId: contentId),
                   let imageURL = extractImageURL(from: content) {
                    elements.append(.image(url: imageURL))
                }
            } else if contentId.contains("_html_") {
                if let content = extractContentForId(html, contentId: contentId) {
                    if let imageURL = extractImageURL(from: content) {
                        elements.append(.image(url: imageURL))
                        if let nestedMatch = contentRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                           let nestedRange = Range(nestedMatch.range(at: 1), in: content) {
                            let nestedId = String(content[nestedRange])
                            if nestedId.contains("_image_") {
                                processedIds.insert(nestedId)
                            }
                        }
                    }
                }
            } else if contentId.contains("_heading_") {
                if let textContent = extractTextContent(html, contentId: contentId) {
                    let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let styles = extractInlineStyles(html, contentId: contentId)
                        let fontSize = parseFontSize(from: styles)
                        let colorStr = extractStyleValue(from: styles, property: "color")
                        let color = parseColor(colorStr)
                        let alignment = parseTextAlignment(from: styles)
                        elements.append(.heading(text: text, fontSize: fontSize, color: color, textAlignment: alignment))
                    }
                }
            } else if contentId.contains("_text_") {
                if let textContent = extractTextContent(html, contentId: contentId) {
                    let text = stripHTML(textContent).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let styles = extractInlineStyles(html, contentId: contentId)
                        let fontSize = parseFontSize(from: styles)
                        let textColor = extractStyleValue(from: styles, property: "color")
                        let color = parseColor(textColor)
                        let alignment = parseTextAlignment(from: styles)
                        elements.append(.text(text: text, fontSize: fontSize, color: color, textAlignment: alignment))
                    }
                }
            } else if contentId.contains("_textfield_") {
                if let content = extractContentForId(html, contentId: contentId),
                   let textFieldData = extractTextFieldContent(content) {
                    let styles = extractInputStyles(from: content)
                    let fontSize = parseFontSize(from: styles)
                    let textColor = parseColor(extractStyleValue(from: styles, property: "color"))
                    let bgColor = parseColor(extractStyleValue(from: styles, property: "background-color"))
                    let borderColor = parseColor(extractStyleValue(from: styles, property: "border-color"))
                    let alignment = parseTextAlignment(from: styles)
                    elements.append(.textField(placeholder: textFieldData.placeholder, fieldName: textFieldData.fieldName, fontSize: fontSize, textColor: textColor, bgColor: bgColor, borderColor: borderColor, textAlignment: alignment))
                }
            } else if contentId.contains("_button_") {
                if let buttonContent = extractButtonContent(html, contentId: contentId) {
                    let text = stripHTML(buttonContent.text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        var bgColor = parseColor(buttonContent.bgColor) ?? UIColor(red: 0.50, green: 0.29, blue: 1.0, alpha: 1.0)
                        let textColor = parseColor(buttonContent.textColor) ?? .white
                        let borderColor = parseColor(buttonContent.borderColor)
                        let isClose = buttonContent.isClose
                        let isOpenSettings = buttonContent.isOpenSettings
                        let isSendTags = buttonContent.isSendTags
                        let isGetTags = buttonContent.isGetTags
                        let eventName = buttonContent.eventName
                        let eventAttributes = buttonContent.eventAttributes
                        let tags = buttonContent.tags

                        if let bgColorStr = buttonContent.bgColor?.lowercased(),
                           bgColorStr.contains("transparent"),
                           let _ = borderColor {
                            bgColor = .clear
                        }

                        elements.append(.button(text: text, bgColor: bgColor, textColor: textColor, borderColor: borderColor, isClose: isClose, isOpenSettings: isOpenSettings, isSendTags: isSendTags, isGetTags: isGetTags, eventName: eventName, eventAttributes: eventAttributes, tags: tags))
                    }
                }
            }
        }

        return elements
    }

    private func extractBackgroundColor(from html: String) -> UIColor? {
        let patterns = [
            "id=\"u_column_1\"[^>]*>",
            "id=\"u_body\"[^>]*>"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range, in: html) {
                let tagStr = String(html[range])

                if let bgColor = extractStyleValue(from: tagStr, property: "background-color") {
                    return parseColor(bgColor)
                }
            }
        }

        return nil
    }

    private func extractBodyBackgroundImage(from html: String) -> String? {
        let pattern = "id=\"u_body\"[^>]*style=\"[^\"]*background-image:\\s*url\\(['\"]?([^'\"\\)]+)['\"]?\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    private func extractContentForId(_ html: String, contentId: String) -> String? {
        let pattern = "id=\"\(contentId)\"[^>]*>([\\s\\S]*?)</div>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    private func extractImageURL(from content: String) -> String? {
        let patterns = [
            "<img[^>]*src=\"([^\"]+)\"",
            "background-image:\\s*url\\(['\"]?([^'\"\\)]+)['\"]?\\)",
            "background:\\s*url\\(['\"]?([^'\"\\)]+)['\"]?\\)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range])
            }
        }
        return nil
    }


    private func extractTextContent(_ html: String, contentId: String) -> String? {
        let pattern = "id=\"\(contentId)\"[^>]*>([\\s\\S]*?)</div>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    private func extractTextFieldContent(_ content: String) -> (placeholder: String, fieldName: String)? {
        let inputPattern = "<input[^>]*>"
        guard let inputRegex = try? NSRegularExpression(pattern: inputPattern),
              let match = inputRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range, in: content) else {
            return nil
        }

        let inputTag = String(content[range])
        let placeholder = extractAttribute(from: inputTag, attribute: "placeholder") ?? ""
        let fieldName = extractDataAttribute(from: inputTag, attribute: "data-field-name") ?? "textField"

        return (placeholder, fieldName)
    }

    private func extractInputStyles(from content: String) -> String {
        let pattern = "<input[^>]*style=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return ""
        }
        return String(content[range])
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

    private func extractButtonContent(_ html: String, contentId: String) -> (text: String, bgColor: String?, textColor: String?, borderColor: String?, isClose: Bool, isOpenSettings: Bool, isSendTags: Bool, isGetTags: Bool, eventName: String?, eventAttributes: [String: Any]?, tags: [String: Any]?)? {
        let pattern = "id=\"\(contentId)\"[^>]*>([\\s\\S]*?)</div>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let content = String(html[range])
        let isClose = content.contains("closeInApp")
        let isOpenSettings = content.contains("openAppSettings")
        let isSendTags = content.contains("sendTags")
        let isGetTags = content.contains("getTags")

        let textPattern = "<a[^>]*>\\s*([\\s\\S]*?)\\s*</a>"
        guard let textRegex = try? NSRegularExpression(pattern: textPattern),
              let textMatch = textRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let textRange = Range(textMatch.range(at: 1), in: content) else {
            return nil
        }

        let text = stripHTML(String(content[textRange]))
        let bgColor = extractStyleValue(from: content, property: "background-color")
        let textColor = extractStyleValue(from: content, property: "color")
        let borderColor = extractStyleValue(from: content, property: "border-bottom-color")
            ?? extractStyleValue(from: content, property: "border-color")

        let eventName = extractDataAttribute(from: content, attribute: "data-event")
        var eventAttributes: [String: Any]?
        if let attributesStr = extractDataAttribute(from: content, attribute: "data-attributes"),
           let data = attributesStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            eventAttributes = json
        }

        var tags: [String: Any]?
        if let tagsStr = extractDataAttribute(from: content, attribute: "data-tags"),
           let data = tagsStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            tags = json
        }

        return (text, bgColor, textColor, borderColor, isClose, isOpenSettings, isSendTags, isGetTags, eventName, eventAttributes, tags)
    }

    private func extractDataAttribute(from html: String, attribute: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    private func extractInlineStyles(_ html: String, contentId: String) -> String {
        guard let content = extractContentForId(html, contentId: contentId) else {
            return ""
        }

        let pattern = "style=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return ""
        }
        return String(content[range])
    }

    private func extractStyleValue(from content: String, property: String) -> String? {
        let pattern = "\(property):\\s*([^;\"]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range]).trimmingCharacters(in: .whitespaces)
    }


    private func parseFontSize(from styles: String) -> CGFloat {
        guard let sizeStr = extractStyleValue(from: styles, property: "font-size") else {
            return 20
        }

        let numericString = sizeStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let size = Double(numericString) {
            return CGFloat(size * 1.2)
        }

        return 20
    }

    private func parseTextAlignment(from styles: String) -> NSTextAlignment {
        guard let alignmentStr = extractStyleValue(from: styles, property: "text-align") else {
            return .left
        }

        let alignment = alignmentStr.lowercased().trimmingCharacters(in: .whitespaces)
        switch alignment {
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
            let pattern = "rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: cleanColor, range: NSRange(cleanColor.startIndex..., in: cleanColor)) else {
                return nil
            }

            let r = (cleanColor as NSString).substring(with: match.range(at: 1))
            let g = (cleanColor as NSString).substring(with: match.range(at: 2))
            let b = (cleanColor as NSString).substring(with: match.range(at: 3))

            return UIColor(red: CGFloat(Double(r) ?? 0) / 255.0,
                          green: CGFloat(Double(g) ?? 0) / 255.0,
                          blue: CGFloat(Double(b) ?? 0) / 255.0,
                          alpha: 1.0)
        }

        return nil
    }

    func stripHTML(_ html: String) -> String {
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
}
