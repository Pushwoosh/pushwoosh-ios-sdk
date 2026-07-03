//
//  PushwooshLiveActivitiesImplementationSetupTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import ActivityKit
@testable import PushwooshLiveActivities
import PushwooshCore

final class PushwooshLiveActivitiesImplementationSetupTests: XCTestCase {

    private var savedAppCode: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedAppCode = PWPreferences.preferencesInstance().appCode
        PWPreferences.preferencesInstance().appCode = TestConstants.appCode
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

    /// Verifies that scheduling a default Live Activity on iOS < 26 fails the completion with the
    /// version-required error instead of starting anything. Skipped on iOS 26+, where the gate is absent.
    func test_defaultStartAt_belowiOS26_failsWithVersionError() throws {
        if #available(iOS 26.0, *) {
            throw XCTSkip("Scheduling is supported on this OS; the version gate does not apply.")
        }

        let completion = XCTestExpectation(description: "completion fired")
        var capturedError: Error?

        PushwooshLiveActivitiesImplementationSetup.defaultStart(
            "sched_1",
            attributes: ["team": "Lakers"],
            content: ["score": "0:0"],
            at: Date().addingTimeInterval(3600),
            alertTitle: "Game starting",
            alertBody: "Lakers vs Celtics"
        ) { error in
            capturedError = error
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1.0)

        XCTAssertNotNil(capturedError)
        XCTAssertEqual((capturedError as NSError?)?.domain, "pushwoosh")
        XCTAssertEqual((capturedError as NSError?)?.code, 4)
    }

    /// Verifies cancel(_:activityId:) notifies the server with a PWRequestStopLiveActivity carrying the
    /// given activityId. The on-device end()/observer-dedup path runs only with a live ActivityKit
    /// activity, so in the unit host Activity.activities is empty and only the server-notify path executes.
    func test_cancel_sendsStopRequestWithActivityId() throws {
        guard #available(iOS 16.2, *) else {
            throw XCTSkip("cancel(_:activityId:) requires iOS 16.2+.")
        }
        if !Activity<DefaultLiveActivityAttributes>.activities.isEmpty {
            throw XCTSkip("A live DefaultLiveActivityAttributes activity is present (e.g. left over from an E2E run); cancel() would also drive the on-device end path, so this server-notify assertion is not isolated.")
        }
        let sent = XCTestExpectation(description: "stop request sent")
        var capturedRequest: PWCoreSetLiveActivityTokenRequest?
        PushwooshLiveActivitiesImplementationSetup._requestSender = { request, completion in
            capturedRequest = request
            completion(nil)
            sent.fulfill()
        }

        PushwooshLiveActivitiesImplementationSetup.cancel(DefaultLiveActivityAttributes.self, activityId: "cancel-1")

        wait(for: [sent], timeout: 1.0)

        XCTAssertTrue(capturedRequest is PWRequestStopLiveActivity)
        XCTAssertEqual((capturedRequest as? PWRequestStopLiveActivity)?.parameters.activityId, "cancel-1")
    }
}
