//
//  PWTVOSAPIClient.swift
//  PushwooshTVOS
//
//  Created by André Kis on 06.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import PushwooshCore

@available(tvOS 11.0, *)
class PWTVOSAPIClient {

    func registerDevice(appCode: String, token: String, hwid: String, completion: @escaping (Error?) -> Void) {
        let request = PWTVOSRegisterRequest(appCode: appCode, token: token, hwid: hwid)

        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }

    func unregisterDevice(completion: @escaping (Error?) -> Void) {
        let request = PWTVOSUnregisterRequest()

        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }
}

@available(tvOS 11.0, *)
private final class PWTVOSRegisterRequest: PWRequest {

    private let appCode: String
    private let token: String
    private let hwid: String

    init(appCode: String, token: String, hwid: String) {
        self.appCode = appCode
        self.token = token
        self.hwid = hwid
        super.init()
    }

    override func methodName() -> String {
        return "registerDevice"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        guard let dict = baseDictionary() else {
            return [:]
        }

        dict["application"] = appCode
        dict["push_token"] = token
        dict["hwid"] = hwid
        dict["device_type"] = 1
        dict["timezone"] = PWCoreUtils.timezone()
        dict["gateway"] = PWCoreUtils.getAPSProductionStatus(false) ? "production" : "sandbox"
        dict["package"] = Bundle.main.bundleIdentifier ?? ""
        dict["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        dict["os_version"] = UIDevice.current.systemVersion
        dict["device_model"] = getDeviceModel()
        dict["language"] = Locale.current.languageCode ?? "en"

        return dict as! [AnyHashable: Any]
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

@available(tvOS 11.0, *)
private final class PWTVOSUnregisterRequest: PWRequest {

    override func methodName() -> String {
        return "unregisterDevice"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        let dict = baseDictionary()
        return dict as! [AnyHashable: Any]
    }
}
