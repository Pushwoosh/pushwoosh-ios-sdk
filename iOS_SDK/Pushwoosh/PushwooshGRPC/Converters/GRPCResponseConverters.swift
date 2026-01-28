//
//  GRPCResponseConverters.swift
//  PushwooshGRPC
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import SwiftProtobuf

enum GRPCResponseConverters {

    static func toDictionary<T: SwiftProtobuf.Message>(_ response: T?) -> [String: Any] {
        guard let response = response else {
            return [:]
        }

        switch response {
        case let r as Pushwoosh_DeviceApi_V2_GetTagsResponse:
            return convertGetTags(r)

        case let r as Pushwoosh_DeviceApi_V2_GetInAppsResponse:
            return convertGetInApps(r)

        case let r as Pushwoosh_DeviceApi_V2_ApplicationOpenResponse:
            return convertApplicationOpen(r)

        case let r as Pushwoosh_DeviceApi_V2_RegisterDeviceResponse:
            return convertRegisterDevice(r)

        case let r as Pushwoosh_DeviceApi_V2_CheckDeviceResponse:
            return convertCheckDevice(r)

        case let r as Pushwoosh_PostEventApi_PostEventResponse:
            return convertPostEvent(r)

        default:
            return [:]
        }
    }

    // MARK: - Individual Converters

    private static func convertGetTags(_ response: Pushwoosh_DeviceApi_V2_GetTagsResponse) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let jsonData = try? response.result.jsonUTF8Data(),
           let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            dict["result"] = jsonDict
        }
        return dict
    }

    private static func convertGetInApps(_ response: Pushwoosh_DeviceApi_V2_GetInAppsResponse) -> [String: Any] {
        let inAppsArray: [[String: Any]] = response.inApps.map { inApp in
            [
                "url": inApp.url,
                "code": inApp.code,
                "layout": inApp.layout,
                "updated": inApp.updated,
                "closeButtonType": inApp.closeButtonType,
                "hash": inApp.hash,
                "required": inApp.required,
                "priority": inApp.priority,
                "businessCase": inApp.businessCase,
                "gdpr": inApp.gdpr
            ]
        }
        return ["inApps": inAppsArray]
    }

    private static func convertApplicationOpen(_ response: Pushwoosh_DeviceApi_V2_ApplicationOpenResponse) -> [String: Any] {
        guard !response.requiredInapps.isEmpty else {
            return [:]
        }

        var inappsDict: [String: [String: Any]] = [:]
        for (key, inapp) in response.requiredInapps {
            inappsDict[key] = [
                "code": inapp.code,
                "updated": inapp.updated
            ]
        }
        return ["required_inapps": inappsDict]
    }

    private static func convertRegisterDevice(_ response: Pushwoosh_DeviceApi_V2_RegisterDeviceResponse) -> [String: Any] {
        guard !response.iosCategories.isEmpty else {
            return [:]
        }

        let categoriesArray: [[String: Any]] = response.iosCategories.map { category in
            let buttonsArray: [[String: Any]] = category.buttons.map { button in
                [
                    "id": button.id,
                    "label": button.label,
                    "type": button.type,
                    "startApplication": button.startApplication
                ]
            }
            return [
                "categoryId": category.categoryID,
                "buttons": buttonsArray
            ]
        }
        return ["iosCategories": categoriesArray]
    }

    private static func convertCheckDevice(_ response: Pushwoosh_DeviceApi_V2_CheckDeviceResponse) -> [String: Any] {
        return [
            "exist": response.exist,
            "push_token_exist": response.pushTokenExist
        ]
    }

    private static func convertPostEvent(_ response: Pushwoosh_PostEventApi_PostEventResponse) -> [String: Any] {
        var dict: [String: Any] = [:]

        if !response.code.isEmpty {
            dict["code"] = response.code
        }

        if response.hasRichmedia {
            let rm = response.richmedia
            if !rm.url.isEmpty {
                dict["richmedia"] = [
                    "url": rm.url,
                    "code": rm.code,
                    "ts": String(rm.ts),
                    "hash": rm.hash,
                    "tags": [:] as [String: Any]
                ]
            }
        }

        if !response.messageHash.isEmpty {
            dict["message_hash"] = response.messageHash
        }

        return dict
    }
}
