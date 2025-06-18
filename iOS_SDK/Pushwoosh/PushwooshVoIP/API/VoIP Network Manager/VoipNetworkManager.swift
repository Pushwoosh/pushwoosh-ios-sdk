//
//  voipNetworkManager.swift
//  PushwooshVoIP
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

class VoipNetworkManager {
    static let shared = VoipNetworkManager()
    
    func sendInnerRequest(request: PWCoreSetVoIPTokenRequest, completion: @escaping (Error?) -> Void) {
        if request.prepareForExecution() {
            executeInnerRequest(request: request, completion: completion)
        } else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Failed to prepare the request.")
            completion(NSError(domain: "pushwoosh", code: 1, userInfo: [NSLocalizedDescriptionKey: "Request preparation failed."]))
        }
    }
    
    private func executeInnerRequest(request: PWCoreSetVoIPTokenRequest, completion: @escaping (Error?) -> Void) {
        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }
}
