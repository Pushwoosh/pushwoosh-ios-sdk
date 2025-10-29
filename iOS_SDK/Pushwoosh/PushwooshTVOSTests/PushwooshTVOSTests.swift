//
//  PushwooshTVOSTests.swift
//  PushwooshTVOSTests
//
//  Created by André Kis on 22.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshTVOS
import PushwooshCore

@available(tvOS 11.0, *)
final class PushwooshTVOSTests: XCTestCase {

    var implementation: PushwooshTVOSImplementation!

    override func setUpWithError() throws {
        try super.setUpWithError()
        implementation = PushwooshTVOSImplementation.shared
        PWPreferences.preferencesInstance().appCode = ""
        PWPreferences.preferencesInstance().pushTvToken = nil
    }

    override func tearDownWithError() throws {
        PWPreferences.preferencesInstance().appCode = ""
        PWPreferences.preferencesInstance().pushTvToken = nil
        try super.tearDownWithError()
    }

    func testSetAppCode() throws {
        let testAppCode = "TEST-12345"

        PushwooshTVOSImplementation.setAppCode(testAppCode)

        XCTAssertEqual(PWPreferences.preferencesInstance().appCode, testAppCode)
    }

    func testRegisterWithoutAppCodeFails() throws {
        let tokenData = Data([0x12, 0x34, 0x56, 0x78])
        let expectation = self.expectation(description: "Registration fails without app code")
        var capturedError: Error?

        implementation.registerForPushNotifications(withToken: tokenData) { error in
            capturedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertNotNil(capturedError)
        XCTAssertEqual((capturedError as NSError?)?.code, -1)
    }

    func testHandleTvPushTokenConversion() throws {
        let tokenData = Data([0xaa, 0xbb, 0xcc, 0xdd])

        PushwooshTVOSImplementation.setAppCode("TEST-APP")
        PushwooshTVOSImplementation.handleTvPushToken(tokenData)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let savedToken = PWPreferences.preferencesInstance().pushTvToken
            XCTAssertNotNil(savedToken)
        }
    }

    func testUnregisterClearsToken() throws {
        PWPreferences.preferencesInstance().pushTvToken = "test_token_123"

        let expectation = self.expectation(description: "Unregister")

        implementation.unregisterForPushNotifications { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testSharedInstanceIsSingleton() throws {
        let instance1 = PushwooshTVOSImplementation.shared
        let instance2 = PushwooshTVOSImplementation.shared

        XCTAssertTrue(instance1 === instance2)
    }

    func testRichMediaManagerAccessible() throws {
        let richMediaManager = implementation.richMediaManager

        XCTAssertNotNil(richMediaManager)
    }

    func testStaticTvosMethodReturnsClass() throws {
        let tvosClass = PushwooshTVOSImplementation.tvos()

        XCTAssertTrue(tvosClass is PushwooshTVOSImplementation.Type)
    }
}
