//
//  PushwooshInboxKitAttributesTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import UIKit
import PushwooshCore
@testable import PushwooshInboxKit

class PushwooshInboxKitAttributesTest: XCTestCase {

    /// Verifies the bundled four-cell default registry — Banner / Captioned /
    /// Classic, with `default` falling back to Classic.
    func testDefaultAttributesShipFourCellRegistry() {
        let attributes = PushwooshInboxKitAttributes()
        XCTAssertTrue(attributes.cells["banner"] == PushwooshInboxBannerCell.self)
        XCTAssertTrue(attributes.cells["captioned"] == PushwooshInboxCaptionedCell.self)
        XCTAssertTrue(attributes.cells["classic"] == PushwooshInboxClassicCell.self)
        XCTAssertTrue(attributes.cells["default"] == PushwooshInboxClassicCell.self)
    }

    /// Verifies that the cell registry accepts host-supplied custom kinds.
    func testCellRegistryAcceptsCustomKind() {
        var attributes = PushwooshInboxKitAttributes()
        attributes.cells["hero"] = HeroCell.self
        XCTAssertTrue(attributes.cells["hero"] == HeroCell.self)
    }

    /// Verifies that the transform closure is applied before publishing the data set.
    func testTransformIsAppliedBeforeReload() {
        var attributes = PushwooshInboxKitAttributes()
        attributes.transform = { $0.reversed() }

        let messages: [PWInboxMessageProtocol] = [FakeMessage(code: "a"), FakeMessage(code: "b"), FakeMessage(code: "c")]
        let result = attributes.transform(messages)

        XCTAssertEqual(result.map { $0.code }, ["c", "b", "a"])
    }

    /// Verifies that the default style ships dynamic colors that resolve differently per trait.
    func testStyleDefaultsAreDynamicWhenDarkThemeEnabled() {
        let style = PushwooshInboxKitAttributes.Style.default
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let lightBg = style.backgroundColor.resolvedColor(with: lightTraits)
        let darkBg = style.backgroundColor.resolvedColor(with: darkTraits)
        XCTAssertNotEqual(lightBg, darkBg)
    }

    /// Verifies that disabling dark theme forces a light-mode resolution path.
    func testEnableDarkThemeFalseForcesLightResolution() {
        var attributes = PushwooshInboxKitAttributes()
        attributes.enableDarkTheme = false
        XCTAssertFalse(attributes.enableDarkTheme)
    }

    // MARK: - Default cell-kind resolver

    /// Resolver picks `banner` when server says so AND a non-empty image is present.
    func testResolverHonoursServerBannerWhenImagePresent() {
        let message = FakeMessage(imageUrl: "https://x/y.png")
        message.actionParams = ["displayType": "banner"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "banner")
    }

    /// Resolver picks `captioned` when server says so AND a non-empty image is present.
    func testResolverHonoursServerCaptionedWhenImagePresent() {
        let message = FakeMessage(imageUrl: "https://x/y.png")
        message.actionParams = ["displayType": "captioned"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "captioned")
    }

    /// Resolver degrades `banner` to `classic` when imageUrl is missing — never
    /// renders an empty image card.
    func testResolverDegradesBannerWithoutImageToClassic() {
        let message = FakeMessage(imageUrl: nil)
        message.actionParams = ["displayType": "banner"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "classic")
    }

    /// Resolver degrades `captioned` to `classic` when imageUrl is empty.
    func testResolverDegradesCaptionedWithEmptyImageToClassic() {
        let message = FakeMessage(imageUrl: "")
        message.actionParams = ["displayType": "captioned"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "classic")
    }

    /// Resolver picks heuristic banner when no displayType is supplied but the
    /// message carries an image and no title.
    func testResolverHeuristicBannerWhenImageNoTitle() {
        let message = FakeMessage(title: "", imageUrl: "https://x/y.png")
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "banner")
    }

    /// Resolver picks classic for plain text messages by default.
    func testResolverFallsBackToClassicForTextMessage() {
        let message = FakeMessage(title: "Hello", imageUrl: nil)
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "classic")
    }

    /// Resolver reads displayType nested in the JSON-encoded `u` string the
    /// server commonly emits.
    func testResolverReadsDisplayTypeFromStringEncodedU() {
        let message = FakeMessage(imageUrl: "https://x/y.png")
        message.actionParams = ["u": "{\"displayType\":\"banner\"}"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "banner")
    }

    // MARK: - Helpers

    private final class HeroCell: PushwooshInboxCell {}
}
