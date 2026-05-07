//
//  PWInboxKitStubTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import PushwooshBridge

class PWInboxKitStubTest: XCTestCase {

    /// Verifies that the stub returns its own marker class so the umbrella SDK
    /// can detect whether the optional InboxKit module is linked.
    func testStubReturnsPlaceholderViewController() {
        let cls: AnyClass = PWInboxKitStub.inboxKit()
        XCTAssertEqual(NSStringFromClass(cls), NSStringFromClass(PWInboxKitStub.self))
    }
}
