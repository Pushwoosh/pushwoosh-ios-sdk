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
import PushKit

final class PushwooshVoIPTests: XCTestCase {

    var implementation: PushwooshVoIPImplementation!

    override func setUpWithError() throws {
        try super.setUpWithError()
        implementation = PushwooshVoIPImplementation.shared
        PWPreferences.preferencesInstance().voipPushToken = nil
    }

    override func tearDownWithError() throws {
        PWPreferences.preferencesInstance().voipPushToken = nil
        try super.tearDownWithError()
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

    func testSetVoIPTokenSavesToPreferences() throws {
        let tokenData = Data([0x12, 0x34, 0x56, 0x78])

        PushwooshVoIPImplementation.setVoIPToken(tokenData)

        XCTAssertNotNil(PWPreferences.preferencesInstance().voipPushToken)
        XCTAssertEqual(PWPreferences.preferencesInstance().voipPushToken, "12345678")
    }

    func testRawPayloadFiltersNSNull() throws {
        let payload: [AnyHashable: Any] = [
            "callerName": "John Doe",
            "video": NSNull(),
            "handleType": 1,
            "customData": NSNull(),
            "validKey": "validValue"
        ]

        let message = PWVoIPMessage(rawPayload: payload)

        XCTAssertNotNil(message.rawPayload["callerName"])
        XCTAssertNotNil(message.rawPayload["handleType"])
        XCTAssertNotNil(message.rawPayload["validKey"])
        XCTAssertNil(message.rawPayload["video"])
        XCTAssertNil(message.rawPayload["customData"])
    }

    /// Verifies the setRingtone facade routes to the implementation without recursing and persists the value.
    func testSetRingtoneFacadeDoesNotRecurseAndPersists() throws {
        PushwooshVoIPImplementation.setRingtone("regression_ringtone.caf")

        XCTAssertEqual(UserDefaults.standard.string(forKey: "PushwooshVoIPRingtone"), "regression_ringtone.caf")

        PushwooshVoIPImplementation.setRingtone(nil)
    }

    /// Verifies that a revoked VoIP token is forgotten at once without any request and the regular push token stays.
    func testInvalidatedVoIPTokenIsClearedLocallyWithoutRequests() throws {
        let preferences = PWPreferences.preferencesInstance()
        preserveRegularPushToken()
        preferences.pushToken = "regular_push_token"
        preferences.voipPushToken = "0badc0de"
        let requestManager = installRecordingRequestManager()

        implementation.pushRegistry(PKPushRegistry(queue: nil), didInvalidatePushTokenFor: .voIP)

        XCTAssertEqual(requestManager.sentRequests.map { $0.methodName() }, [])
        XCTAssertNil(preferences.voipPushToken)
        XCTAssertEqual(preferences.pushToken, "regular_push_token")
    }

    /// Verifies that a VoIP token delivered after a revocation is registered with the server.
    func testNewVoIPTokenAfterInvalidationIsRegistered() throws {
        PWPreferences.preferencesInstance().voipPushToken = "0badc0de"
        let requestManager = installRecordingRequestManager()
        let registry = PKPushRegistry(queue: nil)

        implementation.pushRegistry(registry, didInvalidatePushTokenFor: .voIP)
        implementation.pushRegistry(registry, didUpdate: FakePushCredentials(token: Data([0xca, 0xfe])), for: .voIP)

        let registrations = requestManager.sentRequests.filter { $0.methodName() == "registerDevice" }
        XCTAssertEqual(registrations.count, 1)
        XCTAssertEqual(registrations.first?.requestDictionary()["voip_push_token"] as? String, "cafe")
    }

    private func installRecordingRequestManager() -> RecordingRequestManager {
        // Swift imports +module as init(), which builds a new module instead of the shared one.
        let networkModule = (PWNetworkModule.self as AnyObject).value(forKey: "module") as! PWNetworkModule
        let liveRequestManager = networkModule.requestManager
        let recorder = RecordingRequestManager()
        networkModule.requestManager = recorder
        addTeardownBlock { networkModule.requestManager = liveRequestManager }
        return recorder
    }

    private func preserveRegularPushToken() {
        let originalPushToken = PWPreferences.preferencesInstance().pushToken
        addTeardownBlock { PWPreferences.preferencesInstance().pushToken = originalPushToken }
    }
}

/// Records what reaches the network layer and never answers, like a server that has not replied yet.
private final class RecordingRequestManager: PWRequestManager {
    private(set) var sentRequests: [PWRequest] = []

    override func send(_ request: PWRequest!, completion: ((Error?) -> Void)!) {
        sentRequests.append(request)
    }
}

private final class FakePushCredentials: PKPushCredentials {
    private let fakeToken: Data

    init(token: Data) {
        fakeToken = token
        super.init()
    }

    override var token: Data { fakeToken }
    override var type: PKPushType { .voIP }
}
