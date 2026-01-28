//
//  PWTransportStub.swift
//  PushwooshBridge
//
//  Created by André on 26.01.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

/// Stub implementation of PWTransport for when gRPC module is not linked.
/// Returns an error indicating that gRPC transport is not available.
@objc public class PWTransportStub: NSObject, PWTransport {

    @objc
    public static func transport() -> AnyClass {
        return PWTransportStub.self
    }

    @objc
    public static var isAvailable: Bool {
        return false
    }

    @objc
    public static var transportName: String {
        return "Stub"
    }

    @objc
    public static func sendRequest(_ request: PWRequest,
                                   completion: @escaping (NSDictionary?, Error?) -> Void) {
        let error = NSError(
            domain: "com.pushwoosh.grpc",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "PushwooshGRPC not found. To enable gRPC transport, make sure the PushwooshGRPC module is added to the project."
            ]
        )
        completion(nil, error)
    }

    @objc
    public static func supportsMethod(_ methodName: String) -> Bool {
        return false
    }
}
