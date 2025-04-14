//
//  PWRequestSetActivityToken.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

class PWRequestSetActivityToken: PWCoreRequest, PWCoreSetLiveActivityTokenRequest {
    var parameters: ActivityRequestParameters
    
    init(parameters: ActivityRequestParameters) {
        self.parameters = parameters
        super.init()
    }
    
    func prepareForExecution() -> Bool {
        guard let token = parameters.token, !token.isEmpty else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Error: Start live activity token is missing or empty.")
            return false
        }

        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                  className: self,
                                  message: "Preparing request with live activity token")
        return true
    }

    override func methodName() -> String {
        return "setActivityToken"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        let dict = self.baseDictionary()
        dict["activity_token"] = parameters.token
        dict["activity_id"] = parameters.activityId!.isEmpty ? "" : parameters.activityId
        return dict as? [AnyHashable : Any] ?? [:]
    }
}

