//
//  PWKeychain.swift
//  PushwooshBridge
//
//  Created by André Kis on 14.01.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation

/// Environment types for the running application.
@objc public enum PWAppEnvironment: Int {
    /// Running in iOS Simulator
    case simulator = 0
    /// Running on device with debug/development provisioning
    case debug = 1
    /// Installed via TestFlight
    case testFlight = 2
    /// Installed from App Store
    case appStore = 3
}

/// Protocol for managing persistent HWID storage using Keychain.
///
/// This module provides persistent device identification that survives app reinstallation.
/// It automatically disables itself in App Store builds to avoid using Keychain in production.
///
/// ## Overview
///
/// When the PushwooshKeychain module is linked and the app is running in a non-production
/// environment (Simulator, Debug, TestFlight), the SDK will:
/// 1. Check Keychain for existing HWID on first launch
/// 2. If found, use the stored HWID (device won't create duplicate)
/// 3. If not found, save current HWID to Keychain for future reinstalls
///
/// In App Store builds, the module is automatically disabled and standard IDFV-based
/// identification is used.
///
/// ## Usage
///
/// Simply link the PushwooshKeychain module to your project. No additional code required.
/// The module activates automatically in non-production environments.
///
/// ```swift
/// // Check if persistent HWID is active
/// if Pushwoosh.Keychain.isEnabled {
///     print("Persistent HWID is active")
/// }
///
/// // Get current environment
/// let env = Pushwoosh.Keychain.currentEnvironment
/// print("Running in: \(env)")
/// ```
///
/// > Important: This module is intended for QA/Development use only.
/// > It automatically disables itself in App Store builds.
@objc
public protocol PWKeychain {

    /// Returns the implementation class for runtime detection.
    @objc static func keychain() -> AnyClass

    /// Indicates whether persistent HWID storage is enabled.
    ///
    /// Returns `true` for Simulator, Debug, and TestFlight builds.
    /// Returns `false` for App Store builds.
    @objc static var isEnabled: Bool { get }

    /// Returns the current application environment.
    @objc static var currentEnvironment: PWAppEnvironment { get }

    /// Returns the persistent HWID from Keychain, or nil if not available.
    ///
    /// This method:
    /// - Returns `nil` in App Store builds (module disabled)
    /// - Returns existing HWID from Keychain if found
    /// - Creates and stores new HWID in Keychain if not found (first launch)
    ///
    /// - Returns: Persistent HWID string, or nil if module is disabled.
    @objc static func getPersistentHWID() -> String?

    /// Clears the stored HWID from Keychain.
    ///
    /// Use this method to reset the persistent HWID.
    /// After calling this method, the next call to `getPersistentHWID()`
    /// will generate and store a new HWID.
    @objc static func clearPersistentHWID()
}
