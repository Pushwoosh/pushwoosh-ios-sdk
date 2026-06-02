//
//  LiveActivityDismissalTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

@available(iOS 16.1, *)
final class LiveActivityDismissalTests: XCTestCase {

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

    /// Verifies the public stopLiveActivity(activityId:) entry routes a PWRequestStopLiveActivity
    /// (NOT a PWRequestSetActivityToken with empty token) through the seam — exercises the ADR-1 swap.
    func test_stopLiveActivity_routesStopRequest_notSetToken() throws {
        let captured = XCTestExpectation(description: "captured request")
        var capturedRequest: PWCoreSetLiveActivityTokenRequest?

        PushwooshLiveActivitiesImplementationSetup._requestSender = { request, completion in
            capturedRequest = request
            completion(nil)
            captured.fulfill()
        }

        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity(activityId: "act-dismiss-1")

        wait(for: [captured], timeout: 1.0)

        XCTAssertNotNil(capturedRequest)
        XCTAssertTrue(capturedRequest is PWRequestStopLiveActivity, "Dismissed/stopped activity must route via PWRequestStopLiveActivity")
        XCTAssertFalse(capturedRequest is PWRequestSetActivityToken, "Must NOT route as PWRequestSetActivityToken with empty token (silent-fail regression)")
    }

    /// Verifies startLiveActivity routes a PWRequestSetActivityToken via the seam.
    func test_startLiveActivity_routesSetActivityTokenRequest() throws {
        let captured = XCTestExpectation(description: "captured request")
        var capturedRequest: PWCoreSetLiveActivityTokenRequest?

        PushwooshLiveActivitiesImplementationSetup._requestSender = { request, completion in
            capturedRequest = request
            completion(nil)
            captured.fulfill()
        }

        PushwooshLiveActivitiesImplementationSetup.startLiveActivity(token: "deadbeef", activityId: "act-start-1")

        wait(for: [captured], timeout: 1.0)

        XCTAssertTrue(capturedRequest is PWRequestSetActivityToken)
    }

    /// Verifies the stop variant without activityId routes via PWRequestStopLiveActivity too.
    func test_stopLiveActivity_noActivityId_routesStopRequest() throws {
        let captured = XCTestExpectation(description: "captured request")
        var capturedRequest: PWCoreSetLiveActivityTokenRequest?

        PushwooshLiveActivitiesImplementationSetup._requestSender = { request, completion in
            capturedRequest = request
            completion(nil)
            captured.fulfill()
        }

        PushwooshLiveActivitiesImplementationSetup.stopLiveActivity()

        wait(for: [captured], timeout: 1.0)

        XCTAssertTrue(capturedRequest is PWRequestStopLiveActivity)
    }

    /// ADR-1 unit guard — verifies the dismissed-state factory emits a stop request, never a set-token request.
    /// Covers the actual `.dismissed` state-machine path (state observer is iOS-only / device-only at runtime).
    func test_dismissedActivityRequest_returnsStopRequestNotSetToken() throws {
        let req = PushwooshLiveActivitiesImplementationSetup.dismissedActivityRequest(forActivityId: "test-id")

        XCTAssertTrue(req is PWRequestStopLiveActivity)
        XCTAssertFalse(req is PWRequestSetActivityToken)
    }

    /// Verifies handleDismissedState routes a PWRequestStopLiveActivity through the seam — drives the
    /// extracted dismissal code path directly without requiring an `Activity<>` instance.
    func test_handleDismissedState_sendsStopRequest() throws {
        let captured = XCTestExpectation(description: "captured request")
        var capturedRequest: PWCoreSetLiveActivityTokenRequest?

        PushwooshLiveActivitiesImplementationSetup._requestSender = { request, completion in
            capturedRequest = request
            completion(nil)
            captured.fulfill()
        }

        PushwooshLiveActivitiesImplementationSetup.handleDismissedState(forActivityId: "test-id", runtimeActivityId: "test-id")

        wait(for: [captured], timeout: 1.0)

        XCTAssertNotNil(capturedRequest)
        XCTAssertTrue(capturedRequest is PWRequestStopLiveActivity)
        XCTAssertFalse(capturedRequest is PWRequestSetActivityToken)
    }
}
