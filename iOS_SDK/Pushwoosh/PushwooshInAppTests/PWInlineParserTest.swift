//
//  PWInlineParserTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWInlineParserTest: XCTestCase {

    private func banner(_ root: Any, extra: [String: Any] = [:]) -> [String: Any] {
        var banner: [String: Any] = ["bannerId": "promo-1", "version": 3, "format": "native", "native": ["root": root]]
        banner.merge(extra) { _, new in new }
        return banner
    }

    private func text(_ value: String) -> [String: Any] {
        ["type": "text", "text": value]
    }

    private func parse(_ raw: Any?) -> PWInlineBanner? {
        PWInlineParser.banner(from: raw, slotId: "home_top", receivedAt: Date())
    }

    private func nativeChildren(_ banner: PWInlineBanner) -> [PWInlineNode] {
        guard case .native(let root) = banner.content, case .stack(let stack) = root.kind else {
            return []
        }
        return stack.children
    }

    /// Verifies that a native banner built from every node and style key is accepted with its envelope fields.
    func testParsesNativeBannerWithEveryNodeAndStyle() throws {
        let root: [String: Any] = [
            "type": "stack", "axis": "column", "spacing": 8, "align": "fill",
            "padding": [12, 16], "background": "#FFF4E5", "cornerRadius": 16,
            "children": [
                ["type": "text", "text": "Flash sale", "color": "#D92D20", "size": 20, "weight": "bold",
                 "align": "center", "lines": 2],
                ["type": "image", "url": "https://example.com/banner.png", "aspect": 2, "cornerRadius": 8],
                ["type": "stack", "axis": "row", "distribution": "equal", "children": [
                    ["type": "button", "title": "Shop now", "color": "#FFFFFF", "background": "#D92D20",
                     "padding": [8, 12, 8, 12], "action": ["type": "deeplink", "value": "pushmart://deals"]],
                    text("Ends tonight"),
                ]],
            ],
        ]

        let parsed = try XCTUnwrap(parse(banner(root, extra: ["maxHeight": 320, "expireDate": 4102444800])))

        XCTAssertEqual(parsed.slotId, "home_top")
        XCTAssertEqual(parsed.bannerId, "promo-1")
        XCTAssertEqual(parsed.version, 3)
        XCTAssertEqual(parsed.maxHeight, 320)
        XCTAssertEqual(parsed.expireDate, Date(timeIntervalSince1970: 4102444800))
        guard case .native(let parsedRoot) = parsed.content, case .stack(let stack) = parsedRoot.kind else {
            return XCTFail("root must be a native stack")
        }
        XCTAssertEqual(stack.children.count, 3)
        XCTAssertEqual(parsedRoot.style.padding, UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        XCTAssertEqual(parsedRoot.style.cornerRadius, 16)
        XCTAssertNotNil(parsedRoot.style.background)
    }

    /// Verifies that a slot the server left empty gives no banner.
    func testEmptySlotGivesNoBanner() {
        XCTAssertNil(parse(nil))
        XCTAssertNil(parse(NSNull()))
    }

    /// Verifies that a banner without bannerId, a non-negative integer version, a known format or native content is dropped.
    func testMissingRequiredBannerFieldsDropBanner() {
        let root = text("Hi")
        let candidates: [[String: Any]] = [
            ["version": 1, "format": "native", "native": ["root": root]],
            ["bannerId": "", "version": 1, "format": "native", "native": ["root": root]],
            ["bannerId": "a", "format": "native", "native": ["root": root]],
            ["bannerId": "a", "version": -1, "format": "native", "native": ["root": root]],
            ["bannerId": "a", "version": "1", "format": "native", "native": ["root": root]],
            ["bannerId": "a", "version": 1, "native": ["root": root]],
            ["bannerId": "a", "version": 1, "format": "flash", "native": ["root": root]],
            ["bannerId": "a", "version": 1, "format": "native"],
            ["bannerId": "a", "version": 1, "format": "native", "native": root],
        ]

        for candidate in candidates {
            XCTAssertNil(parse(candidate), "\(candidate)")
        }
    }

    /// Verifies that the whole banner is dropped when any nested node is unknown or malformed.
    func testInvalidNodeDropsWholeBanner() {
        let broken: [[String: Any]] = [
            ["type": "stack", "children": [text("ok"), ["type": "marquee"]]],
            ["type": "stack", "children": []],
            ["type": "text"],
            ["type": "image"],
            ["type": "button", "title": "Go", "action": ["type": "url", "value": "ftp://example.com"]],
            ["type": "button", "title": "Go", "action": ["type": "deeplink", "url": "pushmart://deals"]],
            ["type": "button", "title": "Go", "action": ["value": "pushmart://deals"]],
            ["type": "text", "text": "x", "color": "red"],
            ["type": "text", "text": "x", "padding": "8"],
            ["type": "text", "text": "x", "size": true],
        ]

        for root in broken {
            XCTAssertNil(parse(banner(root)), "\(root)")
        }
    }

    /// Verifies that url and deeplink actions take their target from `value`.
    func testActionTargetComesFromValue() throws {
        let root: [String: Any] = ["type": "stack", "children": [
            ["type": "button", "title": "Open", "action": ["type": "url", "value": "https://example.com/sale"]],
            ["type": "button", "title": "Deals", "action": ["type": "deeplink", "value": "pushmart://deals"]],
        ]]

        let parsed = try XCTUnwrap(parse(banner(root)))

        let actions = nativeChildren(parsed).map(\.action)
        guard case .url(let url)? = actions[0], case .deeplink(let link)? = actions[1] else {
            return XCTFail("expected url and deeplink actions, got \(actions)")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/sale")
        XCTAssertEqual(link.absoluteString, "pushmart://deals")
    }

    /// Verifies that a link or image URL with a space or a non-ASCII character is encoded instead of dropping the banner.
    func testURLWithSpaceOrNonASCIIIsEncoded() throws {
        let root: [String: Any] = ["type": "stack", "children": [
            ["type": "image", "url": "https://example.com/summer sale.png"],
            ["type": "button", "title": "Open", "action": ["type": "url", "value": "https://example.com/café"]],
        ]]

        let parsed = try XCTUnwrap(parse(banner(root)))

        let children = nativeChildren(parsed)
        guard case .image(let image) = children[0].kind, case .url(let url)? = children[1].action else {
            return XCTFail("expected an image and a url action, got \(children)")
        }
        XCTAssertEqual(image.url.absoluteString, "https://example.com/summer%20sale.png")
        XCTAssertEqual(url.absoluteString, "https://example.com/caf%C3%A9")
    }

    /// Verifies that an action of an unknown type is ignored and the banner is still drawn.
    func testUnknownActionTypeIsIgnored() throws {
        let root: [String: Any] = ["type": "stack", "children": [
            ["type": "button", "title": "Go", "action": ["type": "teleport", "value": "mars"]],
        ]]

        let parsed = try XCTUnwrap(parse(banner(root, extra: ["action": ["type": "hologram"]])))

        XCTAssertNil(nativeChildren(parsed).first?.action)
        XCTAssertNil(parsed.action)
    }

    /// Verifies that the banner's own action is parsed and `close`, allowed only on nodes, is ignored there.
    func testBannerActionIsParsedAndCloseIsIgnored() throws {
        let tapped = try XCTUnwrap(parse(banner(text("Hi"), extra: [
            "action": ["type": "postEvent", "event": "BannerTapped", "attributes": ["slot": "home"]],
        ])))
        let closing = try XCTUnwrap(parse(banner(text("Hi"), extra: ["action": ["type": "close"]])))

        guard case .postEvent(let name, let attributes)? = tapped.action else {
            return XCTFail("expected a postEvent banner action, got \(String(describing: tapped.action))")
        }
        XCTAssertEqual(name, "BannerTapped")
        XCTAssertEqual(attributes["slot"] as? String, "home")
        XCTAssertNil(closing.action)
    }

    /// Verifies that an html banner keeps its document and is dropped without one.
    func testHTMLBannerKeepsDocument() throws {
        let document = "<html><body><p>Autumn sale</p></body></html>"
        let html: [String: Any] = ["bannerId": "story", "version": 1, "format": "html", "html": document]

        let parsed = try XCTUnwrap(parse(html))

        XCTAssertEqual(parsed.html, document)
        for broken in [["html": ""], ["html": NSNull()], ["html": 42]] as [[String: Any]] {
            XCTAssertNil(parse(html.merging(broken) { _, new in new }), "\(broken)")
        }
    }

    /// Verifies that keys the SDK does not know are ignored and the banner is still accepted.
    func testUnknownKeysAreIgnored() {
        XCTAssertNotNil(parse(banner(text("Hi"), extra: ["campaignColor": "teal", "priority": 2])))
    }

    /// Verifies that a banner holding non-JSON values is rejected instead of crashing later on persistence.
    func testNonJSONValueDropsBanner() {
        XCTAssertNil(parse(banner(["type": "text", "text": "x", "extra": Date()])))
    }

    /// Verifies that an image or video aspect outside 0.1...20 or not finite drops the banner.
    func testAspectOutsideRangeDropsBanner() {
        for type in ["image", "video"] {
            let node = { (aspect: Double) -> [String: Any] in
                ["type": type, "url": "https://example.com/media", "aspect": aspect]
            }
            for aspect in [1e-320, 0.05, 21, .infinity] {
                XCTAssertNil(parse(banner(node(aspect))), "\(type) aspect \(aspect)")
            }
            for aspect in [0.1, 1.5, 20] {
                XCTAssertNotNil(parse(banner(node(aspect))), "\(type) aspect \(aspect)")
            }
        }
    }

    /// Verifies that the renderer never builds a non-finite aspect multiplier.
    func testRendererKeepsAspectMultiplierFinite() {
        for aspect: CGFloat in [1e-320, 0, -1, 1000, .infinity, .nan] {
            XCTAssertTrue(PWInlineRenderer.aspectConstraint(UIView(), aspect).multiplier.isFinite, "aspect \(aspect)")
        }
    }

    /// Verifies that a pager interval under 1 s drops the banner.
    func testPagerIntervalUnderOneSecondDropsBanner() {
        let pager = { (interval: Double) -> [String: Any] in
            ["type": "pager", "pages": [self.text("a"), self.text("b")], "interval": interval]
        }

        XCTAssertNil(parse(banner(pager(0.001))))
        XCTAssertNil(parse(banner(pager(0.5))))
        XCTAssertNotNil(parse(banner(pager(1))))
        XCTAssertNotNil(parse(banner(pager(3))))
    }

    /// Verifies that every size, spacing, padding, radius, border, shadow and height past its limit drops the banner.
    func testLengthPastLimitDropsBanner() {
        let image: [String: Any] = ["type": "image", "url": "https://example.com/a.png"]
        let cases: [(String, (Double) -> [String: Any])] = [
            ("spacing", { self.banner(["type": "stack", "spacing": $0, "children": [self.text("a"), self.text("b")]]) }),
            ("overlay spacing", { self.banner(["type": "stack", "axis": "overlay", "spacing": $0,
                                               "children": [image, self.text("b").merging(["position": "topLeft"]) { $1 }]]) }),
            ("padding", { self.banner(self.text("a").merging(["padding": $0]) { $1 }) }),
            ("padding list", { self.banner(self.text("a").merging(["padding": [8, $0, 8, 8]]) { $1 }) }),
            ("cornerRadius", { self.banner(self.text("a").merging(["cornerRadius": $0]) { $1 }) }),
            ("border", { self.banner(self.text("a").merging(["border": ["width": $0, "color": "#000000"]]) { $1 }) }),
            ("shadow radius", { self.banner(self.text("a").merging(["shadow": ["radius": $0]]) { $1 }) }),
            ("shadow x", { self.banner(self.text("a").merging(["shadow": ["x": $0]]) { $1 }) }),
            ("shadow y", { self.banner(self.text("a").merging(["shadow": ["y": -$0]]) { $1 }) }),
            ("spacer", { self.banner(["type": "spacer", "size": $0]) }),
            ("divider", { self.banner(["type": "divider", "thickness": $0]) }),
            ("maxHeight", { self.banner(self.text("a"), extra: ["maxHeight": $0]) }),
            ("close cornerRadius", { self.banner(self.text("a"), extra: ["close": ["enabled": true, "cornerRadius": $0]]) }),
        ]
        for (field, make) in cases {
            for length in [9e307, 1e308, PWInlineParser.maxLength + 1] {
                XCTAssertNil(parse(make(length)), "\(field) \(length)")
            }
            XCTAssertNotNil(parse(make(PWInlineParser.maxLength)), field)
        }
        for size in [9e307, PWInlineParser.maxFontSize + 1] {
            XCTAssertNil(parse(banner(text("a").merging(["size": size]) { $1 })), "text size \(size)")
            XCTAssertNil(parse(banner(["type": "button", "title": "Go", "size": size])), "button size \(size)")
        }
        XCTAssertNotNil(parse(banner(text("a").merging(["size": PWInlineParser.maxFontSize]) { $1 })))
    }

    /// Verifies that a banner with every length at its limit lays out in a window without a non-finite constraint.
    func testLengthsAtLimitLayOut() throws {
        let limit = PWInlineParser.maxLength
        let parsed = try XCTUnwrap(parse(banner([
            "type": "stack", "spacing": limit, "padding": limit, "cornerRadius": limit,
            "border": ["width": limit, "color": "#000000"], "shadow": ["radius": limit, "x": limit, "y": -limit],
            "children": [
                ["type": "stack", "axis": "overlay", "spacing": limit,
                 "children": [["type": "spacer", "size": limit], text("b").merging(["position": "center"]) { $1 }]],
                ["type": "divider", "thickness": limit],
                ["type": "button", "title": "Go", "padding": [limit, limit], "size": PWInlineParser.maxFontSize],
                ["type": "stack", "axis": "row", "spacing": limit, "children": [text("c"), ["type": "spacer"], text("d")]],
            ],
        ], extra: ["maxHeight": limit, "close": ["enabled": true, "cornerRadius": limit]])))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let view = PWInlineRenderer(onSizeChange: {}, onAction: { _, _ in }, canPostEvent: { true }).makeView(parsed)
        view.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: window.topAnchor),
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            view.widthAnchor.constraint(equalToConstant: 390),
        ])

        window.layoutIfNeeded()

        XCTAssertTrue(view.frame.height.isFinite)
        XCTAssertGreaterThan(view.frame.height, limit)
    }
}
#endif
