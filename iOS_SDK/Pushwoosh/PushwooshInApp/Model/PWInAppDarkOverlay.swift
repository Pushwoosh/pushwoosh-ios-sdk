//
//  PWInAppDarkOverlay.swift
//  PushwooshInApp
//
//  Created by André Kis on 08.09.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import Foundation
import PushwooshCore

/// Sparse `dark` overlay for a native in-app display block (SDK-971), one contract
/// with Android's `InAppDarkOverlay`: only visual leaves are themable — `background`,
/// `color`, `image`, `poster`, `fallback` by key name; objects merge recursively, the
/// `buttons` / `items` arrays merge positionally and must match in length; everything else
/// in `dark` (texts, flags, actions, `url`, other arrays) is ignored, and a JSON `null`
/// never deletes a light value. Leaf values are copied through untouched — rejecting a
/// malformed one is the strict parser's job, which then falls back to the light variant.
enum PWInAppDarkOverlay {

    enum Outcome {
        case none
        case merged([AnyHashable: Any])
        case broken(String)
    }

    /// Effective theme at presentation time (SDK-958 scheme: APP/SYSTEM/LIGHT/DARK).
    /// Main thread only — the resolver walks the app's window hierarchy.
    static func isDarkNow() -> Bool {
        PWRichMediaColorSchemeResolver.isCurrentSchemeDark()
    }

    private struct Broken: Error {
        let label: String
    }

    private static let blockKeys: Set<String> = ["modal", "sheet", "carousel", "stories", "banner",
                                                 "fullscreen", "video", "pip", "scratchcard", "spinwheel"]

    /// Themable leaves shared with Android. `url` (video/pip) and `text` are content, deliberately absent.
    private static let visualLeafKeys: Set<String> = ["background", "color", "image", "poster", "fallback"]
    /// Arrays merged positionally, same set as Android's `POSITIONAL_ARRAY_KEYS`; any other array in `dark` is ignored.
    private static let positionalArrayKeys: Set<String> = ["buttons", "items"]

    static func apply(to config: [AnyHashable: Any]) -> Outcome {
        guard let displayType = (config["displayType"] as? String)?.lowercased(),
              blockKeys.contains(displayType),
              let block = config[displayType] as? [AnyHashable: Any] else {
            return .none
        }
        guard let rawDark = block["dark"], !(rawDark is NSNull) else {
            return .none
        }
        guard let dark = rawDark as? [AnyHashable: Any] else {
            return .broken("\(displayType).dark is not an object")
        }
        do {
            var mergedBlock = try mergeVisual(light: block, dark: dark, label: "\(displayType).dark")
            mergedBlock["dark"] = nil
            var merged = config
            merged[displayType] = mergedBlock
            return .merged(merged)
        } catch let failure as Broken {
            return .broken(failure.label)
        } catch {
            return .broken("\(displayType).dark")
        }
    }

    private static func mergeVisual(light: [AnyHashable: Any],
                                    dark: [AnyHashable: Any],
                                    label: String) throws -> [AnyHashable: Any] {
        var merged = light
        for (rawKey, darkValue) in dark {
            guard let key = rawKey as? String, key != "dark", !(darkValue is NSNull) else { continue }
            let lightValue = light[key]
            if positionalArrayKeys.contains(key) {
                merged[key] = try mergeArray(light: lightValue, dark: darkValue, label: "\(label).\(key)")
            } else if let lightDict = lightValue as? [AnyHashable: Any] {
                if let darkDict = darkValue as? [AnyHashable: Any] {
                    merged[key] = try mergeVisual(light: lightDict, dark: darkDict, label: "\(label).\(key)")
                }
            } else if visualLeafKeys.contains(key) {
                merged[key] = darkValue
            }
        }
        return merged
    }

    private static func mergeArray(light: Any?,
                                   dark: Any,
                                   label: String) throws -> [[AnyHashable: Any]] {
        guard let lightArray = light as? [[AnyHashable: Any]] else {
            throw Broken(label: "\(label) has no light array of objects to merge onto")
        }
        guard let darkArray = dark as? [[AnyHashable: Any]] else {
            throw Broken(label: "\(label) is not an array of objects")
        }
        guard darkArray.count == lightArray.count else {
            throw Broken(label: "\(label) length \(darkArray.count) != \(lightArray.count)")
        }
        return try zip(lightArray, darkArray).enumerated().map { index, pair in
            try mergeVisual(light: pair.0, dark: pair.1, label: "\(label)[\(index)]")
        }
    }
}
#endif
