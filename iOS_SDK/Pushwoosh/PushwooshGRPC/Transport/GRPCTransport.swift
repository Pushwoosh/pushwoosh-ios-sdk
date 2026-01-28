//
//  GRPCTransport.swift
//  PushwooshGRPC
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import SwiftProtobuf

enum GRPCService {
    case device
    case postEvent

    var baseURL: String {
        return "https://device-api.svc-nue.pushwoosh.com"
    }

    var servicePath: String {
        switch self {
        case .device:
            return "/pushwoosh.device_api.v2.DeviceService"
        case .postEvent:
            return "/pushwoosh.post_event_api.PostEventService"
        }
    }
}

final class GRPCTransport {

    // MARK: - Configuration

    static let defaultService: GRPCService = .device

    static let maxRetryAttempts = 3
    static let initialRetryDelay: TimeInterval = 25.0

    // MARK: - Shared Session

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // MARK: - Send Request

    static func send<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request,
        responseType: Response.Type,
        service: GRPCService = .device,
        cacheable: Bool = false,
        completion: @escaping (Result<Response?, Error>) -> Void
    ) {
        sendWithRetry(
            method: method,
            request: request,
            responseType: responseType,
            service: service,
            cacheable: cacheable,
            attempt: 0,
            previousDelay: initialRetryDelay,
            completion: completion
        )
    }

    // MARK: - Retry Logic

    private static func sendWithRetry<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request,
        responseType: Response.Type,
        service: GRPCService,
        cacheable: Bool,
        attempt: Int,
        previousDelay: TimeInterval,
        completion: @escaping (Result<Response?, Error>) -> Void
    ) {
        sendOnce(method: method, request: request, responseType: responseType, service: service) { result in
            switch result {
            case .success:
                completion(result)

            case .failure(let error):
                if cacheable && isRetryableError(error) && attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(previousDelay: previousDelay)

                    GRPCLogger.logRetry(method: method, attempt: attempt + 1, maxAttempts: maxRetryAttempts, delay: delay, error: error)

                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        sendWithRetry(
                            method: method,
                            request: request,
                            responseType: responseType,
                            service: service,
                            cacheable: cacheable,
                            attempt: attempt + 1,
                            previousDelay: delay,
                            completion: completion
                        )
                    }
                } else {
                    completion(result)
                }
            }
        }
    }

    private static func calculateRetryDelay(previousDelay: TimeInterval) -> TimeInterval {
        return previousDelay * log2(previousDelay)
    }

    private static func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        if let grpcError = error as? GRPCError {
            switch grpcError {
            case .grpcError(let status, _):
                return isRetryableGRPCStatus(status)
            default:
                return false
            }
        }

        return false
    }

    private static func isRetryableGRPCStatus(_ status: String) -> Bool {
        guard let statusCode = Int(status) else { return false }
        // 8 = RESOURCE_EXHAUSTED, 13 = INTERNAL, 14 = UNAVAILABLE
        return [8, 13, 14].contains(statusCode)
    }

    // MARK: - Single Request

    private static func sendOnce<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request,
        responseType: Response.Type,
        service: GRPCService,
        completion: @escaping (Result<Response?, Error>) -> Void
    ) {
        let urlString = "\(service.baseURL)\(service.servicePath)/\(method)"
        guard let url = URL(string: urlString) else {
            completion(.failure(GRPCError.invalidURL))
            return
        }

        guard let messageData = try? request.serializedData() else {
            completion(.failure(GRPCError.serializationFailed))
            return
        }

        let framedData = GRPCFraming.frame(messageData)
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/grpc", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("trailers", forHTTPHeaderField: "TE")
        httpRequest.setValue("identity", forHTTPHeaderField: "grpc-encoding")
        httpRequest.setValue("identity,deflate,gzip", forHTTPHeaderField: "grpc-accept-encoding")
        httpRequest.httpBody = framedData

        let task = session.dataTask(with: httpRequest) { data, response, error in
            DispatchQueue.main.async {
                let result = parseResponse(
                    data: data,
                    response: response,
                    error: error,
                    responseType: responseType
                )
                completion(result)
            }
        }
        task.resume()
    }

    // MARK: - Response Parsing

    private static func parseResponse<Response: SwiftProtobuf.Message>(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        responseType: Response.Type
    ) -> Result<Response?, Error> {
        if let error = error {
            return .failure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(GRPCError.invalidResponse)
        }

        if let grpcStatus = httpResponse.value(forHTTPHeaderField: "grpc-status"),
           grpcStatus != "0" {
            let grpcMessage = httpResponse.value(forHTTPHeaderField: "grpc-message") ?? "Unknown error"
            return .failure(GRPCError.grpcError(status: grpcStatus, message: grpcMessage))
        }

        guard let data = data, !data.isEmpty else {
            return .success(nil)
        }

        guard let messageData = GRPCFraming.parse(data) else {
            return .failure(GRPCError.malformedFrame)
        }

        do {
            let protoResponse = try Response(serializedData: messageData)
            return .success(protoResponse)
        } catch {
            return .failure(GRPCError.deserializationFailed(error))
        }
    }
}

// MARK: - Errors

enum GRPCError: LocalizedError {
    case invalidURL
    case serializationFailed
    case invalidResponse
    case grpcError(status: String, message: String)
    case malformedFrame
    case deserializationFailed(Error)
    case unknownMethod(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serializationFailed:
            return "Failed to serialize request"
        case .invalidResponse:
            return "Invalid response"
        case .grpcError(let status, let message):
            return "gRPC error (\(status)): \(message)"
        case .malformedFrame:
            return "Malformed gRPC frame"
        case .deserializationFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unknownMethod(let method):
            return "Unknown gRPC method: \(method)"
        }
    }
}
