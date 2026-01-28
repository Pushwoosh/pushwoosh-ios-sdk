//
//  GRPCRequestBuilders.swift
//  PushwooshGRPC
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import SwiftProtobuf

enum GRPCRequestBuilders {

    // MARK: - Device Registration

    static func registerDevice(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_RegisterDeviceRequest {
        var request = Pushwoosh_DeviceApi_V2_RegisterDeviceRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)
        request.pushToken = dict["push_token"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        request.language = dict["language"] as? String ?? ""
        request.appVersion = dict["app_version"] as? String ?? ""
        request.deviceModel = dict["device_model"] as? String ?? ""
        request.osVersion = dict["os_version"] as? String ?? ""
        request.sdkVersion = dict["v"] as? String ?? ""
        request.timezone = dict["timezone"] as? String ?? ""

        if let tagsStruct = structFromDict(dict["tags"]) {
            request.tags = tagsStruct
        }

        return request
    }

    static func unregisterDevice(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_UnregisterDeviceRequest {
        var request = Pushwoosh_DeviceApi_V2_UnregisterDeviceRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        return request
    }

    // MARK: - Tags

    static func setTags(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_SetTagsRequest {
        var request = Pushwoosh_DeviceApi_V2_SetTagsRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)

        if let tagsStruct = structFromDict(dict["tags"]) {
            request.tags = tagsStruct
        }

        return request
    }

    static func getTags(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_GetTagsRequest {
        var request = Pushwoosh_DeviceApi_V2_GetTagsRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        return request
    }

    // MARK: - Application Events

    static func applicationOpen(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_ApplicationOpenRequest {
        var request = Pushwoosh_DeviceApi_V2_ApplicationOpenRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)
        request.language = dict["language"] as? String ?? ""
        request.appVersion = dict["app_version"] as? String ?? ""
        request.deviceModel = dict["device_model"] as? String ?? ""
        request.osVersion = dict["os_version"] as? String ?? ""
        request.sdkVersion = dict["v"] as? String ?? ""
        request.timezone = dict["timezone"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        return request
    }

    // MARK: - Push Statistics

    static func pushStat(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_PushStatRequest {
        var request = Pushwoosh_DeviceApi_V2_PushStatRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.hash = dict["hash"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)
        request.userID = dict["userId"] as? String ?? ""
        return request
    }

    static func messageDelivery(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_MessageDeliveryRequest {
        var request = Pushwoosh_DeviceApi_V2_MessageDeliveryRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.hash = dict["hash"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)
        request.userID = dict["userId"] as? String ?? ""
        return request
    }

    // MARK: - Badge

    static func setBadge(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_SetBadgeRequest {
        var request = Pushwoosh_DeviceApi_V2_SetBadgeRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.badge = Int32(dict["badge"] as? Int ?? 0)
        return request
    }

    // MARK: - In-Apps

    static func getInApps(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_GetInAppsRequest {
        var request = Pushwoosh_DeviceApi_V2_GetInAppsRequest()
        request.application = dict["application"] as? String ?? ""
        return request
    }

    // MARK: - User

    static func registerUser(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_RegisterUserRequest {
        var request = Pushwoosh_DeviceApi_V2_RegisterUserRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)
        return request
    }

    // MARK: - Live Activities

    static func setActivityToken(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_SetActivityTokenRequest {
        var request = Pushwoosh_DeviceApi_V2_SetActivityTokenRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.activityToken = dict["activity_token"] as? String ?? ""
        request.activityID = dict["activity_id"] as? String ?? ""
        return request
    }

    static func setActivityPushToStartToken(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_SetActivityPushToStartTokenRequest {
        var request = Pushwoosh_DeviceApi_V2_SetActivityPushToStartTokenRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.activityPushToStartToken = dict["activity_push_to_start_token"] as? String ?? ""
        return request
    }

    // MARK: - Rich Media

    static func richMediaAction(from dict: [String: Any]) -> Pushwoosh_DeviceApi_V2_RichMediaActionRequest {
        var request = Pushwoosh_DeviceApi_V2_RichMediaActionRequest()
        request.application = dict["application"] as? String ?? ""
        request.hwid = dict["hwid"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        request.inappCode = dict["inapp_code"] as? String ?? ""
        request.richMediaCode = dict["rich_media_code"] as? String ?? ""
        request.messageHash = dict["message_hash"] as? String ?? ""
        request.platform = UInt32(dict["device_type"] as? Int ?? 1)
        request.actionType = UInt32(dict["action_type"] as? Int ?? 0)

        if let actionAttrs = dict["action_attributes"] as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: actionAttrs),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            request.actionAttributes = jsonString
        }

        return request
    }

    // MARK: - Events (PostEventService)

    static func postEvent(from dict: [String: Any]) -> Pushwoosh_PostEventApi_PostEventRequest {
        var request = Pushwoosh_PostEventApi_PostEventRequest()
        request.hwid = dict["hwid"] as? String ?? ""
        request.application = dict["application"] as? String ?? ""
        request.event = dict["event"] as? String ?? ""
        request.userID = dict["userId"] as? String ?? ""
        request.platform = Int32(dict["device_type"] as? Int ?? 1)
        request.timestamp = Int64(dict["timestampUTC"] as? Int ?? 0)
        request.sdkVersion = dict["v"] as? String ?? ""

        if let attributesStruct = structFromDict(dict["attributes"]) {
            request.attributes = attributesStruct
        }

        return request
    }

    // MARK: - Helpers

    private static func structFromDict(_ value: Any?) -> Google_Protobuf_Struct? {
        guard let dict = value as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let protoStruct = try? Google_Protobuf_Struct(jsonUTF8Data: data) else {
            return nil
        }
        return protoStruct
    }
}
