//
//  PWRequestSetPushToStartToken.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 14.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst) && os(iOS)
import Foundation
import PushwooshCore

class PWRequestSetPushToStartToken: PWRequest, PWCoreSetLiveActivityTokenRequest, PWCoreSetPushToStartTokenRequest {
    
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
        guard let dict = self.baseDictionary() else {
            return [:]
        }
        dict["activity_push_to_start_token"] = parameters.pushToStartToken
        return dict as? [AnyHashable : Any] ?? [:]
    }
}
#endif
