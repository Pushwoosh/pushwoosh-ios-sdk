//
//  GRPCFramingTests.swift
//  PushwooshGRPCTests
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshGRPC

final class GRPCFramingTests: XCTestCase {

    // MARK: - Frame Tests

    func testFrameEmptyMessage() {
        let message = Data()
        let framed = GRPCFraming.frame(message)

        XCTAssertEqual(framed.count, 5)
        XCTAssertEqual(framed[0], 0) // compression flag
        XCTAssertEqual(framed[1], 0) // length bytes
        XCTAssertEqual(framed[2], 0)
        XCTAssertEqual(framed[3], 0)
        XCTAssertEqual(framed[4], 0)
    }

    func testFrameSmallMessage() {
        let message = Data([0x01, 0x02, 0x03])
        let framed = GRPCFraming.frame(message)

        XCTAssertEqual(framed.count, 8)
        XCTAssertEqual(framed[0], 0) // compression flag
        XCTAssertEqual(framed[1], 0) // length = 3 (big endian)
        XCTAssertEqual(framed[2], 0)
        XCTAssertEqual(framed[3], 0)
        XCTAssertEqual(framed[4], 3)
        XCTAssertEqual(framed[5], 0x01) // message data
        XCTAssertEqual(framed[6], 0x02)
        XCTAssertEqual(framed[7], 0x03)
    }

    func testFrameLargeMessage() {
        let message = Data(repeating: 0xAB, count: 1000)
        let framed = GRPCFraming.frame(message)

        XCTAssertEqual(framed.count, 1005)
        XCTAssertEqual(framed[0], 0) // compression flag
        // length = 1000 = 0x000003E8 (big endian)
        XCTAssertEqual(framed[1], 0x00)
        XCTAssertEqual(framed[2], 0x00)
        XCTAssertEqual(framed[3], 0x03)
        XCTAssertEqual(framed[4], 0xE8)
    }

    // MARK: - Parse Tests

    func testParseEmptyData() {
        let data = Data()
        let result = GRPCFraming.parse(data)
        XCTAssertNil(result)
    }

    func testParseTooShortData() {
        let data = Data([0x00, 0x00, 0x00, 0x00]) // only 4 bytes
        let result = GRPCFraming.parse(data)
        XCTAssertNil(result)
    }

    func testParseEmptyMessage() {
        let data = Data([0x00, 0x00, 0x00, 0x00, 0x00]) // header with length 0
        let result = GRPCFraming.parse(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 0)
    }

    func testParseValidMessage() {
        let data = Data([0x00, 0x00, 0x00, 0x00, 0x03, 0x01, 0x02, 0x03])
        let result = GRPCFraming.parse(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result, Data([0x01, 0x02, 0x03]))
    }

    func testParseTruncatedMessage() {
        // Header says 10 bytes but only 3 bytes of data
        let data = Data([0x00, 0x00, 0x00, 0x00, 0x0A, 0x01, 0x02, 0x03])
        let result = GRPCFraming.parse(data)
        XCTAssertNil(result)
    }

    func testParseMessageWithExtraData() {
        // Header says 3 bytes, but there are 5 bytes of data - should only return 3
        let data = Data([0x00, 0x00, 0x00, 0x00, 0x03, 0x01, 0x02, 0x03, 0x04, 0x05])
        let result = GRPCFraming.parse(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result, Data([0x01, 0x02, 0x03]))
    }

    func testParseOverflowProtection() {
        // Header says message is larger than 10MB - should reject
        let data = Data([0x00, 0x01, 0x00, 0x00, 0x00]) // 16MB
        let result = GRPCFraming.parse(data)
        XCTAssertNil(result)
    }

    // MARK: - Round Trip Tests

    func testFrameAndParse() {
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let framed = GRPCFraming.frame(original)
        let parsed = GRPCFraming.parse(framed)

        XCTAssertEqual(parsed, original)
    }

    func testFrameAndParseLargeMessage() {
        let original = Data(repeating: 0x42, count: 10000)
        let framed = GRPCFraming.frame(original)
        let parsed = GRPCFraming.parse(framed)

        XCTAssertEqual(parsed, original)
    }
}
