//
//  CallCancellationTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 11.11.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshVoIP
import PushwooshCore
import CallKit
import PushKit

@available(iOS 14.0, *)
final class CallCancellationTests: XCTestCase {

    var implementation: PushwooshVoIPImplementation!
    var mockDelegate: MockVoIPDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        implementation = PushwooshVoIPImplementation.shared
        mockDelegate = MockVoIPDelegate()
        PushwooshVoIPImplementation.delegate = mockDelegate
        PWPreferences.preferencesInstance().voipAppCode = "TEST-APP"
    }

    override func tearDownWithError() throws {
        PushwooshVoIPImplementation.delegate = nil
        PWPreferences.preferencesInstance().voipAppCode = ""
        PWPreferences.preferencesInstance().voipPushToken = nil
        mockDelegate = nil
        try super.tearDownWithError()
    }

    // MARK: - Message Parsing Tests

    func testCancellationMessageParsing() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertTrue(message.cancelCall)
    }

    func testIncomingCallMessageWithCallId() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "callerName": "John Doe",
            "handleType": 2,
            "video": false,
            "cancelCall": false
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertFalse(message.cancelCall)
        XCTAssertEqual(message.callerName, "John Doe")
    }

    func testBackwardCompatibilityWithoutCallId() throws {
        let payload: [AnyHashable: Any] = [
            "callerName": "John Doe",
            "handleType": 1,
            "video": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNil(message.callId)
        XCTAssertFalse(message.cancelCall)
        XCTAssertEqual(message.callerName, "John Doe")
        XCTAssertTrue(message.hasVideo)
    }

    func testCancellationWithoutCallId() throws {
        let payload: [AnyHashable: Any] = [
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNil(message.callId)
        XCTAssertTrue(message.cancelCall)
    }

    // MARK: - Cancellation Scenarios

    func testCancellationPayloadStructure() throws {
        let cancellationPayload: [AnyHashable: Any] = [
            "callId": "call-xyz-789",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: cancellationPayload)

        XCTAssertNotNil(message.callId)
        XCTAssertTrue(message.cancelCall)
        XCTAssertEqual(message.callId, "call-xyz-789")
    }

    func testMultipleCancellationMessages() throws {
        let payload1: [AnyHashable: Any] = [
            "callId": "call-1",
            "cancelCall": true
        ]

        let payload2: [AnyHashable: Any] = [
            "callId": "call-2",
            "cancelCall": true
        ]

        let message1 = PWVoIPMessage(rawPayload: payload1)
        let message2 = PWVoIPMessage(rawPayload: payload2)

        XCTAssertEqual(message1.callId, "call-1")
        XCTAssertTrue(message1.cancelCall)
        XCTAssertEqual(message2.callId, "call-2")
        XCTAssertTrue(message2.cancelCall)
    }

    // MARK: - Delegate Callback Tests

    func testDelegateReceivesCancellationCallback() throws {
        let expectation = XCTestExpectation(description: "Delegate receives cancellation callback")

        mockDelegate.onCancelCall = { voipMessage in
            XCTAssertNotNil(voipMessage.callId)
            expectation.fulfill()
        }

        let payload: [AnyHashable: Any] = [
            "callId": "call-123",
            "callerName": "Test Caller"
        ]
        let message = PWVoIPMessage(rawPayload: payload)

        mockDelegate.voipDidCancelCall?(voipMessage: message)

        wait(for: [expectation], timeout: 1.0)
    }

    func testDelegateNotCalledWhenNotImplemented() throws {
        PushwooshVoIPImplementation.delegate = MinimalMockDelegate()

        let payload: [AnyHashable: Any] = [
            "callId": "call-123",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)
        XCTAssertNotNil(message)
    }

    func testDelegateReceivesFailureCallbackWithoutCallId() throws {
        let expectation = XCTestExpectation(description: "Delegate receives failure callback")

        mockDelegate.onFailToCancelCall = { callId, reason in
            XCTAssertNil(callId)
            XCTAssertTrue(reason.contains("without callId"))
            expectation.fulfill()
        }

        mockDelegate.voipDidFailToCancelCall?(callId: nil, reason: "Received cancel request without callId. Cannot cancel call.")

        wait(for: [expectation], timeout: 1.0)
    }

    func testDelegateReceivesFailureCallbackWhenCallNotFound() throws {
        let expectation = XCTestExpectation(description: "Delegate receives failure callback for missing call")

        mockDelegate.onFailToCancelCall = { callId, reason in
            XCTAssertEqual(callId, "call-nonexistent")
            XCTAssertTrue(reason.contains("No active call found"))
            expectation.fulfill()
        }

        mockDelegate.voipDidFailToCancelCall?(callId: "call-nonexistent", reason: "No active call found for callId: call-nonexistent")

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Edge Cases

    func testCallIdWithUnicodeCharacters() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-测试-🔔",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-测试-🔔")
        XCTAssertTrue(message.cancelCall)
    }

    func testCallIdWithVeryLongString() throws {
        let longCallId = String(repeating: "a", count: 1000)
        let payload: [AnyHashable: Any] = [
            "callId": longCallId,
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, longCallId)
        XCTAssertTrue(message.cancelCall)
    }

    func testCancellationWithAdditionalFields() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "cancelCall": true,
            "callerName": "Should be ignored",
            "customField": "customValue"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertTrue(message.cancelCall)
        XCTAssertEqual(message.rawPayload["customField"] as? String, "customValue")
    }

    func testCancelCallWithNSNull() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-123",
            "cancelCall": NSNull()
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertFalse(message.cancelCall)
    }

    // MARK: - Call Flow Tests

    func testCompleteCallFlow() throws {
        let incomingPayload: [AnyHashable: Any] = [
            "callId": "call-flow-123",
            "callerName": "John Doe",
            "handleType": 2,
            "video": false,
            "cancelCall": false
        ]

        let incomingMessage = PWVoIPMessage(rawPayload: incomingPayload)

        XCTAssertEqual(incomingMessage.callId, "call-flow-123")
        XCTAssertFalse(incomingMessage.cancelCall)

        let cancellationPayload: [AnyHashable: Any] = [
            "callId": "call-flow-123",
            "cancelCall": true
        ]

        let cancellationMessage = PWVoIPMessage(rawPayload: cancellationPayload)

        XCTAssertEqual(cancellationMessage.callId, "call-flow-123")
        XCTAssertTrue(cancellationMessage.cancelCall)
    }

    // MARK: - Failure Scenarios Tests

    func testCancellationFailsWithEmptyCallId() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "")
        XCTAssertTrue(message.cancelCall)
    }

    func testCancellationFailureReasonContainsCallId() throws {
        let callId = "call-missing-123"
        let expectedReason = "No active call found for callId: \(callId). Call may have already ended or been answered."

        mockDelegate.onFailToCancelCall = { receivedCallId, receivedReason in
            XCTAssertEqual(receivedCallId, callId)
            XCTAssertEqual(receivedReason, expectedReason)
        }

        mockDelegate.voipDidFailToCancelCall?(callId: callId, reason: expectedReason)
    }

    func testMultipleCancellationFailures() throws {
        var failureCount = 0

        mockDelegate.onFailToCancelCall = { _, _ in
            failureCount += 1
        }

        mockDelegate.voipDidFailToCancelCall?(callId: "call-1", reason: "Reason 1")
        mockDelegate.voipDidFailToCancelCall?(callId: "call-2", reason: "Reason 2")
        mockDelegate.voipDidFailToCancelCall?(callId: nil, reason: "Reason 3")

        XCTAssertEqual(failureCount, 3)
    }

    func testFailureReasonDescriptiveness() throws {
        let reasonWithoutCallId = "Received cancel request without callId. Cannot cancel call."
        let reasonNotFound = "No active call found for callId: test-id. Call may have already ended or been answered."

        XCTAssertTrue(reasonWithoutCallId.contains("without callId"))
        XCTAssertTrue(reasonNotFound.contains("No active call found"))
        XCTAssertTrue(reasonNotFound.contains("test-id"))
    }

    func testSuccessfulCancellationDoesNotTriggerFailure() throws {
        var failureCalled = false
        var successCalled = false

        mockDelegate.onFailToCancelCall = { _, _ in
            failureCalled = true
        }

        mockDelegate.onCancelCall = { _ in
            successCalled = true
        }

        let payload: [AnyHashable: Any] = [
            "callId": "call-success",
            "callerName": "John Doe"
        ]
        let message = PWVoIPMessage(rawPayload: payload)

        mockDelegate.voipDidCancelCall?(voipMessage: message)

        XCTAssertTrue(successCalled)
        XCTAssertFalse(failureCalled)
    }
}

// MARK: - Mock Delegates

@available(iOS 14.0, *)
class MockVoIPDelegate: NSObject, PWVoIPCallDelegate {
    var onCancelCall: ((PWVoIPMessage) -> Void)?
    var onFailToCancelCall: ((String?, String) -> Void)?
    var onReceiveIncomingCall: ((PWVoIPMessage) -> Void)?

    func voipDidReceiveIncomingCall(payload: PWVoIPMessage) {
        onReceiveIncomingCall?(payload)
    }

    func voipDidCancelCall(voipMessage: PWVoIPMessage) {
        onCancelCall?(voipMessage)
    }

    func voipDidFailToCancelCall(callId: String?, reason: String) {
        onFailToCancelCall?(callId, reason)
    }

    func pwProviderDidReset(_ provider: CXProvider) {}

    func pwProviderDidBegin(_ provider: CXProvider) {}
}

@available(iOS 14.0, *)
class MinimalMockDelegate: NSObject, PWVoIPCallDelegate {
    func voipDidReceiveIncomingCall(payload: PWVoIPMessage) {}

    func pwProviderDidReset(_ provider: CXProvider) {}

    func pwProviderDidBegin(_ provider: CXProvider) {}
}
