//
//  PWTVOSHTMLParserTests.swift
//  PushwooshTVOSTests
//
//  Created by André Kis on 22.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshTVOS

@available(tvOS 11.0, *)
final class PWTVOSHTMLParserTests: XCTestCase {

    var parser: PWTVOSHTMLParser!

    override func setUp() {
        super.setUp()
        parser = PWTVOSHTMLParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testStripHTMLRemovesTags() {
        let html = "<p>Hello <strong>World</strong></p>"
        let result = parser.stripHTML(html)
        XCTAssertEqual(result, "Hello World")
    }

    func testStripHTMLDecodesEntities() {
        let html = "Hello&nbsp;World&amp;Test&lt;&gt;&quot;"
        let result = parser.stripHTML(html)
        XCTAssertEqual(result, "Hello World&Test<>\"")
    }

    func testStripHTMLHandlesEmptyString() {
        let html = ""
        let result = parser.stripHTML(html)
        XCTAssertEqual(result, "")
    }

    func testStripHTMLHandlesNoTags() {
        let html = "Plain text"
        let result = parser.stripHTML(html)
        XCTAssertEqual(result, "Plain text")
    }

    func testParseHTMLWithSimpleHeading() {
        let html = """
        <div id="u_content_heading_1">
            <h1 style="color: #000000; font-size: 24px;">Test Heading</h1>
        </div>
        """
        let elements = parser.parseHTML(html, localization: nil)
        XCTAssertFalse(elements.isEmpty)
    }

    func testParseHTMLWithImage() {
        let html = """
        <div id="u_content_image_1">
            <img src="https://example.com/image.png" style="border-radius: 10px;">
        </div>
        """
        let elements = parser.parseHTML(html, localization: nil)
        XCTAssertFalse(elements.isEmpty)
    }

    func testParseHTMLWithButton() {
        let html = """
        <div id="u_content_button_1">
            <a style="background-color: #3498db; color: #ffffff;">Click Me</a>
        </div>
        """
        let elements = parser.parseHTML(html, localization: nil)
        XCTAssertFalse(elements.isEmpty)
    }

    func testParseHTMLWithEmptyContent() {
        let html = ""
        let elements = parser.parseHTML(html, localization: nil)
        XCTAssertTrue(elements.isEmpty)
    }

    func testProcessPlaceholders() {
        let html = "Hello {{name|text|World}}"
        let localization = ["name": "User"]
        let elements = parser.parseHTML(html, localization: localization)
        XCTAssertTrue(elements.isEmpty)
    }

    func testProcessPlaceholdersWithDefault() {
        let html = "<div id=\"u_content_text_1\">{{greeting|text|Hello}}</div>"
        let elements = parser.parseHTML(html, localization: nil)
        XCTAssertFalse(elements.isEmpty)
    }
}
