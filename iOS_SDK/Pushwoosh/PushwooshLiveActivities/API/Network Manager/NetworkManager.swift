//
//  PWRequestExecutor.swift
//  PushwooshLiveActivities
//
//  Created by André Kis on 06.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import UIKit

class NetworkManager {
    static let shared = NetworkManager()
    
    func sendInnerRequest(request: PWCoreSetLiveActivityTokenRequest, completion: @escaping (Error?) -> Void) {
        if request.prepareForExecution() {
            executeInnerRequest(request: request, completion: completion)
        } else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Failed to prepare the request.")
            completion(NSError(domain: "pushwoosh", code: 1, userInfo: [NSLocalizedDescriptionKey: "Request preparation failed."]))
        }
    }
    
    private func executeInnerRequest(request: PWCoreSetLiveActivityTokenRequest, completion: @escaping (Error?) -> Void) {
        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }
}


