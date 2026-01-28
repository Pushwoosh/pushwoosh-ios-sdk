//
//  PWTransport.swift
//  PushwooshBridge
//
//  Created by André on 26.01.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

/// Protocol defining the transport layer interface for sending network requests.
/// This allows for different transport implementations (REST, gRPC) to be used interchangeably.
@objc
public protocol PWTransport {

    /// Sends a request using this transport.
    /// - Parameters:
    ///   - request: The PWRequest to send
    ///   - completion: Completion handler called with the response dictionary and/or error
    @objc
    static func sendRequest(_ request: PWRequest,
                            completion: @escaping (NSDictionary?, Error?) -> Void)

    /// Indicates whether this transport is currently available and can be used.
    @objc
    static var isAvailable: Bool { get }

    /// Returns the transport name for logging purposes.
    @objc
    static var transportName: String { get }

    /// Checks if this transport supports the given method.
    /// - Parameter methodName: The API method name (e.g., "registerDevice", "postEvent")
    /// - Returns: true if this transport can handle the method, false otherwise
    @objc
    static func supportsMethod(_ methodName: String) -> Bool
}
