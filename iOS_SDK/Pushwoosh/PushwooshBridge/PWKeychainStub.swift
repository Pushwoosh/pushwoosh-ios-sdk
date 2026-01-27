//
//  PWKeychainStub.swift
//  PushwooshBridge
//
//  Created by André Kis on 14.01.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

/// Stub implementation for PWKeychain protocol.
///
/// This stub is used when the PushwooshKeychain module is not linked.
/// All methods return safe default values and print informational messages.
@objc public class PWKeychainStub: NSObject, PWKeychain {

    @objc
    public static func keychain() -> AnyClass {
        return PWKeychainStub.self
    }

    @objc
    public static var isEnabled: Bool {
        return false
    }

    @objc
    public static var currentEnvironment: PWAppEnvironment {
        return .appStore
    }

    @objc
    public static func getPersistentHWID() -> String? {
        return nil
    }

    @objc
    public static func clearPersistentHWID() {
    }
}
