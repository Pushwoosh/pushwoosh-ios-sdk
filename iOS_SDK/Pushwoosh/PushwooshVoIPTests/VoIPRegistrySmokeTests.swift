//
//  VoIPRegistrySmokeTests.swift
//  PushwooshVoIPTests
//
//  Created by André Kis on 25.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import PushwooshCore

/// Confirms that the VoIP module's `+load` registrar populated
/// `PushwooshModuleRegistry` with the expected implementation class and the
/// `configureVoIP` back-channel handler. Any regression — `+load` removed,
/// `@objc(...)` rename, registrar file dropped from the target — flips this to red.
final class VoIPRegistrySmokeTests: XCTestCase {

    /// Verifies that the registered class for the VoIP identifier is the real
    /// implementation, not the missing-module proxy.
    func test_registryHoldsExpectedImplementationClass() throws {
        let resolvedName = Self.registeredClassName(for: "voIP")
        XCTAssertEqual(resolvedName, "PushwooshVoIPImplementation",
                       "Registry returned '\(resolvedName ?? "nil")' instead of the VoIP implementation. Likely `+load` regression in PushwooshVoIPLoader.")
        XCTAssertNotEqual(resolvedName, "PWMissingModule",
                          "Registry fell back to PWMissingModule — implementation class not registered at image load.")
    }

    /// Verifies that the configureVoIP back-channel handler was registered.
    func test_registryHoldsConfigureBackchannelHandler() throws {
        XCTAssertNotNil(Self.registeredHandler(for: "voIP"),
                        "PushwooshModuleRegistry.handlerForIdentifier(voIP) returned nil — VoIP back-channel handler not registered at image load.")
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
