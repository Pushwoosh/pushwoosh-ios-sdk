//
//  GRPCRequestBuildersTests.swift
//  PushwooshGRPCTests
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshGRPC

final class GRPCRequestBuildersTests: XCTestCase {

    // MARK: - RegisterDevice Tests

    func testRegisterDeviceWithAllFields() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "device_type": 1,
            "push_token": "test-token",
            "userId": "user123",
            "language": "en",
            "app_version": "1.0.0",
            "device_model": "iPhone15,1",
            "os_version": "17.0",
            "v": "6.0.0",
            "timezone": "3600"
        ]

        let request = GRPCRequestBuilders.registerDevice(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.platform, 1)
        XCTAssertEqual(request.pushToken, "test-token")
        XCTAssertEqual(request.userID, "user123")
        XCTAssertEqual(request.language, "en")
        XCTAssertEqual(request.appVersion, "1.0.0")
        XCTAssertEqual(request.deviceModel, "iPhone15,1")
        XCTAssertEqual(request.osVersion, "17.0")
        XCTAssertEqual(request.sdkVersion, "6.0.0")
        XCTAssertEqual(request.timezone, "3600")
    }

    func testRegisterDeviceWithMissingFields() {
        let dict: [String: Any] = [:]
        let request = GRPCRequestBuilders.registerDevice(from: dict)

        XCTAssertEqual(request.hwid, "")
        XCTAssertEqual(request.application, "")
        XCTAssertEqual(request.platform, 1) // default
        XCTAssertEqual(request.pushToken, "")
    }

    func testRegisterDeviceWithTags() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "tags": ["key1": "value1", "key2": 42]
        ]

        let request = GRPCRequestBuilders.registerDevice(from: dict)

        XCTAssertTrue(request.hasTags)
    }

    // MARK: - UnregisterDevice Tests

    func testUnregisterDevice() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX"
        ]

        let request = GRPCRequestBuilders.unregisterDevice(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
    }

    // MARK: - SetTags Tests

    func testSetTags() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "userId": "user123",
            "device_type": 1,
            "tags": ["tag1": "value1", "tag2": 123]
        ]

        let request = GRPCRequestBuilders.setTags(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.userID, "user123")
        XCTAssertEqual(request.platform, 1)
        XCTAssertTrue(request.hasTags)
    }

    // MARK: - GetTags Tests

    func testGetTags() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "userId": "user123"
        ]

        let request = GRPCRequestBuilders.getTags(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.userID, "user123")
    }

    // MARK: - ApplicationOpen Tests

    func testApplicationOpen() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "device_type": 1,
            "language": "en",
            "app_version": "1.0.0",
            "device_model": "iPhone15,1",
            "os_version": "17.0",
            "v": "6.0.0",
            "timezone": "3600",
            "userId": "user123"
        ]

        let request = GRPCRequestBuilders.applicationOpen(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.platform, 1)
        XCTAssertEqual(request.language, "en")
        XCTAssertEqual(request.appVersion, "1.0.0")
        XCTAssertEqual(request.deviceModel, "iPhone15,1")
        XCTAssertEqual(request.osVersion, "17.0")
        XCTAssertEqual(request.sdkVersion, "6.0.0")
        XCTAssertEqual(request.timezone, "3600")
        XCTAssertEqual(request.userID, "user123")
    }

    // MARK: - PushStat Tests

    func testPushStat() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "hash": "abc123",
            "device_type": 1,
            "userId": "user123"
        ]

        let request = GRPCRequestBuilders.pushStat(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.hash, "abc123")
        XCTAssertEqual(request.platform, 1)
        XCTAssertEqual(request.userID, "user123")
    }

    // MARK: - MessageDelivery Tests

    func testMessageDelivery() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "hash": "msg-hash",
            "device_type": 1,
            "userId": "user123"
        ]

        let request = GRPCRequestBuilders.messageDelivery(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.hash, "msg-hash")
        XCTAssertEqual(request.platform, 1)
        XCTAssertEqual(request.userID, "user123")
    }

    // MARK: - SetBadge Tests

    func testSetBadge() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "badge": 5
        ]

        let request = GRPCRequestBuilders.setBadge(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.badge, 5)
    }

    func testSetBadgeZero() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "badge": 0
        ]

        let request = GRPCRequestBuilders.setBadge(from: dict)
        XCTAssertEqual(request.badge, 0)
    }

    // MARK: - GetInApps Tests

    func testGetInApps() {
        let dict: [String: Any] = [
            "application": "XXXXX-XXXXX"
        ]

        let request = GRPCRequestBuilders.getInApps(from: dict)

        XCTAssertEqual(request.application, "XXXXX-XXXXX")
    }

    // MARK: - RegisterUser Tests

    func testRegisterUser() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "userId": "user123",
            "device_type": 1
        ]

        let request = GRPCRequestBuilders.registerUser(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.userID, "user123")
        XCTAssertEqual(request.platform, 1)
    }

    // MARK: - SetActivityToken Tests

    func testSetActivityToken() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "activity_token": "activity-token-123",
            "activity_id": "activity-id-456"
        ]

        let request = GRPCRequestBuilders.setActivityToken(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.activityToken, "activity-token-123")
        XCTAssertEqual(request.activityID, "activity-id-456")
    }

    // MARK: - SetActivityPushToStartToken Tests

    func testSetActivityPushToStartToken() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "activity_push_to_start_token": "push-to-start-token"
        ]

        let request = GRPCRequestBuilders.setActivityPushToStartToken(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.activityPushToStartToken, "push-to-start-token")
    }

    // MARK: - RichMediaAction Tests

    func testRichMediaAction() {
        let dict: [String: Any] = [
            "application": "XXXXX-XXXXX",
            "hwid": "test-hwid",
            "userId": "user123",
            "inapp_code": "inapp-code",
            "rich_media_code": "rm-code",
            "message_hash": "msg-hash",
            "device_type": 1,
            "action_type": 2,
            "action_attributes": ["key": "value"]
        ]

        let request = GRPCRequestBuilders.richMediaAction(from: dict)

        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.userID, "user123")
        XCTAssertEqual(request.inappCode, "inapp-code")
        XCTAssertEqual(request.richMediaCode, "rm-code")
        XCTAssertEqual(request.messageHash, "msg-hash")
        XCTAssertEqual(request.platform, 1)
        XCTAssertEqual(request.actionType, 2)
        XCTAssertFalse(request.actionAttributes.isEmpty)
    }

    // MARK: - PostEvent Tests

    func testPostEvent() {
        let dict: [String: Any] = [
            "hwid": "test-hwid",
            "application": "XXXXX-XXXXX",
            "event": "test_event",
            "userId": "user123",
            "device_type": 1,
            "timestampUTC": 1234567890,
            "v": "6.0.0",
            "attributes": ["attr1": "value1"]
        ]

        let request = GRPCRequestBuilders.postEvent(from: dict)

        XCTAssertEqual(request.hwid, "test-hwid")
        XCTAssertEqual(request.application, "XXXXX-XXXXX")
        XCTAssertEqual(request.event, "test_event")
        XCTAssertEqual(request.userID, "user123")
        XCTAssertEqual(request.platform, 1)
        XCTAssertEqual(request.timestamp, 1234567890)
        XCTAssertEqual(request.sdkVersion, "6.0.0")
        XCTAssertTrue(request.hasAttributes)
    }

    // MARK: - Type Conversion Tests

    func testDeviceTypeConversion() {
        let dictIOS: [String: Any] = ["device_type": 1]
        let dictAndroid: [String: Any] = ["device_type": 3]
        let dictMissing: [String: Any] = [:]

        XCTAssertEqual(GRPCRequestBuilders.registerDevice(from: dictIOS).platform, 1)
        XCTAssertEqual(GRPCRequestBuilders.registerDevice(from: dictAndroid).platform, 3)
        XCTAssertEqual(GRPCRequestBuilders.registerDevice(from: dictMissing).platform, 1) // default
    }
}
