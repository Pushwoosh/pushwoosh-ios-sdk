//
//  PushwooshInboxKitImplementationTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import UIKit
import PushwooshBridge
@testable import PushwooshInboxKit

class PushwooshInboxKitImplementationTest: XCTestCase {

    /// Verifies that the public factory returns a concrete inbox VC instance.
    func testFactoryReturnsConcreteVC() {
        let vc = PushwooshInboxKitImplementation.makeViewController()
        XCTAssertTrue(vc is PushwooshInboxKitViewController)
    }

    /// Verifies that the public factory keeps returning a non-optional controller to Swift callers.
    func testFactoryKeepsNonOptionalReturnType() {
        let vc: UIViewController = PushwooshInboxKitImplementation.makeViewController()
        XCTAssertTrue(vc is PushwooshInboxKitViewController)
    }

    /// Verifies that the factory is reachable through the PWInboxKit bridge protocol behind Pushwoosh.InboxKit.
    func testFactoryReachableThroughBridgeProtocol() {
        let kit: PWInboxKit.Type = PushwooshInboxKitImplementation.self
        XCTAssertTrue(kit.makeViewController() is PushwooshInboxKitViewController)
    }
}
