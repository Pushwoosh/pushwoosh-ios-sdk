//
//  PWKeychainPersistentHWIDProvider.swift
//  PushwooshBridge
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Back-channel protocol that lets `PushwooshCore` resolve the persistent
/// HWID stored by the optional `PushwooshKeychain` module without
/// reflection.
///
/// The keychain module registers an instance conforming to this protocol via
/// `PushwooshModuleRegistry.registerHandler(_:forIdentifier:)` at load time.
/// `PWPreferences` looks the handler up and forwards `getPersistentHWIDIfAvailable`
/// through it. When the module is not linked the handler is `nil` and the
/// caller falls back to its default behaviour.
@objc
public protocol PWKeychainPersistentHWIDProvider {
    /// `true` when persistent HWID storage is active in the current build.
    @objc var isPersistentHWIDEnabled: Bool { get }

    /// Returns the HWID stored in the keychain, or `nil` when unavailable.
    @objc func persistentHWID() -> String?
}
