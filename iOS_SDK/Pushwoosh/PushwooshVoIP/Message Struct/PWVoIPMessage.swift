//
//  PWVoIPMessage.swift
//  PushwooshVoIP
//
//  Created by André on 13.05.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshBridge

/// Display format for caller information in CallKit UI.
@objc public enum PWVoIPHandleType: Int {
    /// Generic identifier like username or custom ID.
    case generic = 1
    /// Phone number with automatic formatting.
    case phoneNumber = 2
    /// Email address format.
    case email = 3
}

/// An encapsulation of VoIP push notification payload data.
@objc
public class PWVoIPMessage: NSObject {
    /// The unique identifier for the call.
    @objc public var uuid: String
    /// The display format for caller information.
    @objc public let handleType: PWVoIPHandleType
    /// The caller's display name or identifier.
    @objc public let callerName: String
    /// A Boolean value that indicates whether the call supports video.
    @objc public var hasVideo: Bool
    /// A Boolean value that indicates whether the call supports hold functionality.
    @objc public let supportsHolding: Bool
    /// A Boolean value that indicates whether the call supports DTMF tones.
    @objc public let supportsDTMF: Bool
    /// The raw push notification payload.
    @objc public let rawPayload: [AnyHashable: Any]

    /// Creates a VoIP message from push notification payload.
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


