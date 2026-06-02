//
//  PWTVoSInAppHandler.swift
//  PushwooshBridge
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

/// Back-channel protocol that lets `PWInAppMessagesManager` dispatch
/// in-app resources to the optional `PushwooshTVOS` module without a
/// four-hop `performSelector` chain.
///
/// The tvOS module registers a handler conforming to this protocol via
/// `PushwooshModuleRegistry.registerHandler(_:forIdentifier:)` at load time.
/// Core forwards in-app resources through `handleInAppResource(_:)`; when the
/// module is not linked the handler is `nil` and the message is a no-op.
@objc
public protocol PWTVoSInAppHandler {
    /// Hands an opaque in-app resource off to the tvOS rich-media manager.
    @objc func handleInAppResource(_ resource: Any)
}
