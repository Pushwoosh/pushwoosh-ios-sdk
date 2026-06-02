//
//  DefaultLiveActivityAttributesTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities

@available(iOS 16.1, *)
final class DefaultLiveActivityAttributesTests: XCTestCase {

    /// Verifies DefaultLiveActivityAttributes survives Codable roundtrip with nested data.
    func test_codable_attributesRoundtrip() throws {
        let pushwoosh = PushwooshLiveActivityAttributeData(activityId: "act-1")
        let attributes = DefaultLiveActivityAttributes(
            data: ["orderNumber": AnyCodable("12345"), "active": AnyCodable(true)],
            pushwoosh: pushwoosh
        )

        let data = try JSONEncoder().encode(attributes)
        let decoded = try JSONDecoder().decode(DefaultLiveActivityAttributes.self, from: data)

        XCTAssertEqual(decoded.pushwoosh.activityId, "act-1")
        XCTAssertEqual(decoded.data["orderNumber"]?.asString(), "12345")
        XCTAssertEqual(decoded.data["active"]?.asBool(), true)
    }

    /// Verifies ContentState with nil pushwoosh metadata survives Codable roundtrip.
    func test_codable_contentStateRoundtrip_withNilPushwoosh() throws {
        let state = DefaultLiveActivityAttributes.ContentState(
            data: ["status": AnyCodable("Preparing")],
            pushwoosh: nil
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(DefaultLiveActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.data["status"]?.asString(), "Preparing")
        XCTAssertNil(decoded.pushwoosh)
    }
}
