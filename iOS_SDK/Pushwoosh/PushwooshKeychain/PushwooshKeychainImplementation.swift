//
//  PushwooshKeychainImplementation.swift
//  PushwooshKeychain
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge
#if canImport(UIKit)
import UIKit
#endif

/// Implementation of persistent HWID storage using iOS Keychain.
///
/// This module provides persistent device identification that survives app reinstallation.
/// It automatically disables itself in App Store builds.
@available(iOS 12.0, *)
@objc(PushwooshKeychainImplementation)
public class PushwooshKeychainImplementation: NSObject, PWKeychain {

    /// Shared singleton instance.
    @objc(shared)
    public static let shared = PushwooshKeychainImplementation()

    /// Cached environment to avoid repeated detection.
    private static var cachedEnvironment: PWAppEnvironment?

    /// Returns the Keychain implementation class.
    @objc
    public static func keychain() -> AnyClass {
        return PushwooshKeychainImplementation.self
    }

    /// Indicates whether persistent HWID storage is enabled.
    ///
    /// Returns `true` for Simulator, Debug, and TestFlight builds.
    /// Returns `false` for App Store builds.
    @objc
    public static var isEnabled: Bool {
        return currentEnvironment != .appStore
    }

    /// Returns the current application environment.
    @objc
    public static var currentEnvironment: PWAppEnvironment {
        if let cached = cachedEnvironment {
            return cached
        }

        let detected = PWEnvironmentDetector.detect()
        cachedEnvironment = detected

        let environmentName: String
        switch detected {
        case .simulator:
            environmentName = "Simulator"
        case .debug:
            environmentName = "Debug"
        case .testFlight:
            environmentName = "TestFlight"
        case .appStore:
            environmentName = "App Store"
        @unknown default:
            environmentName = "Unknown"
        }

        PushwooshLog.pushwooshLog(
            .PW_LL_INFO,
            className: self,
            message: "Detected environment: \(environmentName). Persistent HWID: \(detected != .appStore ? "ENABLED" : "DISABLED")"
        )

        return detected
    }

    /// Returns the persistent HWID from Keychain, or nil if not available.
    ///
    /// This method:
    /// - Returns `nil` in App Store builds (module disabled)
    /// - Returns existing HWID from Keychain if found
    /// - Creates and stores new HWID in Keychain if not found (first launch)
    @objc
    public static func getPersistentHWID() -> String? {
        guard isEnabled else {
            return nil
        }

        if let existingHWID = PWKeychainHelper.read() {
            PushwooshLog.pushwooshLog(
                .PW_LL_INFO,
                className: self,
                message: "Using persistent HWID from Keychain"
            )
            return existingHWID
        }

        let newHWID = generateHWID()

        PushwooshLog.pushwooshLog(
            .PW_LL_INFO,
            className: self,
            message: "First launch detected. Saving HWID to Keychain for persistence across reinstalls."
        )

        if PWKeychainHelper.save(newHWID) {
            return newHWID
        } else {
            PushwooshLog.pushwooshLog(
                .PW_LL_ERROR,
                className: self,
                message: "Failed to save HWID to Keychain. Persistent HWID disabled for this session."
            )
            return nil
        }
    }

    /// Clears the stored HWID from Keychain.
    @objc
    public static func clearPersistentHWID() {
        PWKeychainHelper.delete()
        PushwooshLog.pushwooshLog(
            .PW_LL_INFO,
            className: self,
            message: "Persistent HWID cleared from Keychain"
        )
    }

    /// Generates a new HWID using identifierForVendor or UUID.
    private static func generateHWID() -> String {
        #if canImport(UIKit) && !os(watchOS)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        #endif
        return UUID().uuidString
    }
}
