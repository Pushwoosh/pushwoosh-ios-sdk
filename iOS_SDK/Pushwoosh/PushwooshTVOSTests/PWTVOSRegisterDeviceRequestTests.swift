//
//  PWTVOSRegisterDeviceRequestTests.swift
//  PushwooshTVOSTests
//
//  Created by André Kis on 22.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshTVOS
import PushwooshCore

@available(tvOS 11.0, *)
final class PWTVOSRegisterDeviceRequestTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        PWPreferences.preferencesInstance().appCode = "TEST-TVOS-APP"
        let ready = XCTestExpectation(description: "sdk ready")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ready.fulfill() }
        wait(for: [ready], timeout: 1.0)
    }

    override func tearDownWithError() throws {
        PWPreferences.preferencesInstance().appCode = ""
        try super.tearDownWithError()
    }

    func testAPIClientRegisterDeviceSendsRequest() {
        let client = PWTVOSAPIClient()
        let expectation = self.expectation(description: "Register device completion")

        client.registerDevice(appCode: "TEST-12345", token: "test_token", hwid: "test_hwid") { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testAPIClientUnregisterDeviceSendsRequest() {
        let client = PWTVOSAPIClient()
        let expectation = self.expectation(description: "Unregister device completion")

        client.unregisterDevice { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }
}
