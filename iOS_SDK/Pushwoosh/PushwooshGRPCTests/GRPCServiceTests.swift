//
//  GRPCServiceTests.swift
//  PushwooshGRPCTests
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshGRPC

final class GRPCServiceTests: XCTestCase {

    // MARK: - BaseURL Tests

    func testDeviceServiceBaseURL() {
        XCTAssertEqual(GRPCService.device.baseURL, "https://device-api.svc-nue.pushwoosh.com")
    }

    func testPostEventServiceBaseURL() {
        XCTAssertEqual(GRPCService.postEvent.baseURL, "https://device-api.svc-nue.pushwoosh.com")
    }

    func testAllServicesUseSameGateway() {
        XCTAssertEqual(GRPCService.device.baseURL, GRPCService.postEvent.baseURL)
    }

    // MARK: - ServicePath Tests

    func testDeviceServicePath() {
        XCTAssertEqual(GRPCService.device.servicePath, "/pushwoosh.device_api.v2.DeviceService")
    }

    func testPostEventServicePath() {
        XCTAssertEqual(GRPCService.postEvent.servicePath, "/pushwoosh.post_event_api.PostEventService")
    }

    func testServicePathsAreDifferent() {
        XCTAssertNotEqual(GRPCService.device.servicePath, GRPCService.postEvent.servicePath)
    }

    // MARK: - Full URL Construction Tests

    func testDeviceServiceFullURL() {
        let service = GRPCService.device
        let fullURL = "\(service.baseURL)\(service.servicePath)/RegisterDevice"
        XCTAssertEqual(fullURL, "https://device-api.svc-nue.pushwoosh.com/pushwoosh.device_api.v2.DeviceService/RegisterDevice")
    }

    func testPostEventServiceFullURL() {
        let service = GRPCService.postEvent
        let fullURL = "\(service.baseURL)\(service.servicePath)/PostEvent"
        XCTAssertEqual(fullURL, "https://device-api.svc-nue.pushwoosh.com/pushwoosh.post_event_api.PostEventService/PostEvent")
    }
}

// MARK: - GRPCError Tests

final class GRPCErrorTests: XCTestCase {

    func testInvalidURLError() {
        let error = GRPCError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid URL")
    }

    func testSerializationFailedError() {
        let error = GRPCError.serializationFailed
        XCTAssertEqual(error.errorDescription, "Failed to serialize request")
    }

    func testInvalidResponseError() {
        let error = GRPCError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response")
    }

    func testGRPCError() {
        let error = GRPCError.grpcError(status: "14", message: "Service unavailable")
        XCTAssertEqual(error.errorDescription, "gRPC error (14): Service unavailable")
    }

    func testMalformedFrameError() {
        let error = GRPCError.malformedFrame
        XCTAssertEqual(error.errorDescription, "Malformed gRPC frame")
    }

    func testDeserializationFailedError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Parse error"])
        let error = GRPCError.deserializationFailed(underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Parse error") ?? false)
    }

    func testUnknownMethodError() {
        let error = GRPCError.unknownMethod("unknownMethod")
        XCTAssertEqual(error.errorDescription, "Unknown gRPC method: unknownMethod")
    }
}
