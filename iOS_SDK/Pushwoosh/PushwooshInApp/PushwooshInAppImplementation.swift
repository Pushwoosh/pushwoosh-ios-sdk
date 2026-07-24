//
//  PushwooshInAppImplementation.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import PushwooshCore
import PushwooshBridge

/// Implementation behind `Pushwoosh.inApp`, registered into
/// `PushwooshModuleRegistry` from `PushwooshInAppLoader.m` at module load.
/// Conforms to the `PWInApp` bridge protocol; forwards to `PushwooshInAppUI`.
@objc(PushwooshInAppImplementation)
public final class PushwooshInAppImplementation: NSObject, PWInApp {

    /// Presents a native in-app from a raw config dictionary. Manual / testing
    /// entry point — production in-apps arrive via the `PWInAppHandler`
    /// back-channel (`native-config.json` from a postEvent resource ZIP).
    @objc
    public static func present(_ config: [AnyHashable: Any]) {
        guard let message = PWInAppConfigParser.parse(config) else {
            return
        }
        PushwooshInAppUI.shared.present(message)
    }

    @objc
    public static var delegate: AnyObject? {
        get { PushwooshInAppUI.shared.delegate }
        set { PushwooshInAppUI.shared.delegate = newValue as? PWInAppMessageDelegate }
    }

    @objc
    public static var isPaused: Bool {
        get { PushwooshInAppUI.shared.isPaused }
        set { PushwooshInAppUI.shared.isPaused = newValue }
    }

    @objc
    public static var isPresenting: Bool {
        PushwooshInAppUI.shared.isPresenting
    }

    @objc
    public static func dismiss() {
        PushwooshInAppUI.shared.dismissVisible()
    }

    @objc
    public static func setFrequencyCapEnabled(_ enabled: Bool) {
        PWInAppFrequencyStore.shared.isCapEnabled = enabled
    }

    /// Singleton back-channel adapter registered by `PushwooshInAppLoader.m`.
    @objc
    public static let configureBackchannel: PWInAppHandler = PushwooshInAppBackchannel()
}
#endif
