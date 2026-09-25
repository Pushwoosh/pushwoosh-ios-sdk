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
    /// Requests the stub transport was handed, in order.
    private var sent: [PWCoreSetVoIPTokenRequest] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        PWPreferences.preferencesInstance().appCode = "TEST-VOIP-APP"
        // A stub transport instead of the live one: the suite used to reach the real
        // server and wait up to fifteen seconds, which is why it kept timing out.
        sent = []
        networkManager = VoipNetworkManager(transport: { [weak self] request, completion in
            self?.sent.append(request)
            completion(nil)
        })
    }

    override func tearDownWithError() throws {
        sent = []
        networkManager = nil
        PWPreferences.preferencesInstance().appCode = ""
        try super.tearDownWithError()
    }

    func testSharedInstanceIsSingleton() throws {
        let instance1 = VoipNetworkManager.shared
        let instance2 = VoipNetworkManager.shared

        XCTAssertTrue(instance1 === instance2)
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

        waitForExpectations(timeout: 1.0)

        XCTAssertNotNil(capturedError)
        XCTAssertEqual((capturedError as NSError?)?.code, 1)
        XCTAssertTrue(sent.isEmpty, "a request that failed preparation must not be sent")
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

        waitForExpectations(timeout: 1.0)

        XCTAssertNotNil(capturedError)
        XCTAssertTrue(sent.isEmpty, "a request that failed preparation must not be sent")
    }

    func testUnregisterDeviceRequest() throws {
        let expectation = self.expectation(description: "Unregister VoIP device")

        let parameters = VoIPRequestParameters(token: nil)
        let request = PWUnregisterVoIPDeviceRequest(parameters: parameters)

        networkManager.sendInnerRequest(request: request) { error in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
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

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(sent.count, 2, "both requests must reach the transport")
        XCTAssertEqual(sent.map { $0.parameters.token }, ["token1", "token2"],
                       "the second request must follow the first, not race it")
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

        waitForExpectations(timeout: 1.0)
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

        waitForExpectations(timeout: 1.0)
    }

}
