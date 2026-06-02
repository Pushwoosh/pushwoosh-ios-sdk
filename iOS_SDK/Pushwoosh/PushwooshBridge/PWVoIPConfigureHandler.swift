//
//  PWVoIPConfigureHandler.swift
//  PushwooshBridge
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Back-channel protocol that lets `PWPushRuntime` trigger VoIP setup without
/// reflecting on `PushwooshVoIPImplementation`.
///
/// The VoIP module registers a handler conforming to this protocol via
/// `PushwooshModuleRegistry.registerHandler(_:forIdentifier:)` at load time.
/// Core sends `configureVoIP()` through the handler; when the module is not
/// linked the handler is `nil` and the message is a no-op.
@objc
public protocol PWVoIPConfigureHandler {
    /// Performs the VoIP module's first-time configuration.
    @objc func configureVoIP()
}
