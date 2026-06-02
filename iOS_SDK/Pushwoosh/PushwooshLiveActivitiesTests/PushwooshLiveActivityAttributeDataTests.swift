//
//  PushwooshLiveActivityAttributeDataTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities

final class PushwooshLiveActivityAttributeDataTests: XCTestCase {

    /// Verifies the init constructor stores activityId.
    func test_init_setsActivityId() throws {
        let data = PushwooshLiveActivityAttributeData(activityId: "act-1")

        XCTAssertEqual(data.activityId, "act-1")
    }

    /// Verifies the static create() factory returns an instance with the supplied activityId.
    func test_create_returnsStructWithActivityId() throws {
        let data = PushwooshLiveActivityAttributeData.create(activityId: "act-2")

        XCTAssertEqual(data.activityId, "act-2")
    }

    /// Verifies PushwooshLiveActivityAttributeData survives Codable roundtrip.
    func test_codable_roundtrip() throws {
        let original = PushwooshLiveActivityAttributeData(activityId: "act-3")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PushwooshLiveActivityAttributeData.self, from: data)

        XCTAssertEqual(decoded.activityId, "act-3")
    }
}
