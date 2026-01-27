//
//  PWEnvironmentDetector.swift
//  PushwooshKeychain
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshBridge

/// Detects the current application runtime environment.
///
/// This class determines whether the app is running in:
/// - Simulator
/// - Debug/Development build on device
/// - TestFlight
/// - App Store
///
/// The detection is based on:
/// - Presence of `embedded.mobileprovision` file (Debug/AdHoc/Enterprise)
/// - Receipt file name (`sandboxReceipt` for TestFlight)
/// - Simulator target environment
final class PWEnvironmentDetector {

    /// Returns the current application environment.
    static func detect() -> PWAppEnvironment {
        #if targetEnvironment(simulator)
        return .simulator
        #else

        if hasEmbeddedMobileProvision() {
            return .debug
        }

        if isAppStoreReceiptSandbox() {
            return .testFlight
        }

        return .appStore

        #endif
    }

    /// Checks if the app bundle contains embedded.mobileprovision.
    ///
    /// This file is present in:
    /// - Debug builds (development provisioning)
    /// - Ad Hoc distribution builds
    /// - Enterprise distribution builds
    ///
    /// This file is NOT present in:
    /// - TestFlight builds
    /// - App Store builds
    private static func hasEmbeddedMobileProvision() -> Bool {
        return Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }

    /// Checks if the app store receipt is a sandbox receipt.
    ///
    /// TestFlight builds have a receipt file named "sandboxReceipt".
    /// App Store builds have a receipt file named "receipt".
    private static func isAppStoreReceiptSandbox() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }
}
