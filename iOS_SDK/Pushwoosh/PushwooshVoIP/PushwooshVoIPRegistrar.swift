//
//  PushwooshVoIPRegistrar.swift
//  PushwooshVoIP
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshBridge

/// Back-channel adapter conforming to `PWVoIPConfigureHandler`. Vended as a
/// singleton via `PushwooshVoIPImplementation.configureBackchannel` and
/// registered with `PushwooshModuleRegistry` from `PushwooshVoIPLoader.m` at
/// module load. `PWPushRuntime` triggers VoIP setup through this handler
/// without touching the implementation class directly.
@available(iOS 14.0, *)
@objc(PushwooshVoIPConfigureBackchannel)
final class PushwooshVoIPConfigureBackchannel: NSObject, PWVoIPConfigureHandler {
    @objc
    func configureVoIP() {
        PushwooshVoIPImplementation.configureVoIP()
    }
}

@available(iOS 14.0, *)
extension PushwooshVoIPImplementation {
    /// Singleton back-channel adapter used by `PWPushRuntime` to trigger
    /// VoIP configuration without reflection.
    @objc
    public static let configureBackchannel: PWVoIPConfigureHandler = PushwooshVoIPConfigureBackchannel()
}
