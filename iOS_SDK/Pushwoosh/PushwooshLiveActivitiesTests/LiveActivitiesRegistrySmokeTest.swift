//
//  LiveActivitiesRegistrySmokeTest.swift
//  PushwooshLiveActivitiesTests
//
//  Created by André Kis on 25.05.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import PushwooshCore

/// Confirms that `PushwooshLiveActivitiesLoader.+load` actually populated
/// `PushwooshModuleRegistry` with the expected implementation class. Any
/// regression — `+load` removed, `@objc(...)` rename, Loader file dropped from
/// target — flips this to red.
final class LiveActivitiesRegistrySmokeTest: XCTestCase {

    /// Verifies that the registered class for the LiveActivities identifier is
    /// the real implementation, not the missing-module proxy.
    func test_registryHoldsExpectedImplementationClass() throws {
        guard let registryClass = NSClassFromString("PushwooshModuleRegistry") as? NSObject.Type else {
            XCTFail("PushwooshModuleRegistry not available in the runtime — Core not linked.")
            return
        }

        let selector = NSSelectorFromString("classForIdentifier:")
        guard registryClass.responds(to: selector) else {
            XCTFail("PushwooshModuleRegistry+classForIdentifier: missing — Registry surface changed.")
            return
        }

        let identifier: NSString = "liveActivities"
        guard let resolved = registryClass.perform(selector, with: identifier)?.takeUnretainedValue() as? AnyClass else {
            XCTFail("PushwooshModuleRegistry.classForIdentifier(liveActivities) returned a nil/unexpected value.")
            return
        }

        let resolvedName = NSStringFromClass(resolved)
        XCTAssertEqual(resolvedName, "PushwooshLiveActivitiesImplementationSetup",
                       "Registry returned '\(resolvedName)' instead of the LiveActivities implementation. Likely `+load` regression in PushwooshLiveActivitiesLoader.m.")
        XCTAssertNotEqual(resolvedName, "PWMissingModule",
                          "Registry fell back to PWMissingModule — implementation class not registered at image load.")
    }
}
