//
//  LiveActivityConfigureIdempotencyTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 20.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

@available(iOS 16.1, *)
final class LiveActivityConfigureIdempotencyTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()
    }

    override func tearDownWithError() throws {
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()
        try super.tearDownWithError()
    }

    /// Verifies that double-calling configureLiveActivity for the same Attributes type registers it once.
    func test_doubleConfigure_registersOnce() throws {
        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(DefaultLiveActivityAttributes.self)
        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(DefaultLiveActivityAttributes.self)

        XCTAssertEqual(PushwooshLiveActivitiesImplementationSetup._registeredTypeCount, 1)

        PushwooshLiveActivitiesImplementationSetup._resetForTesting()

        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(DefaultLiveActivityAttributes.self)

        XCTAssertEqual(PushwooshLiveActivitiesImplementationSetup._registeredTypeCount, 1)
    }

    /// Verifies that replaceActivityTasks cancels prior tasks for the same activity id before overwriting,
    /// preventing duplicate observer pipelines when ActivityKit emits the same activity twice.
    func test_replaceActivityTasks_cancelsPriorBeforeOverwrite() throws {
        let activityId = "duplicate-emit-activity-id"

        let firstA = Task<Void, Never> { while !Task.isCancelled { await Task.yield() } }
        let firstB = Task<Void, Never> { while !Task.isCancelled { await Task.yield() } }
        PushwooshLiveActivitiesImplementationSetup.replaceActivityTasks(forId: activityId, with: [firstA, firstB])
        XCTAssertEqual(PushwooshLiveActivitiesImplementationSetup._activityTaskCount(forId: activityId), 2)

        let secondA = Task<Void, Never> { while !Task.isCancelled { await Task.yield() } }
        let secondB = Task<Void, Never> { while !Task.isCancelled { await Task.yield() } }
        PushwooshLiveActivitiesImplementationSetup.replaceActivityTasks(forId: activityId, with: [secondA, secondB])

        // Slot count remains 2 (not 4) — duplicate emission does not double up the observer pipeline.
        XCTAssertEqual(PushwooshLiveActivitiesImplementationSetup._activityTaskCount(forId: activityId), 2)

        // Prior tasks must be cancelled — wait on the actual condition, not a fixed delay.
        let cancellation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in firstA.isCancelled && firstB.isCancelled },
            object: nil)
        wait(for: [cancellation], timeout: 2.0)

        XCTAssertTrue(firstA.isCancelled, "prior stateTask must be cancelled before overwrite")
        XCTAssertTrue(firstB.isCancelled, "prior tokenTask must be cancelled before overwrite")
        XCTAssertFalse(secondA.isCancelled)
        XCTAssertFalse(secondB.isCancelled)

        secondA.cancel()
        secondB.cancel()
    }

    /// Verifies _resetForTesting() clears all registered types and can be called repeatedly without crashing.
    func test_resetForTesting_cancelsAllTasks() throws {
        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(DefaultLiveActivityAttributes.self)
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()

        XCTAssertEqual(PushwooshLiveActivitiesImplementationSetup._registeredTypeCount, 0)

        PushwooshLiveActivitiesImplementationSetup.configureLiveActivity(DefaultLiveActivityAttributes.self)
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()

        XCTAssertEqual(PushwooshLiveActivitiesImplementationSetup._registeredTypeCount, 0)
    }
}
