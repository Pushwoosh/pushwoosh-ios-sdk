//
//  PWTVOSAPIClientTests.swift
//  PushwooshTVOSTests
//
//  Created by André Kis on 23.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshTVOS
import PushwooshCore

@available(tvOS 11.0, *)
final class PWTVOSAPIClientTests: XCTestCase {

    var apiClient: PWTVOSAPIClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        apiClient = PWTVOSAPIClient()
    }

    override func tearDownWithError() throws {
        apiClient = nil
        try super.tearDownWithError()
    }

    func testRegisterDeviceCallsCompletion() throws {
        let expectation = self.expectation(description: "Register device completion")
        let testAppCode = "TEST-APP-CODE"
        let testToken = "test_device_token_123"
        let testHwid = "test_hwid_456"

        apiClient.registerDevice(appCode: testAppCode, token: testToken, hwid: testHwid) { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testUnregisterDeviceCallsCompletion() throws {
        let expectation = self.expectation(description: "Unregister device completion")

        apiClient.unregisterDevice { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testRegisterDeviceWithEmptyAppCode() throws {
        let expectation = self.expectation(description: "Register with empty app code")

        apiClient.registerDevice(appCode: "", token: "token", hwid: "hwid") { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testRegisterDeviceWithEmptyToken() throws {
        let expectation = self.expectation(description: "Register with empty token")

        apiClient.registerDevice(appCode: "APP-CODE", token: "", hwid: "hwid") { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testRegisterDeviceWithEmptyHwid() throws {
        let expectation = self.expectation(description: "Register with empty hwid")

        apiClient.registerDevice(appCode: "APP-CODE", token: "token", hwid: "") { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testMultipleRegisterCalls() throws {
        let expectation1 = self.expectation(description: "First register")
        let expectation2 = self.expectation(description: "Second register")

        apiClient.registerDevice(appCode: "APP1", token: "token1", hwid: "hwid1") { error in
            expectation1.fulfill()
        }

        apiClient.registerDevice(appCode: "APP2", token: "token2", hwid: "hwid2") { error in
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testMultipleUnregisterCalls() throws {
        let expectation1 = self.expectation(description: "First unregister")
        let expectation2 = self.expectation(description: "Second unregister")

        apiClient.unregisterDevice { error in
            expectation1.fulfill()
        }

        apiClient.unregisterDevice { error in
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testRegisterDeviceParametersNotNil() throws {
        let expectation = self.expectation(description: "Register device")
        let appCode = "TEST-12345"
        let token = "abcdef123456"
        let hwid = "unique-hwid-789"

        apiClient.registerDevice(appCode: appCode, token: token, hwid: hwid) { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testUnregisterAfterRegister() throws {
        let registerExpectation = self.expectation(description: "Register")
        let unregisterExpectation = self.expectation(description: "Unregister")

        apiClient.registerDevice(appCode: "APP", token: "token", hwid: "hwid") { error in
            registerExpectation.fulfill()

            self.apiClient.unregisterDevice { error in
                unregisterExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 15.0)
    }

    func testAPIClientIsNotNil() throws {
        XCTAssertNotNil(apiClient)
    }
}
