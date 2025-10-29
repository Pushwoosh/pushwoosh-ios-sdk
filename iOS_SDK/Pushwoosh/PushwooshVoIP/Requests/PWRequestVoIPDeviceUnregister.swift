//
//  PWRequestVoIPTokenUnregistration.swift
//  PushwooshVoIP
//
//  Created by André on 14.05.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

final class PWUnregisterVoIPDeviceRequest: PWRequest, PWCoreUnregisterVoIPDeviceRequest {
    let parameters: VoIPRequestParameters

    init(parameters: VoIPRequestParameters) {
        self.parameters = parameters
    }

    func prepareForExecution() -> Bool {
        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                  className: self,
                                  message: "Preparing unregister VoIP device request")
        return true
    }

    override func methodName() -> String {
        return "unregisterDevice"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        let dict = self.baseDictionary()
        return dict as! [AnyHashable : Any]
    }
}
