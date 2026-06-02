//
//  TVOSRegistrySmokeTests.swift
//  PushwooshTVOSTests
//
//  Created by André Kis on 25.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import PushwooshCore

/// Confirms that the tvOS module's `+load` registrar populated
/// `PushwooshModuleRegistry` with the expected implementation class and the
/// in-app back-channel handler. Any regression — `+load` removed, `@objc(...)`
/// rename, registrar file dropped from the target — flips this to red.
final class TVOSRegistrySmokeTests: XCTestCase {

    /// Verifies that the registered class for the TVoS identifier is the real
    /// implementation, not the missing-module proxy.
    func test_registryHoldsExpectedImplementationClass() throws {
        let resolvedName = Self.registeredClassName(for: "tvOS")
        XCTAssertEqual(resolvedName, "PushwooshTVOSImplementation",
                       "Registry returned '\(resolvedName ?? "nil")' instead of the tvOS implementation. Likely `+load` regression in PushwooshTVoSLoader.")
        XCTAssertNotEqual(resolvedName, "PWMissingModule",
                          "Registry fell back to PWMissingModule — implementation class not registered at image load.")
    }

    /// Verifies that the in-app back-channel handler was registered.
    func test_registryHoldsInAppBackchannelHandler() throws {
        XCTAssertNotNil(Self.registeredHandler(for: "tvOS"),
                        "PushwooshModuleRegistry.handlerForIdentifier(tvOS) returned nil — tvOS back-channel handler not registered at image load.")
    }

    private static func registeredClassName(for identifier: String) -> String? {
        guard let registryClass = NSClassFromString("PushwooshModuleRegistry") as? NSObject.Type else {
            return nil
        }
        let selector = NSSelectorFromString("classForIdentifier:")
        guard registryClass.responds(to: selector) else { return nil }
        let identifierNS: NSString = identifier as NSString
        guard let resolved = registryClass.perform(selector, with: identifierNS)?.takeUnretainedValue() as? AnyClass else {
            return nil
        }
        return NSStringFromClass(resolved)
    }

    private static func registeredHandler(for identifier: String) -> Any? {
        guard let registryClass = NSClassFromString("PushwooshModuleRegistry") as? NSObject.Type else {
            return nil
        }
        let selector = NSSelectorFromString("handlerForIdentifier:")
        guard registryClass.responds(to: selector) else { return nil }
        let identifierNS: NSString = identifier as NSString
        return registryClass.perform(selector, with: identifierNS)?.takeUnretainedValue()
    }
}
