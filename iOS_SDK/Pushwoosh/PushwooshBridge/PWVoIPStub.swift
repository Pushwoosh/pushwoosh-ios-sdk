//
//  PWVoIPStub.swift
//  PushwooshBridge
//
//  Created by André on 6.5.25..
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

@objc public class PWVoIPStub: NSObject, PWVoIP {
    public static var delegate: AnyObject?
    
    @objc
    public static func voip() -> AnyClass {
        return PWVoIPStub.self
    }
    
    @objc
    public static func setVoIPToken(_ token: Data) {
        print("PushwooshVoIP not found. To enable VoIP features, make sure the PushwooshVoIP module is added to the project.")
    }
    
    @objc
    public static func initializeVoIP(_ supportVideo: Bool,
                                      ringtoneSound: String,
                                      handleTypes: Int) {
        print("PushwooshVoIP not found. To enable VoIP features, make sure the PushwooshVoIP module is added to the project.")
    }
}
