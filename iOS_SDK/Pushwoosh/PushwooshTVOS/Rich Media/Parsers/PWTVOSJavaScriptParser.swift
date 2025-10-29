//
//  PWTVOSJavaScriptParser.swift
//  PushwooshTVOS
//
//  Created by André Kis on 15.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

@available(tvOS 11.0, *)
class PWTVOSJavaScriptParser {

    enum JavaScriptCall {
        case postEvent(name: String, attributes: [String: Any]?)
        case sendTags(tags: [String: Any])
        case getTags
        case setEmail(email: String)
        case closeInApp
        case openAppSettings
        case registerForPushNotifications
        case unregisterForPushNotifications
        case getHwid
        case getVersion
        case getApplication
        case getUserId
        case getRichmediaCode
        case getDeviceType
        case getMessageHash
        case getInAppCode
        case unknown
    }

    func parseJavaScriptCall(_ jsCode: String) -> JavaScriptCall {
        let trimmed = jsCode.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("postEvent") {
            return parsePostEvent(trimmed)
        } else if trimmed.contains("sendTags") {
            return parseSendTags(trimmed)
        } else if trimmed.contains("getTags") {
            return .getTags
        } else if trimmed.contains("setEmail") {
            return parseSetEmail(trimmed)
        } else if trimmed.contains("closeInApp") {
            return .closeInApp
        } else if trimmed.contains("openAppSettings") {
            return .openAppSettings
        } else if trimmed.contains("unregisterForPushNotifications") {
            return .unregisterForPushNotifications
        } else if trimmed.contains("registerForPushNotifications") {
            return .registerForPushNotifications
        } else if trimmed.contains("getHwid") {
            return .getHwid
        } else if trimmed.contains("getVersion") {
            return .getVersion
        } else if trimmed.contains("getApplication") {
            return .getApplication
        } else if trimmed.contains("getUserId") {
            return .getUserId
        } else if trimmed.contains("getRichmediaCode") {
            return .getRichmediaCode
        } else if trimmed.contains("getDeviceType") {
            return .getDeviceType
        } else if trimmed.contains("getMessageHash") {
            return .getMessageHash
        } else if trimmed.contains("getInAppCode") {
            return .getInAppCode
        }

        return .unknown
    }

    private func parsePostEvent(_ jsCode: String) -> JavaScriptCall {
        guard let eventName = extractEventName(from: jsCode) else {
            return .unknown
        }

        let attributes = extractAttributes(from: jsCode)
        return .postEvent(name: eventName, attributes: attributes)
    }

    private func parseSendTags(_ jsCode: String) -> JavaScriptCall {
        guard let tags = extractTags(from: jsCode) else {
            return .unknown
        }

        return .sendTags(tags: tags)
    }

    private func parseSetEmail(_ jsCode: String) -> JavaScriptCall {
        guard let email = extractEmail(from: jsCode) else {
            return .unknown
        }

        return .setEmail(email: email)
    }

    private func extractEventName(from jsCode: String) -> String? {
        let patterns = [
            #"postEvent\s*\(\s*['"']([^'"']+)['"']"#,
            #"postEvent\s*\(\s*"([^"]+)""#,
            #"postEvent\s*\(\s*'([^']+)'"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: jsCode, options: [], range: NSRange(jsCode.startIndex..., in: jsCode)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: jsCode) {
                return String(jsCode[range])
            }
        }

        return nil
    }

    private func extractAttributes(from jsCode: String) -> [String: Any]? {
        guard let jsonStart = jsCode.range(of: "{"),
              let jsonEnd = jsCode.range(of: "}", options: .backwards) else {
            return nil
        }

        let jsonString = String(jsCode[jsonStart.lowerBound..<jsonEnd.upperBound])
        return parseJSON(jsonString)
    }

    private func extractTags(from jsCode: String) -> [String: Any]? {
        guard let jsonStart = jsCode.range(of: "{"),
              let jsonEnd = jsCode.range(of: "}", options: .backwards) else {
            return nil
        }

        let jsonString = String(jsCode[jsonStart.lowerBound..<jsonEnd.upperBound])
        return parseJSON(jsonString)
    }

    private func extractEmail(from jsCode: String) -> String? {
        let patterns = [
            #"setEmail\s*\(\s*['"']([^'"']+)['"']"#,
            #"setEmail\s*\(\s*"([^"]+)""#,
            #"setEmail\s*\(\s*'([^']+)'"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: jsCode, options: [], range: NSRange(jsCode.startIndex..., in: jsCode)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: jsCode) {
                return String(jsCode[range])
            }
        }

        return nil
    }

    private func parseJSON(_ jsonString: String) -> [String: Any]? {
        let cleaned = cleanJavaScriptJSON(jsonString)

        guard let data = cleaned.data(using: .utf8) else {
            return nil
        }

        do {
            if let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return result
            }
        } catch {
            return nil
        }

        return nil
    }

    private func cleanJavaScriptJSON(_ jsJSON: String) -> String {
        var cleaned = jsJSON

        let singleQuotePattern = #"'([^'\\]*(\\.[^'\\]*)*)'"#
        if let regex = try? NSRegularExpression(pattern: singleQuotePattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "\"$1\"")
        }

        let unquotedKeyPattern = #"([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:"#
        if let regex = try? NSRegularExpression(pattern: unquotedKeyPattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "$1\"$2\":")
        }

        return cleaned
    }
}
