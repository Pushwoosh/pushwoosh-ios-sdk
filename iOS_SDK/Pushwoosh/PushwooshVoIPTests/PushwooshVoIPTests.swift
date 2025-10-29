//
//  PushwooshVoIPTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 24.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshVoIP
import PushwooshCore
import CallKit

@available(iOS 14.0, *)
final class PushwooshVoIPTests: XCTestCase {

    var implementation: PushwooshVoIPImplementation!

    override func setUpWithError() throws {
        try super.setUpWithError()
        implementation = PushwooshVoIPImplementation.shared
        PWPreferences.preferencesInstance().voipAppCode = ""
        PWPreferences.preferencesInstance().voipPushToken = nil
    }

    override func tearDownWithError() throws {
        PWPreferences.preferencesInstance().voipAppCode = ""
        PWPreferences.preferencesInstance().voipPushToken = nil
        try super.tearDownWithError()
    }

    func testSetVoIPAppId() throws {
        let testAppId = "VOIP-12345"

        PushwooshVoIPImplementation.setPushwooshVoIPAppId(testAppId)

        XCTAssertEqual(PWPreferences.preferencesInstance().voipAppCode, testAppId)
    }

    func testSharedInstanceIsSingleton() throws {
        let instance1 = PushwooshVoIPImplementation.shared
        let instance2 = PushwooshVoIPImplementation.shared

        XCTAssertTrue(instance1 === instance2)
    }

    func testStaticVoIPMethodReturnsClass() throws {
        let voipClass = PushwooshVoIPImplementation.voip()

        XCTAssertTrue(voipClass is PushwooshVoIPImplementation.Type)
    }

    func testIntToHandleTypeConversionGeneric() throws {
        let handleType = 1.toCXSetHandleType

        XCTAssertTrue(handleType.contains(.generic))
        XCTAssertEqual(handleType.count, 1)
    }

    func testIntToHandleTypeConversionPhoneNumber() throws {
        let handleType = 2.toCXSetHandleType

        XCTAssertTrue(handleType.contains(.phoneNumber))
        XCTAssertEqual(handleType.count, 1)
    }

    func testIntToHandleTypeConversionEmail() throws {
        let handleType = 3.toCXSetHandleType

        XCTAssertTrue(handleType.contains(.emailAddress))
        XCTAssertEqual(handleType.count, 1)
    }

    func testIntToHandleTypeConversionDefault() throws {
        let handleType = 999.toCXSetHandleType

        XCTAssertTrue(handleType.contains(.generic))
        XCTAssertEqual(handleType.count, 1)
    }

    func testDelegatePropertySetter() throws {
        class MockDelegate: NSObject, PWVoIPCallDelegate {
            func voipDidReceiveIncomingCall(payload: PWVoIPMessage) {}
            func pwProviderDidReset(_ provider: CXProvider) {}
            func pwProviderDidBegin(_ provider: CXProvider) {}
        }

        let mockDelegate = MockDelegate()
        PushwooshVoIPImplementation.delegate = mockDelegate

        XCTAssertNotNil(PushwooshVoIPImplementation.delegate)
    }

    func testDelegatePropertyGetter() throws {
        class MockDelegate: NSObject, PWVoIPCallDelegate {
            func voipDidReceiveIncomingCall(payload: PWVoIPMessage) {}
            func pwProviderDidReset(_ provider: CXProvider) {}
            func pwProviderDidBegin(_ provider: CXProvider) {}
        }

        let mockDelegate = MockDelegate()
        PushwooshVoIPImplementation.delegate = mockDelegate
        let retrievedDelegate = PushwooshVoIPImplementation.delegate

        XCTAssertNotNil(retrievedDelegate)
    }

    func testSetVoIPTokenWithValidData() throws {
        let tokenData = Data([0x12, 0x34, 0x56, 0x78])

        PWPreferences.preferencesInstance().voipAppCode = "TEST-APP"
        PushwooshVoIPImplementation.setVoIPToken(tokenData)

        XCTAssertNotNil(PWPreferences.preferencesInstance().voipAppCode)
    }

    func testMultipleAppIdChanges() throws {
        PushwooshVoIPImplementation.setPushwooshVoIPAppId("APP-1")
        XCTAssertEqual(PWPreferences.preferencesInstance().voipAppCode, "APP-1")

        PushwooshVoIPImplementation.setPushwooshVoIPAppId("APP-2")
        XCTAssertEqual(PWPreferences.preferencesInstance().voipAppCode, "APP-2")

        PushwooshVoIPImplementation.setPushwooshVoIPAppId("APP-3")
        XCTAssertEqual(PWPreferences.preferencesInstance().voipAppCode, "APP-3")
    }
}
