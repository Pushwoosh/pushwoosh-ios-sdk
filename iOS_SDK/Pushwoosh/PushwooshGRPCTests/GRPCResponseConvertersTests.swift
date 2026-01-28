//
//  GRPCResponseConvertersTests.swift
//  PushwooshGRPCTests
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshGRPC
import SwiftProtobuf

final class GRPCResponseConvertersTests: XCTestCase {

    // MARK: - Nil Response Tests

    func testNilResponseReturnsEmptyDict() {
        let result: [String: Any] = GRPCResponseConverters.toDictionary(nil as Pushwoosh_DeviceApi_V2_GetTagsResponse?)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - GetTags Response Tests

    func testGetTagsResponseWithResult() throws {
        var response = Pushwoosh_DeviceApi_V2_GetTagsResponse()
        let tagsDict: [String: Any] = ["tag1": "value1", "tag2": 123]
        let jsonData = try JSONSerialization.data(withJSONObject: tagsDict)
        response.result = try Google_Protobuf_Struct(jsonUTF8Data: jsonData)

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNotNil(result["result"])
        if let resultDict = result["result"] as? [String: Any] {
            XCTAssertEqual(resultDict["tag1"] as? String, "value1")
            XCTAssertEqual(resultDict["tag2"] as? Int, 123)
        }
    }

    // MARK: - GetInApps Response Tests

    func testGetInAppsResponseEmpty() {
        let response = Pushwoosh_DeviceApi_V2_GetInAppsResponse()
        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNotNil(result["inApps"])
        if let inApps = result["inApps"] as? [[String: Any]] {
            XCTAssertTrue(inApps.isEmpty)
        }
    }

    func testGetInAppsResponseWithInApps() {
        var response = Pushwoosh_DeviceApi_V2_GetInAppsResponse()

        var inApp = Pushwoosh_DeviceApi_V2_GetInAppsResponse.InApp()
        inApp.url = "https://example.com/inapp.html"
        inApp.code = "inapp-code"
        inApp.layout = "fullscreen"
        inApp.updated = 20240101
        inApp.closeButtonType = 1
        inApp.hash = "abc123"
        inApp.required = true
        inApp.priority = 1
        inApp.businessCase = "promo"
        inApp.gdpr = "consent"

        response.inApps = [inApp]

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNotNil(result["inApps"])
        if let inApps = result["inApps"] as? [[String: Any]], let first = inApps.first {
            XCTAssertEqual(first["url"] as? String, "https://example.com/inapp.html")
            XCTAssertEqual(first["code"] as? String, "inapp-code")
            XCTAssertEqual(first["layout"] as? String, "fullscreen")
            XCTAssertEqual(first["updated"] as? Int32, 20240101)
            XCTAssertEqual(first["closeButtonType"] as? Int32, 1)
            XCTAssertEqual(first["hash"] as? String, "abc123")
            XCTAssertEqual(first["required"] as? Bool, true)
            XCTAssertEqual(first["priority"] as? Int32, 1)
            XCTAssertEqual(first["businessCase"] as? String, "promo")
            XCTAssertEqual(first["gdpr"] as? String, "consent")
        }
    }

    // MARK: - ApplicationOpen Response Tests

    func testApplicationOpenResponseEmpty() {
        let response = Pushwoosh_DeviceApi_V2_ApplicationOpenResponse()
        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertTrue(result.isEmpty)
    }

    func testApplicationOpenResponseWithRequiredInapps() {
        var response = Pushwoosh_DeviceApi_V2_ApplicationOpenResponse()

        var requiredInapp = Pushwoosh_DeviceApi_V2_ApplicationOpenResponse.RequiredInApp()
        requiredInapp.code = "req-inapp-code"
        requiredInapp.updated = 20240115

        response.requiredInapps = ["key1": requiredInapp]

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNotNil(result["required_inapps"])
        if let inapps = result["required_inapps"] as? [String: [String: Any]],
           let inapp = inapps["key1"] {
            XCTAssertEqual(inapp["code"] as? String, "req-inapp-code")
            XCTAssertEqual(inapp["updated"] as? Int32, 20240115)
        }
    }

    // MARK: - RegisterDevice Response Tests

    func testRegisterDeviceResponseEmpty() {
        let response = Pushwoosh_DeviceApi_V2_RegisterDeviceResponse()
        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertTrue(result.isEmpty)
    }

    func testRegisterDeviceResponseWithCategories() {
        var response = Pushwoosh_DeviceApi_V2_RegisterDeviceResponse()

        var button = Pushwoosh_DeviceApi_V2_RegisterDeviceResponse.IOSCategory.Button()
        button.id = "btn-1"
        button.label = "Accept"
        button.type = 1
        button.startApplication = 1

        var category = Pushwoosh_DeviceApi_V2_RegisterDeviceResponse.IOSCategory()
        category.categoryID = 101
        category.buttons = [button]

        response.iosCategories = [category]

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNotNil(result["iosCategories"])
        if let categories = result["iosCategories"] as? [[String: Any]],
           let first = categories.first {
            XCTAssertEqual(first["categoryId"] as? Int32, 101)
            if let buttons = first["buttons"] as? [[String: Any]], let btn = buttons.first {
                XCTAssertEqual(btn["id"] as? String, "btn-1")
                XCTAssertEqual(btn["label"] as? String, "Accept")
                XCTAssertEqual(btn["type"] as? Int32, 1)
                XCTAssertEqual(btn["startApplication"] as? Int32, 1)
            }
        }
    }

    // MARK: - CheckDevice Response Tests

    func testCheckDeviceResponse() {
        var response = Pushwoosh_DeviceApi_V2_CheckDeviceResponse()
        response.exist = true
        response.pushTokenExist = false

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertEqual(result["exist"] as? Bool, true)
        XCTAssertEqual(result["push_token_exist"] as? Bool, false)
    }

    // MARK: - PostEvent Response Tests

    func testPostEventResponseEmpty() {
        let response = Pushwoosh_PostEventApi_PostEventResponse()
        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertTrue(result.isEmpty)
    }

    func testPostEventResponseWithCode() {
        var response = Pushwoosh_PostEventApi_PostEventResponse()
        response.code = "event-code-123"

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertEqual(result["code"] as? String, "event-code-123")
    }

    func testPostEventResponseWithRichmedia() {
        var response = Pushwoosh_PostEventApi_PostEventResponse()

        var richmedia = Pushwoosh_PostEventApi_RichMedia()
        richmedia.url = "https://example.com/rm.html"
        richmedia.code = "rm-code"
        richmedia.ts = 1234567890
        richmedia.hash = "rm-hash"

        response.richmedia = richmedia

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNotNil(result["richmedia"])
        if let rm = result["richmedia"] as? [String: Any] {
            XCTAssertEqual(rm["url"] as? String, "https://example.com/rm.html")
            XCTAssertEqual(rm["code"] as? String, "rm-code")
            XCTAssertEqual(rm["ts"] as? String, "1234567890")
            XCTAssertEqual(rm["hash"] as? String, "rm-hash")
            XCTAssertNotNil(rm["tags"])
        }
    }

    func testPostEventResponseWithEmptyRichmediaURL() {
        var response = Pushwoosh_PostEventApi_PostEventResponse()

        var richmedia = Pushwoosh_PostEventApi_RichMedia()
        richmedia.url = ""
        richmedia.code = "rm-code"

        response.richmedia = richmedia

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertNil(result["richmedia"])
    }

    func testPostEventResponseWithMessageHash() {
        var response = Pushwoosh_PostEventApi_PostEventResponse()
        response.messageHash = "msg-hash-123"

        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertEqual(result["message_hash"] as? String, "msg-hash-123")
    }

    // MARK: - Unknown Response Type Tests

    func testUnknownResponseTypeReturnsEmpty() {
        let response = Pushwoosh_DeviceApi_V2_SetTagsResponse()
        let result = GRPCResponseConverters.toDictionary(response)

        XCTAssertTrue(result.isEmpty)
    }
}
