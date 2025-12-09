//
//  PWRequestVoIPTokenRegistration.swift
//  PushwooshVoIP
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

final class PWSetVoIPTokenRequest: PWRequest, PWCoreSetVoIPTokenRequest {
    let parameters: VoIPRequestParameters

    init(parameters: VoIPRequestParameters) {
        self.parameters = parameters
    }

    func prepareForExecution() -> Bool {
        guard let token = parameters.token, !token.isEmpty else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Error: VoIP token is missing or empty.")
            return false
        }

        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                   className: self,
                                   message: "Preparing request with VoIP token")
        return true
    }

    override func methodName() -> String {
        return "registerDevice"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        guard let dict = self.baseDictionary() else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR,
                                      className: self,
                                      message: "Failed to create base dictionary")
            return [:]
        }

        dict["voip_push_token"] = parameters.token ?? ""
        dict["gateway"] = PWCoreUtils.getAPSProductionStatus(false) ? "production" : "sandbox"
        dict["device_type"] = 1
        dict["timezone"] = PWCoreUtils.timezone()

        if let pushToken = PWPreferences.preferencesInstance().pushToken, !pushToken.isEmpty {
            dict["push_token"] = pushToken
        }

        return dict as! [AnyHashable: Any]
    }
}
