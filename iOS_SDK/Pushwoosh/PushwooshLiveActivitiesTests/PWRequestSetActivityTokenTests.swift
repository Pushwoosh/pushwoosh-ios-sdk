//
//  PWRequestSetActivityTokenTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

final class PWRequestSetActivityTokenTests: XCTestCase {

    /// Verifies prepareForExecution returns false when token is empty.
    func test_prepareForExecution_emptyToken_returnsFalse() throws {
        let params = ActivityRequestParameters(activityId: "act-1", token: "")
        let request = PWRequestSetActivityToken(parameters: params)

        XCTAssertFalse(request.prepareForExecution())
    }

    /// Verifies prepareForExecution returns false when token is nil.
    func test_prepareForExecution_nilToken_returnsFalse() throws {
        let params = ActivityRequestParameters(activityId: "act-1", token: nil)
        let request = PWRequestSetActivityToken(parameters: params)

        XCTAssertFalse(request.prepareForExecution())
    }

    /// Verifies prepareForExecution returns true with a valid token.
    func test_prepareForExecution_validToken_returnsTrue() throws {
        let params = ActivityRequestParameters(activityId: "act-1", token: "deadbeef")
        let request = PWRequestSetActivityToken(parameters: params)

        XCTAssertTrue(request.prepareForExecution())
    }

    /// Verifies the request dictionary emits both activity_id and activity_token.
    func test_requestDictionary_withActivityId_emitsBothFields() throws {
        let params = ActivityRequestParameters(activityId: "act-42", token: "token-1")
        let request = PWRequestSetActivityToken(parameters: params)

        let dict = request.requestDictionary()

        XCTAssertEqual(dict["activity_id"] as? String, "act-42")
        XCTAssertEqual(dict["activity_token"] as? String, "token-1")
    }

    /// H3 regression guard — nil activityId no longer crashes; emits empty string.
    func test_requestDictionary_withNilActivityId_emitsEmptyString() throws {
        let params = ActivityRequestParameters(activityId: nil, token: "token-1")
        let request = PWRequestSetActivityToken(parameters: params)

        let dict = request.requestDictionary()

        XCTAssertEqual(dict["activity_id"] as? String, "")
    }

    /// Verifies the request hits the setActivityToken backend method.
    func test_methodName_isSetActivityToken() throws {
        let params = ActivityRequestParameters(activityId: "act-1", token: "tok")
        let request = PWRequestSetActivityToken(parameters: params)

        XCTAssertEqual(request.methodName(), "setActivityToken")
    }
}
