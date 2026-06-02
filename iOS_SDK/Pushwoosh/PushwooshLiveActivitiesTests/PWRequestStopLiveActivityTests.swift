//
//  PWRequestStopLiveActivityTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

final class PWRequestStopLiveActivityTests: XCTestCase {

    /// Verifies prepareForExecution unconditionally returns true (stop has no token to check).
    func test_prepareForExecution_alwaysTrue() throws {
        let request = PWRequestStopLiveActivity(parameters: ActivityRequestParameters())

        XCTAssertTrue(request.prepareForExecution())
    }

    /// Verifies the request dictionary emits an empty string for activity_token (the server's stop signal) and supplied activity_id.
    func test_requestDictionary_emitsEmptyStringTokenAndIncludesActivityId() throws {
        let params = ActivityRequestParameters(activityId: "act-stop-1")
        let request = PWRequestStopLiveActivity(parameters: params)

        let dict = request.requestDictionary()

        XCTAssertEqual(dict["activity_token"] as? String, "",
                       "activity_token must be empty string — the server overwrites the existing token with this empty value to stop the activity")
        XCTAssertEqual(dict["activity_id"] as? String, "act-stop-1")
    }

    /// Verifies the request dictionary serialises to JSON containing `"activity_token":""` literally.
    func test_requestDictionary_jsonSerialisesEmptyStringToken() throws {
        let params = ActivityRequestParameters(activityId: "act-stop-2")
        let request = PWRequestStopLiveActivity(parameters: params)

        let data = try JSONSerialization.data(withJSONObject: request.requestDictionary(), options: [])
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("\"activity_token\":\"\""),
                      "Expected literal empty string for activity_token, got: \(json)")
    }

    /// Verifies missing activity_id is encoded as empty string, not crashed.
    func test_requestDictionary_withNilActivityId_emitsEmptyString() throws {
        let request = PWRequestStopLiveActivity(parameters: ActivityRequestParameters())

        let dict = request.requestDictionary()

        XCTAssertEqual(dict["activity_id"] as? String, "")
    }

    /// Verifies the stop request shares the setActivityToken method name with the set-token request.
    func test_methodName_isSetActivityToken() throws {
        let request = PWRequestStopLiveActivity(parameters: ActivityRequestParameters())

        XCTAssertEqual(request.methodName(), "setActivityToken")
    }
}
