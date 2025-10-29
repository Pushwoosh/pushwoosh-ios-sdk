//
//  PWVoIPRequestProtocol.swift
//  PushwooshVoIP
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

protocol PWCoreSetVoIPTokenRequest: PWRequest {
    var parameters: VoIPRequestParameters { get }
    func prepareForExecution() -> Bool
}

protocol PWCoreUnregisterVoIPDeviceRequest: PWCoreSetVoIPTokenRequest {}

struct VoIPRequestParameters {
    let token: String?
    
    init(token: String?) {
        self.token = token
    }
}
