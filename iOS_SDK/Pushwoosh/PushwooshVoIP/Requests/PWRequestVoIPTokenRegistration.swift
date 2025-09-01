//
//  PWRequestVoIPTokenRegistration.swift
//  PushwooshVoIP
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

final class PWSetVoIPTokenRequest: PWCoreRequest, PWCoreSetVoIPTokenRequest {
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
        let dict = self.baseDictionary()
        dict["application"] = PWSettings.settingsInstance().voipAppCode
        dict["push_token"] = parameters.token ?? ""
        dict["gateway"] = PWCoreUtils.getAPSProductionStatus(false) ? "production" : "sandbox"
        dict["device_type"] = 1
        dict["timezone"] = PWCoreUtils.timezone()
        
        return dict as! [AnyHashable : Any]
    }
}
