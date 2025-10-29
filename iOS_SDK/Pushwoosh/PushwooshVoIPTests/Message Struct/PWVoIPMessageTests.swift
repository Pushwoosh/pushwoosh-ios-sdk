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
}
