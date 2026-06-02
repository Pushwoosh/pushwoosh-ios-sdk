//
//  PWRequestStopLiveActivity.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 14.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#if !targetEnvironment(macCatalyst) && os(iOS)
import Foundation
import PushwooshCore

class PWRequestStopLiveActivity: PWRequest, PWCoreSetLiveActivityTokenRequest {
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
        guard let dict = self.baseDictionary() else {
            return [:]
        }
        // Server contract: empty string in activity_token is the stop signal.
        // The single token per activity_id is overwritten by every setActivityToken
        // call; sending "" overwrites the previously-registered token to nothing,
        // effectively ending the activity server-side.
        dict["activity_token"] = ""
        dict["activity_id"] = parameters.activityId ?? ""

        return dict as? [AnyHashable : Any] ?? [:]
    }

}
#endif
