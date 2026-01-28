//
//  PushwooshGRPCImplementation.swift
//  PushwooshGRPC
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import SwiftProtobuf
import PushwooshCore
import PushwooshBridge

@objc public class PushwooshGRPCImplementation: NSObject, PWTransport {

    static let version = "1.0.0"

    /// Set of methods supported by gRPC transport
    private static let supportedMethods: Set<String> = [
        "registerDevice",
        "unregisterDevice",
        "setTags",
        "getTags",
        "applicationOpen",
        "pushStat",
        "messageDeliveryEvent",
        "setBadge",
        "getInApps",
        "registerUser",
        "setActivityToken",
        "setActivityPushToStartToken",
        "richMediaAction"
    ]

    // MARK: - PWTransport Protocol

    @objc public static var isAvailable: Bool {
        return true
    }

    @objc public static var transportName: String {
        return "gRPC"
    }

    @objc public static func supportsMethod(_ methodName: String) -> Bool {
        return supportedMethods.contains(methodName)
    }

    @objc public static func sendRequest(_ request: PWRequest,
                                         completion: @escaping (NSDictionary?, Error?) -> Void) {
        let methodName = request.methodName() ?? ""
        let requestDict = request.requestDictionary() as? [String: Any] ?? [:]
        let cacheable = request.cacheable

        routeRequest(methodName: methodName, requestDict: requestDict, cacheable: cacheable, completion: completion)
    }

    // MARK: - Request Routing

    private static func routeRequest(methodName: String,
                                     requestDict: [String: Any],
                                     cacheable: Bool,
                                     completion: @escaping (NSDictionary?, Error?) -> Void) {
        switch methodName {
        case "registerDevice":
            send(method: "RegisterDevice",
                 request: GRPCRequestBuilders.registerDevice(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_RegisterDeviceResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "unregisterDevice":
            send(method: "UnregisterDevice",
                 request: GRPCRequestBuilders.unregisterDevice(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_UnregisterDeviceResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "setTags":
            send(method: "SetTags",
                 request: GRPCRequestBuilders.setTags(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_SetTagsResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "getTags":
            send(method: "GetTags",
                 request: GRPCRequestBuilders.getTags(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_GetTagsResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "applicationOpen":
            send(method: "ApplicationOpen",
                 request: GRPCRequestBuilders.applicationOpen(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_ApplicationOpenResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "pushStat":
            send(method: "PushStat",
                 request: GRPCRequestBuilders.pushStat(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_PushStatResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "messageDeliveryEvent":
            send(method: "MessageDelivery",
                 request: GRPCRequestBuilders.messageDelivery(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_MessageDeliveryResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "setBadge":
            send(method: "SetBadge",
                 request: GRPCRequestBuilders.setBadge(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_SetBadgeResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "getInApps":
            send(method: "GetInApps",
                 request: GRPCRequestBuilders.getInApps(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_GetInAppsResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "registerUser":
            send(method: "RegisterUser",
                 request: GRPCRequestBuilders.registerUser(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_RegisterUserResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "setActivityToken":
            send(method: "SetActivityToken",
                 request: GRPCRequestBuilders.setActivityToken(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_SetActivityTokenResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "setActivityPushToStartToken":
            send(method: "SetActivityPushToStartToken",
                 request: GRPCRequestBuilders.setActivityPushToStartToken(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_SetActivityPushToStartTokenResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        case "richMediaAction":
            send(method: "RichMediaAction",
                 request: GRPCRequestBuilders.richMediaAction(from: requestDict),
                 responseType: Pushwoosh_DeviceApi_V2_RichMediaActionResponse.self,
                 requestDict: requestDict,
                 cacheable: cacheable,
                 completion: completion)

        // TODO: Enable when backend returns richmedia in gRPC response
        // case "postEvent":
        //     send(method: "PostEvent",
        //          request: GRPCRequestBuilders.postEvent(from: requestDict),
        //          responseType: Pushwoosh_PostEventApi_PostEventResponse.self,
        //          service: .postEvent,
        //          requestDict: requestDict,
        //          cacheable: cacheable,
        //          completion: completion)

        default:
            let error = GRPCError.unknownMethod(methodName)
            GRPCLogger.logError(method: methodName, payload: requestDict, error: error)
            completion(nil, error)
        }
    }

    // MARK: - Send Helper

    private static func send<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request,
        responseType: Response.Type,
        service: GRPCService = .device,
        requestDict: [String: Any],
        cacheable: Bool,
        completion: @escaping (NSDictionary?, Error?) -> Void
    ) {
        GRPCTransport.send(method: method, request: request, responseType: responseType, service: service, cacheable: cacheable) { result in
            switch result {
            case .success(let response):
                let convertedResponse = GRPCResponseConverters.toDictionary(response)
                var responseDict: [String: Any] = ["status_code": 200]
                if !convertedResponse.isEmpty {
                    responseDict["response"] = convertedResponse
                }

                if convertedResponse.isEmpty {
                    GRPCLogger.logEmpty(method: method, payload: requestDict)
                } else {
                    GRPCLogger.logSuccess(method: method, payload: requestDict, response: responseDict)
                }

                completion(responseDict as NSDictionary, nil)

            case .failure(let error):
                GRPCLogger.logError(method: method, payload: requestDict, error: error)
                completion(nil, error)
            }
        }
    }
}
