//
//  PWRequestStopLiveActivity.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 14.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

class PWRequestStopLiveActivity: PWCoreRequest, PWCoreSetLiveActivityTokenRequest {
    var parameters: ActivityRequestParameters
    
    init(parameters: ActivityRequestParameters) {
        self.parameters = parameters
        super.init()
    }
    
    func prepareForExecution() -> Bool {
        PushwooshLog.pushwooshLog(.PW_LL_DEBUG,
                                  className: self,
                                  message: "Preparing stop live activity request")
        return true
    }
    
    override func methodName() -> String {
        return "setActivityToken"
    }

    override func requestDictionary() -> [AnyHashable: Any] {
        let dict = self.baseDictionary()
        dict["activity_token"] = nil
        dict["activity_id"] = parameters.activityId ?? ""

        return dict as? [AnyHashable : Any] ?? [:]
    }
    
}
