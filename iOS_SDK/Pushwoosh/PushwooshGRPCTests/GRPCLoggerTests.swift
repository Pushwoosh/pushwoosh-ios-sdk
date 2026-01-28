//
//  GRPCLoggerTests.swift
//  PushwooshGRPCTests
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshGRPC

final class GRPCLoggerTests: XCTestCase {

    // MARK: - formatDict Tests

    func testFormatDictEmpty() {
        let result = GRPCLogger.formatDict([:])
        XCTAssertEqual(result, "{}")
    }

    func testFormatDictSimple() {
        let dict: [String: Any] = ["key": "value"]
        let result = GRPCLogger.formatDict(dict)
        XCTAssertTrue(result.contains("key"))
        XCTAssertTrue(result.contains("value"))
    }

    func testFormatDictWithNumbers() {
        let dict: [String: Any] = ["count": 42, "price": 19.99]
        let result = GRPCLogger.formatDict(dict)
        XCTAssertTrue(result.contains("42"))
        XCTAssertTrue(result.contains("19.9")) // floating-point precision
    }

    func testFormatDictWithNested() {
        let dict: [String: Any] = [
            "outer": ["inner": "value"]
        ]
        let result = GRPCLogger.formatDict(dict)
        XCTAssertTrue(result.contains("outer"))
        XCTAssertTrue(result.contains("inner"))
        XCTAssertTrue(result.contains("value"))
    }

    func testFormatDictWithArray() {
        let dict: [String: Any] = ["items": [1, 2, 3]]
        let result = GRPCLogger.formatDict(dict)
        XCTAssertTrue(result.contains("items"))
        XCTAssertTrue(result.contains("1"))
        XCTAssertTrue(result.contains("2"))
        XCTAssertTrue(result.contains("3"))
    }

    func testFormatDictWithBool() {
        let dict: [String: Any] = ["enabled": true, "disabled": false]
        let result = GRPCLogger.formatDict(dict)
        XCTAssertTrue(result.contains("enabled"))
        XCTAssertTrue(result.contains("disabled"))
    }

    func testFormatDictComplexPayload() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "device_type": 1,
            "tags": ["tag1": "value1"]
        ]
        let result = GRPCLogger.formatDict(dict)

        XCTAssertTrue(result.contains("hwid"))
        XCTAssertTrue(result.contains("test-hwid"))
        XCTAssertTrue(result.contains("application"))
        XCTAssertTrue(result.contains("XXXXX-XXXXX"))
    }
}
