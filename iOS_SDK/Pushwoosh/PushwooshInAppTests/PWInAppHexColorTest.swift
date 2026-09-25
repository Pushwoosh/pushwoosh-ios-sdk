//
//  PWInAppHexColorTest.swift
//  PushwooshTests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWInAppHexColorTest: XCTestCase {

    private func assertColor(_ hex: String,
                             _ er: CGFloat, _ eg: CGFloat, _ eb: CGFloat, _ ea: CGFloat,
                             file: StaticString = #file, line: UInt = #line) {
        guard let color = UIColor.pw_fromHex(hex) else {
            return XCTFail("pw_fromHex(\(hex)) returned nil", file: file, line: line)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, er, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(g, eg, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(b, eb, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(a, ea, accuracy: 0.01, file: file, line: line)
    }

    /// #RRGGBB parses to the right opaque color.
    func testSixDigitOpaque() {
        assertColor("#0E72E5", 14.0/255, 114.0/255, 229.0/255, 1)
    }

    /// #RRGGBBAA parses the trailing alpha byte.
    func testEightDigitAlpha() {
        assertColor("#0E72E580", 14.0/255, 114.0/255, 229.0/255, 128.0/255)
    }

    /// #RGB shorthand expands each nibble to a full byte.
    func testThreeDigitShorthand() {
        assertColor("#F00", 1, 0, 0, 1)
    }

    /// #RGBA shorthand expands including the alpha nibble.
    func testFourDigitShorthandAlpha() {
        assertColor("#0F08", 0, 1, 0, 8.0/15)
    }

    /// A missing leading '#' is still parsed.
    func testWithoutHashPrefix() {
        assertColor("FFFFFF", 1, 1, 1, 1)
    }

    /// Malformed / empty / non-hex / wrong-length input returns nil (fail-closed).
    func testMalformedReturnsNil() {
        XCTAssertNil(UIColor.pw_fromHex(nil))
        XCTAssertNil(UIColor.pw_fromHex(""))
        XCTAssertNil(UIColor.pw_fromHex("#GGG"))
        XCTAssertNil(UIColor.pw_fromHex("0x1234"))
        XCTAssertNil(UIColor.pw_fromHex("#12345"))
    }
}
#endif
