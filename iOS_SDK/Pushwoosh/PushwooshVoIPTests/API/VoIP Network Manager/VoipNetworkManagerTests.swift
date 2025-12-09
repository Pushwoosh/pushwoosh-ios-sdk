//
//  VoipNetworkManagerTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 24.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshVoIP
import PushwooshCore

@available(iOS 14.0, *)
final class VoipNetworkManagerTests: XCTestCase {

    var networkManager: VoipNetworkManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        networkManager = VoipNetworkManager.shared
    }

    override func tearDownWithError() throws {
        networkManager = nil
        try super.tearDownWithError()
    }

    func testSharedInstanceIsSingleton() throws {
        let instance1 = VoipNetworkManager.shared
        let instance2 = VoipNetworkManager.shared

        XCTAssertTrue(instance1 === instance2)
    }

    func testSendRequestWithValidToken() throws {
        let expectation = self.expectation(description: "Send VoIP token request")

        let parameters = VoIPRequestParameters(token: "test_voip_token_123")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testSendRequestWithEmptyToken() throws {
        let expectation = self.expectation(description: "Send request with empty token")
        var capturedError: Error?

        let parameters = VoIPRequestParameters(token: "")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            capturedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        XCTAssertNotNil(capturedError)
        XCTAssertEqual((capturedError as NSError?)?.code, 1)
    }

    func testSendRequestWithNilToken() throws {
        let expectation = self.expectation(description: "Send request with nil token")
        var capturedError: Error?

        let parameters = VoIPRequestParameters(token: nil)
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            capturedError = error
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        XCTAssertNotNil(capturedError)
    }

    func testUnregisterDeviceRequest() throws {
        let expectation = self.expectation(description: "Unregister VoIP device")

        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testMultipleSequentialRequests() throws {
        let expectation1 = self.expectation(description: "First request")
        let expectation2 = self.expectation(description: "Second request")

        let parameters1 = VoIPRequestParameters(token: "token1")
        let request1 = PWSetVoIPTokenRequest(parameters: parameters1)

        networkManager.sendInnerRequest(request: request1) { error in
            expectation1.fulfill()

            let parameters2 = VoIPRequestParameters(token: "token2")
            let request2 = PWSetVoIPTokenRequest(parameters: parameters2)

            self.networkManager.sendInnerRequest(request: request2) { error in
                expectation2.fulfill()
            }
        }

        waitForExpectations(timeout: 15.0)
    }

    func testMultipleParallelRequests() throws {
        let expectation1 = self.expectation(description: "First parallel request")
        let expectation2 = self.expectation(description: "Second parallel request")

        let parameters1 = VoIPRequestParameters(token: "token1")
        let request1 = PWSetVoIPTokenRequest(parameters: parameters1)

        let parameters2 = VoIPRequestParameters(token: "token2")
        let request2 = PWSetVoIPTokenRequest(parameters: parameters2)

        networkManager.sendInnerRequest(request: request1) { error in
            expectation1.fulfill()
        }

        networkManager.sendInnerRequest(request: request2) { error in
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 15.0)
    }

    func testSendRequestCompletionCalled() throws {
        let expectation = self.expectation(description: "Completion block called")
        var completionCalled = false

        let parameters = VoIPRequestParameters(token: "test_token")
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            completionCalled = true
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertTrue(completionCalled)
    }

    func testSendUnregisterRequestCompletionCalled() throws {
        let expectation = self.expectation(description: "Unregister completion called")
        var completionCalled = false

        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            completionCalled = true
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
        XCTAssertTrue(completionCalled)
    }

    func testSendRequestWithLongToken() throws {
        let expectation = self.expectation(description: "Send request with long token")
        let longToken = String(repeating: "a", count: 500)

        let parameters = VoIPRequestParameters(token: longToken)
        let request = PWSetVoIPTokenRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10.0)
    }

    func testSendMixedRequests() throws {
        let expectation1 = self.expectation(description: "Register request")
        let expectation2 = self.expectation(description: "Unregister request")

        let registerParams = VoIPRequestParameters(token: "valid_token")
        let registerRequest = PWSetVoIPTokenRequest(parameters: registerParams)

        let unregisterParams = VoIPRequestParameters(token: nil)
        let unregisterRequest = PWUnregisterVoIPDeviceRequest(parameters: unregisterParams)

        networkManager.sendInnerRequest(request: registerRequest) { error in
            expectation1.fulfill()
        }

        networkManager.sendInnerRequest(request: unregisterRequest) { error in
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 15.0)
    }
}
