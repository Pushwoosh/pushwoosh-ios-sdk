//
//  PushwooshLiveActivitiesImplementationSetupTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

final class PushwooshLiveActivitiesImplementationSetupTests: XCTestCase {

    private var savedAppCode: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedAppCode = PWPreferences.preferencesInstance().appCode
        PWPreferences.preferencesInstance().appCode = TestConstants.appCode
        let ready = XCTestExpectation(description: "sdk ready")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ready.fulfill() }
        wait(for: [ready], timeout: 1.0)
    }

    override func tearDownWithError() throws {
        PushwooshLiveActivitiesImplementationSetup._requestSender = nil
        PWPreferences.preferencesInstance().appCode = savedAppCode ?? ""
        try super.tearDownWithError()
    }

    /// Verifies liveActivities() returns the implementation class itself.
    func test_liveActivities_returnsImplementationSelf() throws {
        let cls = PushwooshLiveActivitiesImplementationSetup.liveActivities()

        XCTAssertTrue(cls is PushwooshLiveActivitiesImplementationSetup.Type)
    }

    /// Verifies that send() short-circuits with an error when prepareForExecution returns false.
    /// _requestSender is intentionally left nil to exercise the real prepareForExecution guard.
    func test_send_failsCompletion_whenPrepareReturnsFalse() throws {
        let completion = XCTestExpectation(description: "completion fired")
        var capturedError: Error?

        PushwooshLiveActivitiesImplementationSetup.sendPushToStartLiveActivity(token: "", completion: { error in
            capturedError = error
            completion.fulfill()
        })

        wait(for: [completion], timeout: 1.0)

        XCTAssertNotNil(capturedError)
        XCTAssertEqual((capturedError as NSError?)?.domain, "pushwoosh")
        XCTAssertEqual((capturedError as NSError?)?.code, 1)
    }
}
