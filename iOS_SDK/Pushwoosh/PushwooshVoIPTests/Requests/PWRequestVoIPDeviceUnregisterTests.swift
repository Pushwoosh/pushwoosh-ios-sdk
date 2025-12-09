//
//  PWRequestVoIPDeviceUnregisterTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 24.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshVoIP
import PushwooshCore

@available(iOS 14.0, *)
final class PWRequestVoIPDeviceUnregisterTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        PWPreferences.preferencesInstance().appCode = "TEST-APP"
    }

    override func tearDownWithError() throws {
        PWPreferences.preferencesInstance().appCode = ""
        try super.tearDownWithError()
    }

    func testRequestMethodName() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        XCTAssertEqual(request.methodName(), "unregisterDevice")
    }

    func testRequestPrepareAlwaysSucceeds() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertTrue(result)
    }

    func testRequestPrepareWithNilToken() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertTrue(result)
    }

    func testRequestPrepareWithEmptyToken() throws {
        let parameters = VoIPRequestParameters(token: "")
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertTrue(result)
    }

    func testRequestPrepareWithValidToken() throws {
        let parameters = VoIPRequestParameters(token: "some_token")
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertTrue(result)
    }

    func testRequestDictionary() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertNotNil(dictionary)
    }

    func testRequestDictionaryIsBaseDictionary() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertTrue(dictionary.count > 0)
    }

    func testRequestParametersStoredCorrectly() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        XCTAssertNil(request.parameters.token)
    }

    func testRequestParametersWithTokenStoredCorrectly() throws {
        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        XCTAssertEqual(request.parameters.token, "test_token")
    }

    func testMultipleUnregisterRequests() throws {
        let parameters1 = VoIPRequestParameters(token: nil)
        let request1 = PWUnregisterVoIPDeviceRequest(parameters: parameters1)

        let parameters2 = VoIPRequestParameters(token: nil)
        let request2 = PWUnregisterVoIPDeviceRequest(parameters: parameters2)

        XCTAssertEqual(request1.methodName(), request2.methodName())
    }

    func testRequestPrepareMultipleTimes() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        let result1 = request.prepareForExecution()
        let result2 = request.prepareForExecution()
        let result3 = request.prepareForExecution()

        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertTrue(result3)
    }

    func testRequestConformsToProtocol() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        XCTAssertTrue(request is PWCoreUnregisterVoIPDeviceRequest)
    }

    func testRequestInheritsFromPWRequest() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        XCTAssertTrue(request is PWRequest)
    }
}
