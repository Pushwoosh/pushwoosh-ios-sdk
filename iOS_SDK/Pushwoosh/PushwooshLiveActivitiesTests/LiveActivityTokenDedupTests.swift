//
//  LiveActivityTokenDedupTests.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 08.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshLiveActivities
import PushwooshCore

@available(iOS 16.1, *)
final class LiveActivityTokenDedupTests: XCTestCase {

    private let activityId = "dedup-activity"
    private let token = "aabbccdd"

    override func setUpWithError() throws {
        try super.setUpWithError()
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()
    }

    override func tearDownWithError() throws {
        PushwooshLiveActivitiesImplementationSetup._requestSender = nil
        PushwooshLiveActivitiesImplementationSetup._resetForTesting()
        try super.tearDownWithError()
    }

    /// Verifies a claimed token blocks concurrent duplicate sends of the same token.
    func test_claim_blocksDuplicateWhileInFlight() {
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        XCTAssertFalse(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }

    /// Verifies a failed send releases the claim so a retry is allowed.
    func test_failedSend_releasesClaim_allowsRetry() {
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        PushwooshLiveActivitiesImplementationSetup.releaseActivityTokenClaim(token, forActivityId: activityId)
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }

    /// Verifies a server-confirmed token stays deduplicated across a process relaunch.
    func test_confirmedSend_persistsAcrossRelaunch() {
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        PushwooshLiveActivitiesImplementationSetup.markActivityTokenSent(token, forActivityId: activityId)
        PushwooshLiveActivitiesImplementationSetup._clearInFlightClaimsForTesting()
        XCTAssertFalse(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }

    /// Regression: a send whose completion is lost (process killed while the request was queued)
    /// must NOT poison the persisted cache — the next launch resends the token.
    func test_lostCompletion_doesNotBlockResendOnNextLaunch() {
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        PushwooshLiveActivitiesImplementationSetup._clearInFlightClaimsForTesting()
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }

    /// Verifies a rotated token passes the claim while the previous token is still in flight.
    func test_rotatedToken_passesClaimWhileOldInFlight() {
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend("eeff0011", forActivityId: activityId))
    }

    /// Verifies dismissal clears the persisted entry so a future activity reusing the id resends.
    func test_dismissal_clearsPersistedToken_allowsResend() {
        PushwooshLiveActivitiesImplementationSetup._requestSender = { _, completion in completion(nil) }
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        PushwooshLiveActivitiesImplementationSetup.markActivityTokenSent(token, forActivityId: activityId)

        PushwooshLiveActivitiesImplementationSetup.handleDismissedState(forActivityId: activityId, runtimeActivityId: "runtime-1")

        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }

    /// Verifies cancel(_:activityId:) clears the persisted token even though it tears down the
    /// state observer before end() — the .dismissed path that normally clears it never fires.
    func test_cancel_clearsPersistedToken_allowsResend() {
        guard #available(iOS 16.2, *) else { return }
        PushwooshLiveActivitiesImplementationSetup._requestSender = { _, completion in completion(nil) }
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
        PushwooshLiveActivitiesImplementationSetup.markActivityTokenSent(token, forActivityId: activityId)
        XCTAssertFalse(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))

        PushwooshLiveActivitiesImplementationSetup.cancel(DefaultLiveActivityAttributes.self, activityId: activityId)

        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }

    /// Verifies dismissal revokes an in-flight claim, so a late success completion does not
    /// resurrect the dead activity's token in the persisted cache.
    func test_dismissal_revokesInFlightClaim_lateSuccessDoesNotPersist() {
        PushwooshLiveActivitiesImplementationSetup._requestSender = { _, completion in completion(nil) }
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))

        PushwooshLiveActivitiesImplementationSetup.handleDismissedState(forActivityId: activityId, runtimeActivityId: "runtime-1")
        PushwooshLiveActivitiesImplementationSetup.markActivityTokenSent(token, forActivityId: activityId)

        PushwooshLiveActivitiesImplementationSetup._clearInFlightClaimsForTesting()
        XCTAssertTrue(PushwooshLiveActivitiesImplementationSetup.claimActivityTokenForSend(token, forActivityId: activityId))
    }
}
