//
//  PushwooshSwiftInterface.swift
//  PushwooshiOS
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge

public extension Pushwoosh {
    
    static var LiveActivities: PWLiveActivities.Type {
        return __liveActivities()
    }
    
    static var Debug: PWDebug.Type {
        return __debug()
    }
    
    @available(*, unavailable, message: "This property is not available yet and will be introduced in future releases.")
    static var GDPR: PWGDPR.Type {
        return __gdpr();
    }
}
