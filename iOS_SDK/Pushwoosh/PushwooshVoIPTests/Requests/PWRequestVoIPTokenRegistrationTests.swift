//
//  PWRequestVoIPTokenRegistrationTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 24.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshVoIP
import PushwooshCore

@available(iOS 14.0, *)
final class PWRequestVoIPTokenRegistrationTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        PWPreferences.preferencesInstance().voipAppCode = "TEST-VOIP-12345"
    }

    override func tearDownWithError() throws {
        PWPreferences.preferencesInstance().voipAppCode = ""
        try super.tearDownWithError()
    }

    func testRequestMethodName() throws {
        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        XCTAssertEqual(request.methodName(), "registerDevice")
    }

    func testRequestPrepareWithValidToken() throws {
        let parameters = VoIPRequestParameters(token: "valid_token_123")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertTrue(result)
    }

    func testRequestPrepareWithEmptyToken() throws {
        let parameters = VoIPRequestParameters(token: "")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertFalse(result)
    }

    func testRequestPrepareWithNilToken() throws {
        let parameters = VoIPRequestParameters(token: nil)
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let result = request.prepareForExecution()

        XCTAssertFalse(result)
    }

    func testRequestDictionary() throws {
        let parameters = VoIPRequestParameters(token: "test_token_abc")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertNotNil(dictionary)
        XCTAssertEqual(dictionary["application"] as? String, "TEST-VOIP-12345")
        XCTAssertEqual(dictionary["push_token"] as? String, "test_token_abc")
        XCTAssertNotNil(dictionary["gateway"])
        XCTAssertEqual(dictionary["device_type"] as? Int, 1)
        XCTAssertNotNil(dictionary["timezone"])
    }

    func testRequestDictionaryGatewayValue() throws {
        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()
        let gateway = dictionary["gateway"] as? String

        XCTAssertNotNil(gateway)
        XCTAssertTrue(gateway == "production" || gateway == "sandbox")
    }

    func testRequestDictionaryDeviceType() throws {
        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertEqual(dictionary["device_type"] as? Int, 1)
    }

    func testRequestDictionaryTimezone() throws {
        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()
        let timezone = dictionary["timezone"]

        XCTAssertNotNil(timezone)
    }

    func testRequestDictionaryApplication() throws {
        PWPreferences.preferencesInstance().voipAppCode = "CUSTOM-APP-CODE"
        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertEqual(dictionary["application"] as? String, "CUSTOM-APP-CODE")
    }

    func testMultipleRequestsWithDifferentTokens() throws {
        let parameters1 = VoIPRequestParameters(token: "token1")
        let request1 = PWSetVoIPTokenRequest(parameters: parameters1)

        let parameters2 = VoIPRequestParameters(token: "token2")
        let request2 = PWSetVoIPTokenRequest(parameters: parameters2)

        let dict1 = request1.requestDictionary()
        let dict2 = request2.requestDictionary()

        XCTAssertEqual(dict1["push_token"] as? String, "token1")
        XCTAssertEqual(dict2["push_token"] as? String, "token2")
    }

    func testRequestParametersWithToken() throws {
        let parameters = VoIPRequestParameters(token: "abc123")

        XCTAssertEqual(parameters.token, "abc123")
    }

    func testRequestParametersWithNilToken() throws {
        let parameters = VoIPRequestParameters(token: nil)

        XCTAssertNil(parameters.token)
    }

    func testRequestPrepareMultipleTimes() throws {
        let parameters = VoIPRequestParameters(token: "valid_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let result1 = request.prepareForExecution()
        let result2 = request.prepareForExecution()
        let result3 = request.prepareForExecution()

        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertTrue(result3)
    }

    func testRequestDictionaryWithLongToken() throws {
        let longToken = String(repeating: "a", count: 256)
        let parameters = VoIPRequestParameters(token: longToken)
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertEqual(dictionary["push_token"] as? String, longToken)
    }

    func testRequestDictionaryWithSpecialCharactersInToken() throws {
        let specialToken = "token_with-special.chars@123"
        let parameters = VoIPRequestParameters(token: specialToken)
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        let dictionary = request.requestDictionary()

        XCTAssertEqual(dictionary["push_token"] as? String, specialToken)
    }
}
