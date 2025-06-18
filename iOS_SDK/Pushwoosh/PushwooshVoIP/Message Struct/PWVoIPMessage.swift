//
//  PWVoIPMessage.swift
//  PushwooshVoIP
//
//  Created by André on 13.05.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshBridge

@objc public enum PWVoIPHandleType: Int {
    case generic = 1
    case phoneNumber = 2
    case email = 3
}

@objc
public class PWVoIPMessage: NSObject {
    @objc public var uuid: String
    @objc public let handleType: PWVoIPHandleType
    @objc public let callerName: String
    @objc public var hasVideo: Bool
    @objc public let supportsHolding: Bool
    @objc public let supportsDTMF: Bool
    @objc public let rawPayload: [AnyHashable: Any]
    
    public init(rawPayload: [AnyHashable: Any]) {
        self.rawPayload = rawPayload
        
        if let handleTypeRaw = rawPayload["handleType"] as? Int,
           let handleType = PWVoIPHandleType(rawValue: handleTypeRaw) {
            self.handleType = handleType
        } else {
            self.handleType = .generic
        }
        
        self.uuid = rawPayload["uuid"] as? String ?? ""
        self.callerName = rawPayload["callerName"] as? String ?? ""
        self.hasVideo = rawPayload["video"] as? Bool ?? false
        self.supportsHolding = rawPayload["supportsHolding"] as? Bool ?? false
        self.supportsDTMF = rawPayload["supportsDTMF"] as? Bool ?? false
    }
}


