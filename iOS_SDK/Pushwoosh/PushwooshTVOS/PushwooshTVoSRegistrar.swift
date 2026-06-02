//
//  PushwooshTVoSRegistrar.swift
//  PushwooshTVOS
//
//  Created by André Kis on 21.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge

/// Back-channel adapter conforming to `PWTVoSInAppHandler`. Vended as a
/// singleton via `PushwooshTVOSImplementation.inAppBackchannel` and registered
/// with `PushwooshModuleRegistry` from `PushwooshTVoSLoader.m` at module
/// load. `PWInAppMessagesManager` dispatches in-app resources through this
/// handler without a four-hop `performSelector` chain.
@available(tvOS 11.0, *)
@objc(PushwooshTVoSInAppBackchannel)
final class PushwooshTVoSInAppBackchannel: NSObject, PWTVoSInAppHandler {
    @objc
    func handleInAppResource(_ resource: Any) {
        let manager = PushwooshTVOSImplementation.shared.richMediaManager
        let handled = manager.handleInAppResource(resource as AnyObject)
        if !handled {
            PushwooshLog.pushwooshLog(.PW_LL_WARN,
                                     className: PushwooshTVoSInAppBackchannel.self,
                                     message: "richMediaManager.handleInAppResource returned false")
        }
    }
}

@available(tvOS 11.0, *)
extension PushwooshTVOSImplementation {
    /// Singleton back-channel adapter used by `PWInAppMessagesManager` to
    /// dispatch in-app resources to the tvOS rich-media manager without
    /// reflection.
    @objc
    public static let inAppBackchannel: PWTVoSInAppHandler = PushwooshTVoSInAppBackchannel()
}
