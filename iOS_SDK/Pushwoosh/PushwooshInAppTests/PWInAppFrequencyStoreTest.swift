//
//  PWInAppFrequencyStoreTest.swift
//  PushwooshTests
//
//  Created by André Kis on 15.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWInAppFrequencyStoreTest: XCTestCase {

    private let store = PWInAppFrequencyStore.shared

    override func setUp() {
        super.setUp()
        store.isCapEnabled = false
    }

    override func tearDown() {
        store.isCapEnabled = false
        super.tearDown()
    }

    private func makeModel(id: String? = UUID().uuidString,
                           maxDisplays: Int? = nil,
                           cooldown: TimeInterval? = nil,
                           expireDate: Date? = nil) -> PWInAppMessageModel {
        let content = PWInAppModalContent(backgroundColor: .white,
                                          title: PWInAppText(text: "T", color: nil),
                                          message: nil,
                                          imageURL: nil,
                                          showCloseButton: true,
                                          buttons: [],
                                          dimsBackground: true)
        return PWInAppMessageModel(id: id,
                                   layout: .modal(content),
                                   maxDisplays: maxDisplays,
                                   cooldown: cooldown,
                                   expireDate: expireDate)
    }

    /// Verifies that maxDisplays and cooldown are ignored while the frequency cap toggle is off (opt-in default).
    func testCapsIgnoredByDefault() {
        let model = makeModel(maxDisplays: 1, cooldown: 3600)

        store.recordShown(model)

        XCTAssertTrue(store.canShow(model))
    }

    /// Verifies that maxDisplays is enforced once the frequency cap toggle is on.
    func testMaxDisplaysEnforcedWhenEnabled() {
        store.isCapEnabled = true
        let model = makeModel(maxDisplays: 1)

        XCTAssertTrue(store.canShow(model))
        store.recordShown(model)

        XCTAssertFalse(store.canShow(model))
    }

    /// Verifies that cooldown is enforced once the frequency cap toggle is on.
    func testCooldownEnforcedWhenEnabled() {
        store.isCapEnabled = true
        let model = makeModel(cooldown: 3600)

        store.recordShown(model)

        XCTAssertFalse(store.canShow(model))
    }

    /// Verifies that an expired message is always dropped, even with the cap toggle off.
    func testExpireDateAlwaysEnforced() {
        let model = makeModel(expireDate: Date(timeIntervalSinceNow: -60))

        XCTAssertFalse(store.canShow(model))
    }

    /// Verifies that caps are skipped for messages without an id even when the toggle is on.
    func testNilIdSkipsCaps() {
        store.isCapEnabled = true
        let model = makeModel(id: nil, maxDisplays: 1)

        store.recordShown(model)

        XCTAssertTrue(store.canShow(model))
    }
}
#endif
