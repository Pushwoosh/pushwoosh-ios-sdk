//
//  PWVoIPMessageTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 24.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshVoIP
import CallKit

@available(iOS 14.0, *)
final class PWVoIPMessageTests: XCTestCase {

    func testMessageParsingWithFullData() throws {
        let payload: [AnyHashable: Any] = [
            "uuid": "test-uuid-123",
            "handleType": 2,
            "callerName": "John Doe",
            "video": true,
            "supportsHolding": true,
            "supportsDTMF": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.uuid, "test-uuid-123")
        XCTAssertEqual(message.handleType, .phoneNumber)
        XCTAssertEqual(message.callerName, "John Doe")
        XCTAssertTrue(message.hasVideo)
        XCTAssertTrue(message.supportsHolding)
        XCTAssertTrue(message.supportsDTMF)
    }

    func testMessageParsingWithMinimalData() throws {
        let payload: [AnyHashable: Any] = [:]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.uuid, "")
        XCTAssertEqual(message.handleType, .generic)
        XCTAssertEqual(message.callerName, "")
        XCTAssertFalse(message.hasVideo)
        XCTAssertFalse(message.supportsHolding)
        XCTAssertFalse(message.supportsDTMF)
    }

    func testMessageHandleTypeGeneric() throws {
        let payload: [AnyHashable: Any] = ["handleType": 1]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.handleType, .generic)
    }

    func testMessageHandleTypePhoneNumber() throws {
        let payload: [AnyHashable: Any] = ["handleType": 2]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.handleType, .phoneNumber)
    }

    func testMessageHandleTypeEmail() throws {
        let payload: [AnyHashable: Any] = ["handleType": 3]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.handleType, .email)
    }

    func testMessageHandleTypeInvalid() throws {
        let payload: [AnyHashable: Any] = ["handleType": 999]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.handleType, .generic)
    }

    func testMessageRawPayloadPreserved() throws {
        let payload: [AnyHashable: Any] = [
            "callerName": "Test Caller",
            "customField": "custom value"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.rawPayload["callerName"] as? String, "Test Caller")
        XCTAssertEqual(message.rawPayload["customField"] as? String, "custom value")
    }

    func testMessageVideoFlagTrue() throws {
        let payload: [AnyHashable: Any] = ["video": true]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertTrue(message.hasVideo)
    }

    func testMessageVideoFlagFalse() throws {
        let payload: [AnyHashable: Any] = ["video": false]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertFalse(message.hasVideo)
    }

    func testMessageSupportsHoldingTrue() throws {
        let payload: [AnyHashable: Any] = ["supportsHolding": true]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertTrue(message.supportsHolding)
    }

    func testMessageSupportsHoldingFalse() throws {
        let payload: [AnyHashable: Any] = ["supportsHolding": false]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertFalse(message.supportsHolding)
    }

    func testMessageSupportsDTMFTrue() throws {
        let payload: [AnyHashable: Any] = ["supportsDTMF": true]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertTrue(message.supportsDTMF)
    }

    func testMessageSupportsDTMFFalse() throws {
        let payload: [AnyHashable: Any] = ["supportsDTMF": false]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertFalse(message.supportsDTMF)
    }

    func testMessageCallerNameWithEmptyString() throws {
        let payload: [AnyHashable: Any] = ["callerName": ""]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callerName, "")
    }

    func testMessageCallerNameWithSpecialCharacters() throws {
        let payload: [AnyHashable: Any] = ["callerName": "Test Caller +1 (555) 123-4567"]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callerName, "Test Caller +1 (555) 123-4567")
    }

    func testMessageUUIDWithEmptyString() throws {
        let payload: [AnyHashable: Any] = ["uuid": ""]
        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.uuid, "")
    }

    func testMessageComplexPayloadPreservation() throws {
        let payload: [AnyHashable: Any] = [
            "callerName": "John Doe",
            "customData": ["key1": "value1", "key2": 42],
            "metadata": ["timestamp": 1234567890]
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotNil(message.rawPayload["customData"])
        XCTAssertNotNil(message.rawPayload["metadata"])
    }

    func testHandleTypeEnumToCallKitConversionGeneric() throws {
        let handleType = PWVoIPHandleType.generic
        let cxHandleType = handleType.toCXHandleType

        XCTAssertEqual(cxHandleType, .generic)
    }

    func testHandleTypeEnumToCallKitConversionPhoneNumber() throws {
        let handleType = PWVoIPHandleType.phoneNumber
        let cxHandleType = handleType.toCXHandleType

        XCTAssertEqual(cxHandleType, .phoneNumber)
    }

    func testHandleTypeEnumToCallKitConversionEmail() throws {
        let handleType = PWVoIPHandleType.email
        let cxHandleType = handleType.toCXHandleType

        XCTAssertEqual(cxHandleType, .emailAddress)
    }

    // MARK: - Call Cancellation Tests

    func testMessageCallIdParsing() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "callerName": "John Doe"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertFalse(message.cancelCall)
    }

    func testMessageCallIdNil() throws {
        let payload: [AnyHashable: Any] = [
            "callerName": "John Doe"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNil(message.callId)
        XCTAssertFalse(message.cancelCall)
    }

    func testMessageCancelCallTrue() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertTrue(message.cancelCall)
    }

    func testMessageCancelCallFalse() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "cancelCall": false
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertFalse(message.cancelCall)
    }

    func testMessageCancelCallDefaultsToFalse() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertFalse(message.cancelCall)
    }

    func testIncomingCallPayload() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "callerName": "John Doe",
            "handleType": 2,
            "video": false,
            "cancelCall": false
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertEqual(message.callerName, "John Doe")
        XCTAssertEqual(message.handleType, .phoneNumber)
        XCTAssertFalse(message.hasVideo)
        XCTAssertFalse(message.cancelCall)
    }

    func testCancellationPayload() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-12345",
            "cancelCall": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-12345")
        XCTAssertTrue(message.cancelCall)
    }

    func testCallIdWithSpecialCharacters() throws {
        let payload: [AnyHashable: Any] = [
            "callId": "call-abc-123-xyz-789"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "call-abc-123-xyz-789")
    }

    func testCallIdWithEmptyString() throws {
        let payload: [AnyHashable: Any] = [
            "callId": ""
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "")
    }

    func testCallIdAsInteger() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 12345
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "12345")
    }

    func testCallIdAsInt64() throws {
        let payload: [AnyHashable: Any] = [
            "callId": Int64(9876543210)
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "9876543210")
    }

    func testCallIdAsDouble() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 123.0
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "123")
    }

    func testCallIdAsDoubleWithDecimal() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 123.456
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "123.456")
    }

    func testCallIdAsFloat() throws {
        let payload: [AnyHashable: Any] = [
            "callId": Float(456.0)
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "456")
    }

    func testCallIdAsFloatWithDecimal() throws {
        let payload: [AnyHashable: Any] = [
            "callId": Float(456.789)
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "456.789")
    }

    func testCallIdAsNegativeInteger() throws {
        let payload: [AnyHashable: Any] = [
            "callId": -999
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "-999")
    }

    func testCallIdAsZero() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 0
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "0")
    }

    func testCallIdMixedPayloadWithIntegerCallId() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 98765,
            "callerName": "Jane Smith",
            "video": true,
            "cancelCall": false
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "98765")
        XCTAssertEqual(message.callerName, "Jane Smith")
        XCTAssertTrue(message.hasVideo)
        XCTAssertFalse(message.cancelCall)
    }

    func testCallIdAsBoolean() throws {
        let payload: [AnyHashable: Any] = [
            "callId": true
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotNil(message.callId)
        XCTAssertEqual(message.callId, "true")
    }

    func testCallIdAsArray() throws {
        let payload: [AnyHashable: Any] = [
            "callId": [1, 2, 3]
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotNil(message.callId)
    }

    func testCallIdAsDictionary() throws {
        let payload: [AnyHashable: Any] = [
            "callId": ["key": "value"]
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotNil(message.callId)
    }

    func testCallIdAsNSNull() throws {
        let payload: [AnyHashable: Any] = [
            "callId": NSNull()
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNil(message.callId)
    }

    func testCallIdAsLargeInteger() throws {
        let payload: [AnyHashable: Any] = [
            "callId": Int.max
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, String(Int.max))
    }

    func testCallIdAsVerySmallDouble() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 0.0000001
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotNil(message.callId)
    }

    func testCallIdTypeStabilityString() throws {
        let payload1: [AnyHashable: Any] = ["callId": "test"]
        let payload2: [AnyHashable: Any] = ["callId": "test"]

        let message1 = PWVoIPMessage(rawPayload: payload1)
        let message2 = PWVoIPMessage(rawPayload: payload2)

        XCTAssertEqual(message1.callId, message2.callId)
    }

    func testCallIdTypeStabilityInteger() throws {
        let payload1: [AnyHashable: Any] = ["callId": 999]
        let payload2: [AnyHashable: Any] = ["callId": 999]

        let message1 = PWVoIPMessage(rawPayload: payload1)
        let message2 = PWVoIPMessage(rawPayload: payload2)

        XCTAssertEqual(message1.callId, message2.callId)
    }

    func testCallIdIntegerZeroDoesNotConvertToEmptyString() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 0
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotEqual(message.callId, "")
        XCTAssertEqual(message.callId, "0")
    }

    func testCallIdDoubleZeroConvertsToZeroString() throws {
        let payload: [AnyHashable: Any] = [
            "callId": 0.0
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertEqual(message.callId, "0")
    }
}
