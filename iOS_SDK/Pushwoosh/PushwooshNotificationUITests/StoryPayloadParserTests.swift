//
//  StoryPayloadParserTests.swift
//  PushwooshNotificationUITests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshNotificationUI

final class StoryPayloadParserTests: XCTestCase {

    /// Parses a well-formed pw_stories block into one StoryPage per entry with all fields mapped.
    func testParsesWellFormedPayload() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": [
                "pages": [
                    ["image": "https://example.com/1.jpg",
                     "duration": 7.0,
                     "link": "myapp://sale",
                     "button_title": "Buy"],
                    ["image": "https://example.com/2.jpg"]
                ]
            ]
        ]

        let pages = StoryPayloadParser.parse(userInfo: userInfo)

        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].imageURL, URL(string: "https://example.com/1.jpg"))
        XCTAssertEqual(pages[0].duration, 7.0)
        XCTAssertEqual(pages[0].link, URL(string: "myapp://sale"))
        XCTAssertEqual(pages[0].buttonTitle, "Buy")
        XCTAssertEqual(pages[1].imageURL, URL(string: "https://example.com/2.jpg"))
        XCTAssertEqual(pages[1].duration, StoryPage.defaultDuration)
        XCTAssertNil(pages[1].link)
        XCTAssertNil(pages[1].buttonTitle)
    }

    /// Returns an empty array when the pw_stories block is absent.
    func testMissingBlockReturnsEmpty() {
        let pages = StoryPayloadParser.parse(userInfo: ["aps": ["alert": "hi"]])
        XCTAssertTrue(pages.isEmpty)
    }

    /// Returns an empty array when the pages array is empty.
    func testEmptyPagesReturnsEmpty() {
        let userInfo: [AnyHashable: Any] = ["pw_stories": ["pages": []]]
        XCTAssertTrue(StoryPayloadParser.parse(userInfo: userInfo).isEmpty)
    }

    /// Skips entries with a missing or non-string image and keeps valid ones; never crashes on garbage types.
    func testMalformedEntriesAreSkipped() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": [
                "pages": [
                    ["duration": 3.0],
                    ["image": 12345],
                    ["image": "not a url with spaces"],
                    ["image": "https://example.com/ok.jpg"]
                ]
            ]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].imageURL, URL(string: "https://example.com/ok.jpg"))
    }

    /// A pw_stories value of the wrong shape returns empty rather than crashing.
    func testGarbageBlockShapeReturnsEmpty() {
        XCTAssertTrue(StoryPayloadParser.parse(userInfo: ["pw_stories": "garbage"]).isEmpty)
        XCTAssertTrue(StoryPayloadParser.parse(userInfo: ["pw_stories": ["pages": "nope"]]).isEmpty)
    }

    /// An integer duration (as server-side APNs JSON emits) is bridged via NSNumber to a TimeInterval.
    func testIntegerDurationParsed() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": ["pages": [["image": "https://example.com/1.jpg", "duration": 5]]]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].duration, 5.0)
    }

    /// A link without a URL scheme is treated as absent (otherwise it shows a CTA that can't open).
    func testSchemelessLinkIsDropped() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": [
                "pages": [
                    ["image": "https://example.com/1.jpg", "link": "example.com/sale", "button_title": "Buy"],
                    ["image": "https://example.com/2.jpg", "link": "myapp://sale", "button_title": "Buy"]
                ]
            ]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertNil(pages[0].link)
        XCTAssertEqual(pages[1].link, URL(string: "myapp://sale"))
    }

    /// Maps the optional per-frame title and subtitle; empty strings are treated as absent.
    func testParsesTitleAndSubtitle() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": [
                "pages": [
                    ["image": "https://example.com/1.jpg",
                     "title": "Summer Sale",
                     "subtitle": "Up to 70% off"],
                    ["image": "https://example.com/2.jpg",
                     "title": "",
                     "subtitle": ""]
                ]
            ]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages[0].title, "Summer Sale")
        XCTAssertEqual(pages[0].subtitle, "Up to 70% off")
        XCTAssertNil(pages[1].title)
        XCTAssertNil(pages[1].subtitle)
    }

    /// A zero or negative duration falls back to the default rather than producing a non-advancing page.
    func testNonPositiveDurationFallsBackToDefault() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": ["pages": [["image": "https://example.com/1.jpg", "duration": 0]]]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].duration, StoryPage.defaultDuration)
    }

    /// An absurdly large duration is clamped to a sane maximum so the page still auto-advances.
    func testHugeDurationIsClamped() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": ["pages": [["image": "https://example.com/1.jpg", "duration": 1e308]]]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].duration, StoryPage.maxDuration)
    }

    /// Parses pw_stories delivered via the `data` API field — arriving as a JSON-encoded `u` string.
    func testParsesFromCustomDataJSONString() {
        let userInfo: [AnyHashable: Any] = [
            "u": "{\"pw_stories\":{\"pages\":[{\"image\":\"https://example.com/1.jpg\",\"duration\":3}]}}"
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].imageURL, URL(string: "https://example.com/1.jpg"))
        XCTAssertEqual(pages[0].duration, 3.0)
    }

    /// Parses pw_stories nested inside a `u` dictionary (custom data delivered as an object).
    func testParsesFromCustomDataDictionary() {
        let userInfo: [AnyHashable: Any] = [
            "u": ["pw_stories": ["pages": [["image": "https://example.com/2.jpg"]]]]
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].imageURL, URL(string: "https://example.com/2.jpg"))
    }

    /// The root `pw_stories` block still takes precedence (legacy ios_root_params delivery).
    func testRootBlockTakesPrecedenceOverCustomData() {
        let userInfo: [AnyHashable: Any] = [
            "pw_stories": ["pages": [["image": "https://example.com/root.jpg"]]],
            "u": "{\"pw_stories\":{\"pages\":[{\"image\":\"https://example.com/u.jpg\"}]}}"
        ]
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].imageURL, URL(string: "https://example.com/root.jpg"))
    }
}
