//
//  PWInlineStoreTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWInlineStoreTest: XCTestCase {

    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("banners.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func banner(_ slotId: String, id: String, version: Int = 1) throws -> PWInlineBanner {
        let raw: [String: Any] = ["bannerId": id, "version": version, "format": "native",
                                  "native": ["root": ["type": "text", "text": id]]]
        return try XCTUnwrap(PWInlineParser.banner(from: raw, slotId: slotId, receivedAt: Date()))
    }

    /// Verifies that an answer puts each slot's banner and empties the answered slots that got none.
    func testApplyPutsBannersAndEmptiesSlotsWithout() throws {
        let store = PWInlineStore(fileURL: fileURL)

        let filled = store.apply(["home_top", "cart_top"],
                                 banners: ["home_top": try banner("home_top", id: "a"), "cart_top": try banner("cart_top", id: "b")])
        let emptied = store.apply(["home_top"], banners: [:])

        XCTAssertEqual(Set(filled), ["home_top", "cart_top"])
        XCTAssertEqual(emptied, ["home_top"])
        XCTAssertNil(store.banner(for: "home_top"))
        XCTAssertEqual(store.banner(for: "cart_top")?.bannerId, "b")
    }

    /// Verifies that the same banner at the same version is not a change, while a newer version is.
    func testRepeatedBannerIsNotAChange() throws {
        let store = PWInlineStore(fileURL: fileURL)
        store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a", version: 1)])

        let repeated = store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a", version: 1)])
        let updated = store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a", version: 2)])

        XCTAssertEqual(repeated, [])
        XCTAssertEqual(updated, ["home_top"])
        XCTAssertEqual(store.banner(for: "home_top")?.version, 2)
    }

    /// Verifies that a banner the user closed does not come back at the same version.
    func testClosedBannerDoesNotComeBack() throws {
        let store = PWInlineStore(fileURL: fileURL)
        store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a")])

        store.dismiss("home_top")
        store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a")])

        XCTAssertNil(store.banner(for: "home_top"))
    }

    /// Verifies that a new store instance over the same file sees previously received banners (cold start).
    func testBannersSurviveRelaunch() throws {
        PWInlineStore(fileURL: fileURL).apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a")])

        let relaunched = PWInlineStore(fileURL: fileURL)

        XCTAssertEqual(relaunched.banner(for: "home_top")?.bannerId, "a")
        XCTAssertEqual(relaunched.banner(for: "home_top")?.slotId, "home_top")
    }

    /// Verifies that a subscriber gets the current banner at once and every later change until cancelled.
    func testSubscriberReceivesCurrentAndLaterChanges() throws {
        let store = PWInlineStore(fileURL: fileURL)
        store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "a")])
        var received: [String?] = []

        var subscription: PWInlineSubscription? = store.subscribe("home_top") { received.append($0?.bannerId) }
        store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "b")])
        store.apply(["cart_top"], banners: ["cart_top": try banner("cart_top", id: "c")])
        store.apply(["home_top"], banners: [:])
        subscription = nil
        store.apply(["home_top"], banners: ["home_top": try banner("home_top", id: "d")])

        XCTAssertNil(subscription)
        XCTAssertEqual(received, ["a", "b", nil])
    }

    /// Verifies that the default store file lives in Application Support, not in purgeable Caches.
    func testDefaultFileIsInApplicationSupport() {
        XCTAssertTrue(PWInlineStore.defaultFileURL.path.contains("/Library/Application Support/"))
    }
}
#endif
