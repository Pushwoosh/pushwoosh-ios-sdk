//
//  PushwooshInAppRegistrar.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import Foundation
import PushwooshBridge

/// Back-channel adapter conforming to `PWInAppHandler`. Vended as a singleton via
/// `PushwooshInAppImplementation.configureBackchannel` and registered with
/// `PushwooshModuleRegistry` from `PushwooshInAppLoader.m`. Core forwards in-app
/// configs (`native-config.json` from a postEvent resource ZIP) through
/// `handleInAppConfig(_:onShown:)`; `onShown` fires on actual display so Core
/// can send the same show statistics as regular in-apps.
@objc(PushwooshInAppBackchannel)
final class PushwooshInAppBackchannel: NSObject, PWInAppHandler {

    @objc
    func handleInAppConfig(_ config: [AnyHashable: Any]) {
        handleInAppConfig(config, onShown: nil)
    }

    @objc
    func handleInAppConfig(_ config: [AnyHashable: Any], onShown: (() -> Void)?) {
        handleInAppConfig(config, onShown: onShown, onClicked: nil, onClosed: nil)
    }

    @objc
    func handleInAppConfig(_ config: [AnyHashable: Any],
                           onShown: (() -> Void)?,
                           onClicked: (() -> Void)?,
                           onClosed: (() -> Void)?) {
        guard var message = PWInAppConfigParser.parse(config) else {
            return
        }
        message.onShown = onShown
        message.onClicked = onClicked
        message.onClosed = onClosed
        PushwooshInAppUI.shared.present(message)
    }
}
#endif
