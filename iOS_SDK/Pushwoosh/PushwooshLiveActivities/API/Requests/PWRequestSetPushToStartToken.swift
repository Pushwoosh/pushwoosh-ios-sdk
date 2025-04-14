//
//  PWRequestSetPushToStartToken.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 14.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

class PWRequestSetPushToStartToken: PWCoreRequest, PWCoreSetLiveActivityTokenRequest, PWCoreSetPushToStartTokenRequest {
    
    var parameters: ActivityRequestParameters
    
    init(parameters: ActivityRequestParameters) {
        self.parameters = parameters
        super.init()
    }
    
    func prepareForExecution() -> Bool {
        guard let pushToStartToken = parameters.pushToStartToken, !pushToStartToken.isEmpty else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Error: Push to start token is missing or empty.")
            return false
        }

        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                  className: self,
                                  message: "Preparing request with push to start token: \(pushToStartToken)")
        return true
    }
    
    override func methodName() -> String {
        return "setActivityPushToStartToken"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        let dict = self.baseDictionary()
        dict["activity_push_to_start_token"] = parameters.pushToStartToken
        return dict as? [AnyHashable : Any] ?? [:]
    }
}
