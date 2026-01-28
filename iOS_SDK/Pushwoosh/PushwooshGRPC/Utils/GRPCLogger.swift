//
//  GRPCLogger.swift
//  PushwooshGRPC
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

enum GRPCLogger {

    static func log(level: PUSHWOOSH_LOG_LEVEL, method: String, payload: [String: Any], status: String, response: String) {
        let payloadString = formatDict(payload)
        let message = """
        [gRPC] Method: \(method)
        Payload: \(payloadString)
        Status: "\(status)"
        Response: \(response)
        """
        PushwooshLog.pushwooshLog(level, className: PushwooshGRPCImplementation.self, message: message)
    }

    static func logSuccess(method: String, payload: [String: Any], response: [String: Any]) {
        log(level: .PW_LL_DEBUG, method: method, payload: payload, status: "200 OK", response: formatDict(response))
    }

    static func logError(method: String, payload: [String: Any], error: Error) {
        log(level: .PW_LL_ERROR, method: method, payload: payload, status: "error", response: error.localizedDescription)
    }

    static func logEmpty(method: String, payload: [String: Any]) {
        log(level: .PW_LL_DEBUG, method: method, payload: payload, status: "200 OK", response: "{}")
    }

    static func logRetry(method: String, attempt: Int, maxAttempts: Int, delay: TimeInterval, error: Error) {
        let message = "[gRPC] Method: \(method) - Retry \(attempt)/\(maxAttempts) in \(String(format: "%.1f", delay))s after error: \(error.localizedDescription)"
        PushwooshLog.pushwooshLog(.PW_LL_WARN, className: PushwooshGRPCImplementation.self, message: message)
    }

    // MARK: - Helpers

    static func formatDict(_ dict: [String: Any]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(dict)"
    }
}
