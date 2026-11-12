//
//  PWInlineManagerTest.swift
//  PushwooshTests
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
import PushwooshCore
import PushwooshBridge
@testable import PushwooshInApp

private final class PWInlineDelegateRecorder: NSObject, PWInlineDelegate {
    var updates: [String] = []

    func inlineSlot(_ slotId: String, didUpdate banner: PushwooshInlineBanner?) {
        updates.append("\(slotId)=\(banner?.bannerId ?? "empty")")
    }
}

class PWInlineManagerTest: XCTestCase {

    private var fileURL: URL!
    private var sent: [PWGetInlineBannersRequest] = []
    private var response: [String: Any] = [:]
    private var failure: Error?
    private var manager: PWInlineManager!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("banners.json")
        manager = PWInlineManager(store: PWInlineStore(fileURL: fileURL), transport: { [unowned self] request, completion in
            self.sent.append(request)
            if let failure = self.failure {
                completion(failure)
                return
            }
            request.parseResponse(self.response)
            completion(nil)
        }, eventSender: { _, completion in completion(nil) })
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private func nativeBanner(_ id: String, version: Int = 1) -> [String: Any] {
        ["bannerId": id, "version": version, "format": "native",
         "native": ["root": ["type": "text", "text": id]], "payload": ["campaign": "autumn"]]
    }

    @discardableResult
    private func request(_ slotIds: [String]) -> Error? {
        var result: Error?
        var finished = false
        manager.requestSlots(slotIds) { error in
            result = error
            finished = true
        }
        XCTAssertTrue(finished)
        return result
    }

    /// Verifies that one getInlineBanners call carries each requested slot once and both formats the SDK draws.
    func testRequestCarriesUniqueSlotsAndBothFormats() throws {
        response = ["slots": [:]]

        request(["home_top", "cart_bottom", "home_top", ""])

        let sentRequest = try XCTUnwrap(sent.first)
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sentRequest.methodName(), "getInlineBanners")
        XCTAssertEqual(sentRequest.slots, ["home_top", "cart_bottom"])
        XCTAssertEqual(sentRequest.formats, ["native", "html"])
    }

    /// Verifies that an html banner reaches the app with its format and document.
    func testHTMLBannerReachesAppWithDocument() throws {
        let document = "<html><body>Autumn sale</body></html>"
        response = ["slots": ["home_top": ["bannerId": "story", "version": 1, "format": "html", "html": document]]]

        request(["home_top"])

        let banner = try XCTUnwrap(manager.banner(forSlot: "home_top"))
        XCTAssertEqual(banner.format, "html")
        XCTAssertEqual(banner.html, document)
    }

    /// Verifies that the answer fills the slots it has a banner for and leaves null and missing slots empty.
    func testResponseFillsSlotsAndEmptiesTheRest() {
        response = ["slots": ["home_top": nativeBanner("b1"), "cart_bottom": NSNull()]]

        XCTAssertNil(request(["home_top", "cart_bottom", "pdp_top"]))

        XCTAssertEqual(manager.banner(forSlot: "home_top")?.bannerId, "b1")
        XCTAssertEqual(manager.banner(forSlot: "home_top")?.payload, ["campaign": "autumn"])
        XCTAssertNil(manager.banner(forSlot: "cart_bottom"))
        XCTAssertNil(manager.banner(forSlot: "pdp_top"))
    }

    /// Verifies that a later empty answer for the slot removes its banner.
    func testEmptyAnswerRemovesBanner() {
        response = ["slots": ["home_top": nativeBanner("b1")]]
        request(["home_top"])

        response = ["slots": ["home_top": NSNull()]]
        request(["home_top"])

        XCTAssertNil(manager.banner(forSlot: "home_top"))
    }

    /// Verifies that slots the app did not request are ignored even when the server sends them.
    func testUnrequestedSlotsAreIgnored() {
        response = ["slots": ["home_top": nativeBanner("b1"), "cart_bottom": nativeBanner("b2")]]

        request(["home_top"])

        XCTAssertNil(manager.banner(forSlot: "cart_bottom"))
    }

    /// Verifies that a banner breaking the contract leaves its slot empty.
    func testBrokenBannerLeavesSlotEmpty() {
        response = ["slots": ["home_top": nativeBanner("b1")]]
        request(["home_top"])

        response = ["slots": ["home_top": ["bannerId": "b2", "version": 1, "format": "flash"]]]
        request(["home_top"])

        XCTAssertNil(manager.banner(forSlot: "home_top"))
    }

    /// Verifies that the delegate hears about the slots whose banner changed and not about repeats.
    func testDelegateGetsChangedSlots() {
        let recorder = PWInlineDelegateRecorder()
        manager.delegate = recorder
        response = ["slots": ["home_top": nativeBanner("b1"), "cart_bottom": NSNull()]]

        request(["home_top", "cart_bottom"])
        request(["home_top", "cart_bottom"])
        response = ["slots": ["home_top": NSNull()]]
        request(["home_top"])

        XCTAssertEqual(recorder.updates, ["home_top=b1", "home_top=empty"])
    }

    /// Verifies that a failed request reports the error and keeps the banners the slots already had.
    func testFailedRequestKeepsBanners() {
        response = ["slots": ["home_top": nativeBanner("b1")]]
        request(["home_top"])

        failure = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let error = request(["home_top"])

        XCTAssertNotNil(error)
        XCTAssertEqual(manager.banner(forSlot: "home_top")?.bannerId, "b1")
    }

    /// Verifies that a request without any slot id fails without network.
    func testRequestWithoutSlotsFailsWithoutNetwork() {
        let error = request(["", ""])

        XCTAssertNotNil(error)
        XCTAssertTrue(sent.isEmpty)
    }
}
#endif
