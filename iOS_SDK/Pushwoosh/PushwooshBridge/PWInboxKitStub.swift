//
//  PWInboxKitStub.swift
//  PushwooshBridge
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Default no-op implementation of ``PWInboxKit`` used when the
/// `PushwooshInboxKit` optional module is not linked.
public class PWInboxKitStub: NSObject, PWInboxKit {

    private static var didWarn = false

    @objc
    public static func inboxKit() -> AnyClass {
        warnOnce()
        return PWInboxKitStub.self
    }

    private static func warnOnce() {
        if !didWarn {
            didWarn = true
            print("PushwooshInboxKit not linked. Add PushwooshXCFramework/PushwooshInboxKit subspec.")
        }
    }
}
