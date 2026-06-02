//
//  PWRequestSetPushToStartTokenTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

final class PWRequestSetPushToStartTokenTests: XCTestCase {

    /// Verifies prepareForExecution returns false when push-to-start token is empty.
    func test_prepareForExecution_emptyToken_returnsFalse() throws {
        let params = ActivityRequestParameters(pushToStartToken: "")
        let request = PWRequestSetPushToStartToken(parameters: params)

        XCTAssertFalse(request.prepareForExecution())
    }

    /// Verifies prepareForExecution returns false when push-to-start token is nil.
    func test_prepareForExecution_nilToken_returnsFalse() throws {
        let params = ActivityRequestParameters(pushToStartToken: nil)
        let request = PWRequestSetPushToStartToken(parameters: params)

        XCTAssertFalse(request.prepareForExecution())
    }

    /// Verifies prepareForExecution returns true for a valid token.
    func test_prepareForExecution_validToken_returnsTrue() throws {
        let params = ActivityRequestParameters(pushToStartToken: "abcd1234")
        let request = PWRequestSetPushToStartToken(parameters: params)

        XCTAssertTrue(request.prepareForExecution())
    }

    /// Verifies the request dictionary includes the push-to-start token under the expected key.
    func test_requestDictionary_includesToken() throws {
        let params = ActivityRequestParameters(pushToStartToken: "abcd1234")
        let request = PWRequestSetPushToStartToken(parameters: params)

        let dict = request.requestDictionary()

        XCTAssertEqual(dict["activity_push_to_start_token"] as? String, "abcd1234")
    }

    /// Verifies the request hits the setActivityPushToStartToken backend method.
    func test_methodName_isSetActivityPushToStartToken() throws {
        let params = ActivityRequestParameters(pushToStartToken: "abcd1234")
        let request = PWRequestSetPushToStartToken(parameters: params)

        XCTAssertEqual(request.methodName(), "setActivityPushToStartToken")
    }
}
