//
//  PushwooshInboxKitImplementationTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshInboxKit

class PushwooshInboxKitImplementationTest: XCTestCase {

    /// Verifies that the public factory returns a concrete inbox VC instance.
    func testFactoryReturnsConcreteVC() {
        let vc = PushwooshInboxKitImplementation.makeViewController()
        XCTAssertTrue(vc is PushwooshInboxKitViewController)
    }
}
