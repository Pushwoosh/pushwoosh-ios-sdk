//
//  PWKeychainHelper.swift
//  PushwooshKeychain
//
//  Created by André Kis on 27.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation
import Security
import PushwooshCore

/// Helper class for secure Keychain operations.
///
/// Provides methods to read, write, and delete HWID from iOS Keychain.
/// The stored data persists across app reinstallation.
/// All operations are thread-safe.
final class PWKeychainHelper {

    private static let service = "com.pushwoosh.keychain"
    private static let account = "persistent_hwid"
    private static let lock = NSLock()

    /// Reads the stored HWID from Keychain.
    ///
    /// - Returns: The stored HWID string, or nil if not found.
    static func read() -> String? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let hwid = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                PushwooshLog.pushwooshLog(
                    .PW_LL_DEBUG,
                    className: self,
                    message: "Keychain read status: \(status)"
                )
            }
            return nil
        }

        return hwid
    }

    /// Saves HWID to Keychain.
    ///
    /// Uses SecItemUpdate if item exists, SecItemAdd otherwise.
    /// - Parameter hwid: The HWID string to store.
    /// - Returns: `true` if save was successful, `false` otherwise.
    @discardableResult
    static func save(_ hwid: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let data = hwid.data(using: .utf8) else {
            PushwooshLog.pushwooshLog(
                .PW_LL_ERROR,
                className: self,
                message: "Failed to convert HWID to data"
            )
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Try to update existing item first
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, add new one
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status == errSecSuccess {
            PushwooshLog.pushwooshLog(
                .PW_LL_DEBUG,
                className: self,
                message: "HWID saved to Keychain successfully"
            )
            return true
        } else {
            PushwooshLog.pushwooshLog(
                .PW_LL_ERROR,
                className: self,
                message: "Failed to save HWID to Keychain. Status: \(status)"
            )
            return false
        }
    }

    /// Deletes the stored HWID from Keychain.
    ///
    /// - Returns: `true` if deletion was successful or item didn't exist, `false` on error.
    @discardableResult
    static func delete() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            if status == errSecSuccess {
                PushwooshLog.pushwooshLog(
                    .PW_LL_DEBUG,
                    className: self,
                    message: "HWID deleted from Keychain"
                )
            }
            return true
        } else {
            PushwooshLog.pushwooshLog(
                .PW_LL_ERROR,
                className: self,
                message: "Failed to delete HWID from Keychain. Status: \(status)"
            )
            return false
        }
    }
}
