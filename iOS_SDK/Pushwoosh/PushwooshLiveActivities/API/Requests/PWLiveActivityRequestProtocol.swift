//
//  PWLiveActivityRequest.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

protocol PWCoreSetLiveActivityTokenRequest: PWCoreRequest {
    var parameters: ActivityRequestParameters { get }
    
    func prepareForExecution() -> Bool
}

protocol PWCoreSetPushToStartTokenRequest: PWCoreSetLiveActivityTokenRequest {}
protocol PWCoreStopLiveActivityRequest: PWCoreSetLiveActivityTokenRequest {}

struct ActivityRequestParameters {
    var activityId: String?
    var token: String?
    var pushToStartToken: String?
    
    init(activityId: String? = nil, token: String? = nil, pushToStartToken: String? = nil) {
        self.activityId = activityId
        self.token = token
        self.pushToStartToken = pushToStartToken
    }
}
