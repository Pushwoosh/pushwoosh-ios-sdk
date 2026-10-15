//
//  PWKeychainPersistentHWIDProvider.swift
//  PushwooshBridge
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Back-channel through which `PWPreferences` reconciles its HWID with the optional `PushwooshKeychain` module.
@objc
public protocol PWKeychainPersistentHWIDProvider {
    /// `true` when persistent HWID storage is active in the current build.
    @objc var isPersistentHWIDEnabled: Bool { get }

    /// Creates a new HWID, stores it in the keychain and returns it; `nil` when the keychain rejects it.
    @objc func persistentHWID() -> String?

    /// Returns the HWID stored in the keychain without creating one;
    /// `nil` when absent or unreadable.
    @objc func storedPersistentHWID() -> String?

    /// Stores `hwid` in the keychain; `false` when the keychain rejects it.
    @objc func storePersistentHWID(_ hwid: String) -> Bool
}
