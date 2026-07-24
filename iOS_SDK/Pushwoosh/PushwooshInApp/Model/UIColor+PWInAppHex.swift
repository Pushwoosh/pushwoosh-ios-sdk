//
//  UIColor+PWInAppHex.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

extension UIColor {
    /// Parses the CSS hex forms `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA` (with
    /// or without the leading `#` — the contract parser additionally requires
    /// the `#`). Returns `nil` for empty or malformed input.
    static func pw_fromHex(_ hex: String?) -> UIColor? {
        guard var string = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return nil
        }
        if string.hasPrefix("#") {
            string.removeFirst()
        }

        // `UInt64(_:radix:)` requires the whole string to be valid hex digits —
        // unlike Scanner.scanHexInt64, which stops at the first invalid char (and
        // accepts a `0x` prefix), silently turning "abcXYZ"/"0x1234" into a wrong
        // color instead of returning nil.
        guard let value = UInt64(string, radix: 16) else {
            return nil
        }

        let r, g, b, a: CGFloat
        switch string.count {
        case 3:
            r = CGFloat((value & 0xF00) >> 8) / 15
            g = CGFloat((value & 0x0F0) >> 4) / 15
            b = CGFloat(value & 0x00F) / 15
            a = 1
        case 4:
            r = CGFloat((value & 0xF000) >> 12) / 15
            g = CGFloat((value & 0x0F00) >> 8) / 15
            b = CGFloat((value & 0x00F0) >> 4) / 15
            a = CGFloat(value & 0x000F) / 15
        case 6:
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = CGFloat((value & 0xFF000000) >> 24) / 255
            g = CGFloat((value & 0x00FF0000) >> 16) / 255
            b = CGFloat((value & 0x0000FF00) >> 8) / 255
            a = CGFloat(value & 0x000000FF) / 255
        default:
            return nil
        }
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
#endif
