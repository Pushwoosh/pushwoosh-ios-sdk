//
//  VoipNetworkManager.swift
//  PushwooshVoIP
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore

class VoipNetworkManager {
    static let shared = VoipNetworkManager()

    typealias Transport = (PWCoreSetVoIPTokenRequest, @escaping (Error?) -> Void) -> Void

    private let transport: Transport

    /// The default transport is the live request manager, so `shared` behaves exactly as
    /// before; a test passes its own and stops depending on a reachable server.
    init(transport: @escaping Transport = { request, completion in
        PushwooshCoreManager.sharedManager().send(request) { error in
            completion(error)
        }
    }) {
        self.transport = transport
    }

    func sendInnerRequest(request: PWCoreSetVoIPTokenRequest, completion: @escaping (Error?) -> Void) {
        if request.prepareForExecution() {
            executeInnerRequest(request: request, completion: completion)
        } else {
            PushwooshLog.pushwooshLog(.PW_LL_ERROR, className: self, message: "Failed to prepare the request.")
            completion(NSError(domain: "pushwoosh", code: 1, userInfo: [NSLocalizedDescriptionKey: "Request preparation failed."]))
        }
    }

    private func executeInnerRequest(request: PWCoreSetVoIPTokenRequest, completion: @escaping (Error?) -> Void) {
        transport(request, completion)
    }
}
