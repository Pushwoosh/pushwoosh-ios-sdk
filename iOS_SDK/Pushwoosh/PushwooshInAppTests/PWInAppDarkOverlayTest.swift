//
//  PWInAppDarkOverlayTest.swift
//  PushwooshTests
//
//  Created by André Kis on 08.09.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWInAppDarkOverlayTest: XCTestCase {

    private let button: [AnyHashable: Any] = [
        "text": ["text": "Shop", "color": "#FFFFFFFF"],
        "background": "#0E72E5FF",
        "border": ["color": "#00FF00FF", "radius": 12],
        "action": ["type": "url", "url": "app://shop"]
    ]

    private func modal(dark: Any? = nil,
                       _ mutate: (inout [AnyHashable: Any]) -> Void = { _ in }) -> [AnyHashable: Any] {
        var block: [AnyHashable: Any] = ["showClose": true,
                                         "dimBackground": true,
                                         "background": "#FFFFFFFF",
                                         "title": ["text": "Hi", "color": "#111111FF"],
                                         "buttons": [button]]
        if let dark = dark { block["dark"] = dark }
        mutate(&block)
        return ["displayType": "modal", "modal": block]
    }

    private func mergedBlock(_ config: [AnyHashable: Any], _ key: String = "modal") -> [AnyHashable: Any]? {
        guard case .merged(let merged) = PWInAppDarkOverlay.apply(to: config) else { return nil }
        return merged[key] as? [AnyHashable: Any]
    }

    private func assertBroken(_ config: [AnyHashable: Any], _ note: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard case .broken = PWInAppDarkOverlay.apply(to: config) else {
            return XCTFail("expected .broken: \(note)", file: file, line: line)
        }
    }

    /// Verifies that a config without a dark key yields .none.
    func testNoDarkKeyReturnsNone() {
        guard case .none = PWInAppDarkOverlay.apply(to: modal()) else {
            return XCTFail("no dark key must yield .none")
        }
    }

    /// Verifies that an explicit JSON null dark is treated as absent.
    func testExplicitNullDarkReturnsNone() {
        guard case .none = PWInAppDarkOverlay.apply(to: modal(dark: NSNull())) else {
            return XCTFail("null dark must yield .none")
        }
    }

    /// Verifies that a config the light parser would reject anyway (unknown displayType, missing block) yields .none, not .broken.
    func testUnknownDisplayTypeOrMissingBlockReturnsNone() {
        guard case .none = PWInAppDarkOverlay.apply(to: ["displayType": "hologram"]) else {
            return XCTFail("unknown displayType must yield .none")
        }
        guard case .none = PWInAppDarkOverlay.apply(to: ["displayType": "modal"]) else {
            return XCTFail("missing block must yield .none")
        }
    }

    /// Verifies that a non-object dark (string, number, array) is broken as a whole.
    func testNonObjectDarkIsBroken() {
        assertBroken(modal(dark: "night"), "string dark")
        assertBroken(modal(dark: 1), "number dark")
        assertBroken(modal(dark: [["background": "#000000FF"]]), "array dark")
    }

    /// Verifies that keys whose light value is a color are overridden and inherited otherwise.
    func testColorKeysAreOverridden() {
        let config = modal(dark: ["background": "#101014FF", "title": ["color": "#EEEEEEFF"]])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual(block["background"] as? String, "#101014FF")
        let title = block["title"] as? [AnyHashable: Any]
        XCTAssertEqual(title?["color"] as? String, "#EEEEEEFF")
        XCTAssertEqual(title?["text"] as? String, "Hi", "text must be inherited from light")
    }

    /// Verifies that non-visual keys inside dark (texts, flags, enums, action) are silently ignored.
    func testNonVisualKeysAreIgnored() {
        let config = modal(dark: ["title": ["text": "Night"],
                                  "showClose": false,
                                  "dimBackground": false,
                                  "futureFlag": "x"])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual((block["title"] as? [AnyHashable: Any])?["text"] as? String, "Hi")
        XCTAssertEqual(block["showClose"] as? Bool, true)
        XCTAssertEqual(block["dimBackground"] as? Bool, true)
    }

    /// Verifies that media keys are overridden by name even when absent in the light block.
    func testMediaKeyOverridesEvenWhenAbsentInLight() {
        let config = modal(dark: ["image": "https://x.co/hero-dark.png"])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual(block["image"] as? String, "https://x.co/hero-dark.png")
    }

    /// Verifies positional button merge: visual keys replaced, text and action inherited per element.
    func testButtonsArrayMergesPositionally() {
        let darkButton: [AnyHashable: Any] = ["background": "#222222FF",
                                              "border": ["color": "#333333FF"],
                                              "text": ["text": "DARK", "color": "#000000FF"],
                                              "action": ["type": "url", "url": "app://dark"]]
        let config = modal(dark: ["buttons": [darkButton]])
        guard let block = mergedBlock(config),
              let merged = (block["buttons"] as? [[AnyHashable: Any]])?.first else {
            return XCTFail("must merge")
        }
        XCTAssertEqual(merged["background"] as? String, "#222222FF")
        XCTAssertEqual((merged["border"] as? [AnyHashable: Any])?["color"] as? String, "#333333FF")
        XCTAssertEqual((merged["border"] as? [AnyHashable: Any])?["radius"] as? Int, 12)
        let text = merged["text"] as? [AnyHashable: Any]
        XCTAssertEqual(text?["text"] as? String, "Shop", "button text must stay light")
        XCTAssertEqual(text?["color"] as? String, "#000000FF", "button text color must go dark")
        XCTAssertEqual((merged["action"] as? [AnyHashable: Any])?["url"] as? String, "app://shop",
                       "action must stay light")
    }

    /// Verifies that an array length mismatch, a non-object array, or a missing light array breaks the whole dark overlay.
    func testBadArraysAreBroken() {
        assertBroken(modal(dark: ["buttons": [[AnyHashable: Any](), [AnyHashable: Any]()]]), "length 2 vs 1")
        assertBroken(modal(dark: ["buttons": [[AnyHashable: Any]]()]), "length 0 vs 1")
        assertBroken(modal(dark: ["buttons": "none"]), "non-array buttons")
        assertBroken(modal(dark: ["buttons": [1]]), "array of non-objects")
        assertBroken(modal(dark: ["buttons": [[AnyHashable: Any]()]]) { $0["buttons"] = nil }, "dark buttons without light buttons")
        assertBroken(modal(dark: ["buttons": [[AnyHashable: Any]()]]) { $0["buttons"] = "none" }, "light buttons is not an array")
    }

    /// Verifies that arrays under keys other than buttons/items are ignored, neither merged nor treated as damage (Android parity: POSITIONAL_ARRAY_KEYS).
    func testArraysOutsideButtonsAndItemsAreIgnored() {
        let lightSlides: [[AnyHashable: Any]] = [["color": "#111111FF"]]
        let config = modal(dark: ["slides": [["color": "#000000FF"], ["color": "#000000FF"]]]) {
            $0["slides"] = lightSlides
        }
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual((block["slides"] as? [[AnyHashable: Any]])?.count, 1)
        XCTAssertEqual((block["slides"] as? [[AnyHashable: Any]])?.first?["color"] as? String, "#111111FF")
    }

    /// Verifies that a gradient background is atomic: replaced wholesale, no positional length rule.
    func testGradientBackgroundIsAtomic() {
        let scratch: [AnyHashable: Any] = [
            "displayType": "scratchcard",
            "scratchcard": ["showClose": true,
                            "background": ["#3A1C71FF", "#B3227CFF"],
                            "revealThreshold": 0.55,
                            "cover": ["background": "#C9CDD6FF"],
                            "reward": ["title": ["text": "20% off", "color": "#111111FF"]],
                            "dark": ["background": ["#000000FF", "#111111FF", "#222222FF"]]]
        ]
        guard let block = mergedBlock(scratch, "scratchcard") else { return XCTFail("must merge") }
        XCTAssertEqual(block["background"] as? [String], ["#000000FF", "#111111FF", "#222222FF"])
    }

    /// Verifies that cover merges recursively: background overridden, image inherited.
    func testCoverMergesRecursively() {
        let fullscreen: [AnyHashable: Any] = [
            "displayType": "fullscreen",
            "fullscreen": ["showClose": true,
                           "cover": ["image": "https://x.co/hero.jpg", "background": "#1A1A1EFF"],
                           "buttons": [[AnyHashable: Any]](),
                           "dark": ["cover": ["background": "#000000FF"]]]
        ]
        guard let block = mergedBlock(fullscreen, "fullscreen"),
              let cover = block["cover"] as? [AnyHashable: Any] else {
            return XCTFail("must merge")
        }
        XCTAssertEqual(cover["background"] as? String, "#000000FF")
        XCTAssertEqual(cover["image"] as? String, "https://x.co/hero.jpg")
    }

    /// Verifies that keys outside the visual allowlist are ignored even when both sides hold hex-looking strings (Android parity: keys by name, not by value).
    func testNonAllowlistedHexLookingKeysAreIgnored() {
        let config = modal(dark: ["title": ["text": "#CAFE", "color": "#F2F2F7FF"]]) {
            $0["title"] = ["text": "#BEEF", "color": "#111111FF"]
        }
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        let title = block["title"] as? [AnyHashable: Any]
        XCTAssertEqual(title?["text"] as? String, "#BEEF")
        XCTAssertEqual(title?["color"] as? String, "#F2F2F7FF")
    }

    /// Verifies that an invalid leaf value is copied through for the strict parser to reject, which then falls back to light (Android parity).
    func testInvalidLeafValueIsCopiedThroughForStrictParserToReject() {
        let config = modal(dark: ["background": "#GGGGGG"])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual(block["background"] as? String, "#GGGGGG")
        XCTAssertNotNil(parsedModal(config, isDark: true), "strict parser rejects the merged block and the light variant is shown")
    }

    /// Verifies that JSON null inside dark never deletes or blanks a light value (Android parity).
    func testNullValuesInDarkCannotDeleteKeys() {
        let config = modal(dark: ["image": NSNull(), "background": NSNull(), "title": ["color": "#F2F2F7FF"]]) {
            $0["image"] = "https://x.co/light.png"
        }
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual(block["image"] as? String, "https://x.co/light.png")
        XCTAssertEqual(block["background"] as? String, "#FFFFFFFF")
        XCTAssertEqual((block["title"] as? [AnyHashable: Any])?["color"] as? String, "#F2F2F7FF")
    }

    /// Verifies that a null array in dark is ignored instead of breaking the overlay (Android parity).
    func testNullArrayInDarkIsIgnored() {
        let config = modal(dark: ["buttons": NSNull(), "background": "#101014FF"])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual((block["buttons"] as? [[AnyHashable: Any]])?.count, 1)
        XCTAssertEqual(block["background"] as? String, "#101014FF")
    }

    /// Verifies that a scalar in dark over an object in light is ignored while sibling leaves still merge (Android parity).
    func testScalarInDarkOverObjectInLightIsIgnored() {
        let config = modal(dark: ["title": "#FFF", "background": "#101014FF"])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual(block["background"] as? String, "#101014FF")
        let title = block["title"] as? [AnyHashable: Any]
        XCTAssertEqual(title?["text"] as? String, "Hi")
        XCTAssertEqual(title?["color"] as? String, "#111111FF")
    }



    /// Verifies that a nested dark inside dark is ignored and the dark key is stripped from the merged block.
    func testNestedDarkIsIgnoredAndDarkKeyStripped() {
        let config = modal(dark: ["background": "#101014FF",
                                  "dark": ["background": "#FF0000FF"]])
        guard let block = mergedBlock(config) else { return XCTFail("must merge") }
        XCTAssertEqual(block["background"] as? String, "#101014FF")
        XCTAssertNil(block["dark"], "merged block must not carry the dark key")
    }

    // MARK: - parse(_:isDark:) integration

    private func darkModal() -> [AnyHashable: Any] {
        modal(dark: ["background": "#101014FF",
                     "title": ["color": "#FFFFFFFF"],
                     "image": "https://x.co/hero-dark.png",
                     "buttons": [["background": "#222222FF"]]])
    }

    private func parsedModal(_ config: [AnyHashable: Any], isDark: Bool) -> PWInAppModalContent? {
        guard case .modal(let content)? = PWInAppConfigParser.parse(config, isDark: isDark)?.layout else {
            return nil
        }
        return content
    }

    /// Verifies that in dark theme every overridden color and media key comes from the overlay while content stays light.
    func testFullDarkOverlayAppliesToParsedModel() {
        guard let content = parsedModal(darkModal(), isDark: true) else {
            return XCTFail("dark modal must parse")
        }
        XCTAssertEqual(content.backgroundColor, UIColor.pw_fromHex("#101014FF"))
        XCTAssertEqual(content.title?.color, UIColor.pw_fromHex("#FFFFFFFF"))
        XCTAssertEqual(content.title?.text, "Hi")
        XCTAssertEqual(content.imageURL?.absoluteString, "https://x.co/hero-dark.png")
        XCTAssertEqual(content.buttons[0].backgroundColor, UIColor.pw_fromHex("#222222FF"))
        XCTAssertEqual(content.buttons[0].text.text, "Shop")
        guard case .url(let url) = content.buttons[0].action else {
            return XCTFail("action must stay light")
        }
        XCTAssertEqual(url.absoluteString, "app://shop")
    }

    /// Verifies that a sparse overlay overrides only its own keys and inherits the rest.
    func testSparseDarkInheritsLightValues() {
        let config = modal(dark: ["background": "#101014FF"])
        guard let content = parsedModal(config, isDark: true) else {
            return XCTFail("sparse dark modal must parse")
        }
        XCTAssertEqual(content.backgroundColor, UIColor.pw_fromHex("#101014FF"))
        XCTAssertEqual(content.title?.color, UIColor.pw_fromHex("#111111FF"))
    }

    /// Verifies that a dark theme without a dark overlay shows the light variant.
    func testNoDarkKeyWithDarkThemeShowsLight() {
        guard let content = parsedModal(modal(), isDark: true) else {
            return XCTFail("light-only modal must parse in dark theme")
        }
        XCTAssertEqual(content.backgroundColor, UIColor.pw_fromHex("#FFFFFFFF"))
    }

    /// Verifies that in light theme the overlay is not applied at all.
    func testDarkPresentButLightThemeShowsLight() {
        guard let content = parsedModal(darkModal(), isDark: false) else {
            return XCTFail("modal must parse in light theme")
        }
        XCTAssertEqual(content.backgroundColor, UIColor.pw_fromHex("#FFFFFFFF"))
        XCTAssertNil(content.imageURL)
    }

    /// Verifies that every broken-dark variant falls back to the light variant — the message is still shown.
    func testBrokenDarkFallsBackToLight() {
        let brokenVariants: [(Any, String)] = [
            ("night", "non-object dark"),
            (["background": "#GGGGGG"], "bad hex"),
            (["image": 123], "non-string media"),
            (["image": ""], "empty media URL"),
            (["buttons": [[AnyHashable: Any](), [AnyHashable: Any]()]], "array length mismatch")
        ]
        for (dark, note) in brokenVariants {
            guard let content = parsedModal(modal(dark: dark), isDark: true) else {
                return XCTFail("broken dark (\(note)) must fall back to light, not drop the message")
            }
            XCTAssertEqual(content.backgroundColor, UIColor.pw_fromHex("#FFFFFFFF"), note)
        }
    }

    /// Verifies that unknown keys next to dark are still ignored (forward-compat is untouched).
    func testUnknownKeysNextToDarkStillIgnored() {
        var config = modal(dark: ["background": "#101014FF"]) { block in
            block["futureFlag"] = true
        }
        config["experiment"] = "A"
        guard let content = parsedModal(config, isDark: true) else {
            return XCTFail("unknown keys must stay ignored")
        }
        XCTAssertEqual(content.backgroundColor, UIColor.pw_fromHex("#101014FF"))
    }
}
#endif
