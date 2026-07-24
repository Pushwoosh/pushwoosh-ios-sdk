//
//  PWInAppConfigParserTest.swift
//  PushwooshTests
//
//  Created by André Kis on 15.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWInAppConfigParserTest: XCTestCase {

    // MARK: - Canonical fixtures (contract examples)

    private let button: [AnyHashable: Any] = [
        "text": ["text": "Shop", "color": "#FFFFFFFF"],
        "background": "#0E72E5FF",
        "border": ["color": "#00FF00FF", "radius": 12],
        "action": ["type": "url", "url": "app://shop"]
    ]

    private let actionlessButton: [AnyHashable: Any] = [
        "text": ["text": "SPIN", "color": "#1B1B46FF"],
        "background": "#F2C94CFF",
        "border": ["color": "#D9A02BFF", "radius": 36]
    ]

    private let reward: [AnyHashable: Any] = [
        "title": ["text": "20% off", "color": "#111111FF"],
        "code": "APEX20"
    ]

    private func modal(_ mutate: (inout [AnyHashable: Any]) -> Void = { _ in }) -> [AnyHashable: Any] {
        var block: [AnyHashable: Any] = ["showClose": true,
                                         "dimBackground": true,
                                         "background": "#FFFFFFFF",
                                         "title": ["text": "Hi", "color": "#111111FF"],
                                         "buttons": [button]]
        mutate(&block)
        return ["displayType": "modal", "modal": block]
    }

    private func sheet(_ mutate: (inout [AnyHashable: Any]) -> Void = { _ in }) -> [AnyHashable: Any] {
        var block: [AnyHashable: Any] = ["showClose": true,
                                         "dimBackground": true,
                                         "background": "#FFFFFFFF",
                                         "title": ["text": "Hi", "color": "#111111FF"],
                                         "buttons": [button]]
        mutate(&block)
        return ["displayType": "sheet", "sheet": block]
    }

    private func stories(_ mutate: (inout [AnyHashable: Any]) -> Void = { _ in }) -> [AnyHashable: Any] {
        var block: [AnyHashable: Any] = ["showClose": true,
                                         "loop": false,
                                         "items": [["title": ["text": "Sale", "color": "#FFFFFFFF"],
                                                    "buttons": [button],
                                                    "duration": 4]]]
        mutate(&block)
        return ["displayType": "stories", "stories": block]
    }

    private func banner(_ mutate: (inout [AnyHashable: Any]) -> Void = { _ in }) -> [AnyHashable: Any] {
        var block: [AnyHashable: Any] = ["showClose": true,
                                         "position": "bottom",
                                         "background": "#4B5057FF",
                                         "action": ["type": "url", "url": "app://promo"]]
        mutate(&block)
        return ["displayType": "banner", "banner": block]
    }

    private func parsed(_ config: [AnyHashable: Any]) -> PWInAppMessageModel? {
        PWInAppConfigParser.parse(config)
    }

    // MARK: - Root / displayType

    /// Verifies that a config without displayType is rejected.
    func testRejectsConfigWithoutDisplayType() {
        XCTAssertNil(parsed(["modal": ["showClose": true]]))
    }

    /// Verifies that unknown display types and removed aliases are rejected, matching Android's case-insensitive `displayType`.
    func testRejectsUnknownAndAliasDisplayTypes() {
        XCTAssertNil(parsed(["displayType": "hologram"]))
        XCTAssertNil(parsed(["displayType": "interstitial", "fullscreen": [:]]))
        XCTAssertNil(parsed(["displayType": "header", "banner": [:]]))
        XCTAssertNotNil(parsed(modal().merging(["displayType": "MODAL"]) { _, new in new }))
    }

    /// Verifies that a missing same-name block invalidates the config.
    func testRejectsMissingBlock() {
        XCTAssertNil(parsed(["displayType": "modal"]))
        XCTAssertNil(parsed(["displayType": "modal", "modal": "not-an-object"]))
    }

    /// Verifies that unknown keys are ignored on every level (forward-compat).
    func testUnknownKeysAreIgnored() {
        let config = modal { block in
            block["futureFlag"] = true
            var futureButton = self.button
            futureButton["haptics"] = "heavy"
            block["buttons"] = [futureButton]
        }.merging(["experiment": "A"]) { _, new in new }
        XCTAssertNotNil(parsed(config))
    }

    // MARK: - Modal / strictness

    /// Verifies that the canonical modal parses with every field mapped.
    func testModalParsesCanonicalConfig() {
        guard case .modal(let content)? = parsed(modal())?.layout else {
            return XCTFail("canonical modal must parse")
        }
        XCTAssertTrue(content.showCloseButton)
        XCTAssertTrue(content.dimsBackground)
        XCTAssertEqual(content.title?.text, "Hi")
        XCTAssertNotNil(content.title?.color)
        XCTAssertEqual(content.buttons.count, 1)
        XCTAssertEqual(content.buttons[0].text.text, "Shop")
        XCTAssertEqual(content.buttons[0].cornerRadius, 12)
        guard case .url(let url) = content.buttons[0].action else {
            return XCTFail("button action must be url")
        }
        XCTAssertEqual(url.absoluteString, "app://shop")
    }

    /// Verifies that each missing required modal field invalidates the whole config.
    func testMissingRequiredModalFieldInvalidatesConfig() {
        for key in ["showClose", "dimBackground", "background", "buttons"] {
            let config = modal { $0[key] = nil }
            XCTAssertNil(parsed(config), "modal without \(key) must be invalid")
        }
    }

    /// Verifies that a modal with only required fields (no visible content) is still valid, mirroring the preview.
    func testEmptyContentModalIsValid() {
        let config = modal { block in
            block["title"] = nil
            block["buttons"] = [[AnyHashable: Any]]()
        }
        XCTAssertNotNil(parsed(config))
    }

    /// Verifies that an empty string in a required text field invalidates the whole config (fail-closed, Android parity) instead of rendering an empty label.
    func testEmptyRequiredTextInvalidatesConfig() {
        XCTAssertNil(parsed(modal { $0["title"] = ["text": "", "color": "#111111FF"] }),
                     "empty title text must invalidate the config")
        XCTAssertNil(parsed(modal { block in
            var emptyButton = button
            emptyButton["text"] = ["text": "", "color": "#FFFFFFFF"]
            block["buttons"] = [emptyButton]
        }), "empty button text must invalidate the config")
    }

    /// Verifies an unparseable optional image URL leaves the asset empty instead of dropping the config (Android parity), while a required media URL still fails.
    func testUnparseableImageUrlKeepsConfigButRequiredMediaStillFails() {
        guard case .modal(let content)? = parsed(modal { $0["image"] = "http://a b.com" })?.layout else {
            return XCTFail("an unparseable image URL must not invalidate the modal")
        }
        XCTAssertNil(content.imageURL, "unparseable image URL resolves to nil, not a parse failure")

        let video: [AnyHashable: Any] = ["displayType": "video",
                                         "video": ["showClose": true, "loop": true, "muted": true,
                                                   "url": "http://a b.com", "buttons": [button]]]
        XCTAssertNil(parsed(video), "an unparseable required video url must still invalidate the config")
    }

    /// Verifies sheet parses its canonical config and is invalidated when a required field is missing (fail-closed like modal).
    func testSheetRules() {
        guard case .sheet? = parsed(sheet())?.layout else {
            return XCTFail("canonical sheet must parse")
        }
        for key in ["showClose", "dimBackground", "background", "buttons"] {
            XCTAssertNil(parsed(sheet { $0[key] = nil }), "sheet without \(key) must be invalid")
        }
    }

    // MARK: - Coercions rejected

    /// Verifies that stringified booleans and numbers are rejected instead of coerced.
    func testCoercionsAreRejected() {
        XCTAssertNil(parsed(modal { $0["showClose"] = "true" }))
        XCTAssertNil(parsed(modal { $0["showClose"] = 1 }))
        XCTAssertNil(parsed(stories { block in
            var item = (block["items"] as! [[AnyHashable: Any]])[0]
            item["duration"] = "5"
            block["items"] = [item]
        }))
        XCTAssertNil(parsed(modal { $0["background"] = 123 }))
    }

    // MARK: - Colors

    /// Verifies that the four CSS hex forms are accepted and everything else is invalid.
    func testColorForms() {
        for valid in ["#FFF", "#FFFA", "#FFFFFF", "#FFFFFFAA"] {
            XCTAssertNotNil(parsed(modal { $0["background"] = valid }), "\(valid) must be valid")
        }
        for invalid in ["FFFFFF", "#GGGGGG", "#FFFFF", "", "#"] {
            XCTAssertNil(parsed(modal { $0["background"] = invalid }), "\(invalid) must be invalid")
        }
    }

    // MARK: - Text

    /// Verifies that Text must be an object with both text and color.
    func testTextRequiresObjectWithColor() {
        XCTAssertNil(parsed(modal { $0["title"] = "plain string" }))
        XCTAssertNil(parsed(modal { $0["title"] = ["text": "Hi"] }))
        XCTAssertNil(parsed(modal { $0["title"] = ["color": "#111111FF"] }))
        XCTAssertNotNil(parsed(modal { $0["title"] = nil }))
    }

    // MARK: - Button

    /// Verifies that every button field is required and a broken button invalidates the config.
    func testButtonRequiresAllFields() {
        for key in ["text", "background", "border", "action"] {
            var broken = button
            broken[key] = nil
            XCTAssertNil(parsed(modal { $0["buttons"] = [broken] }), "button without \(key) must be invalid")
        }
        var badBorder = button
        badBorder["border"] = ["color": "#00FF00FF"]
        XCTAssertNil(parsed(modal { $0["buttons"] = [badBorder] }))

        var infRadiusBorder = button
        infRadiusBorder["border"] = ["color": "#00FF00FF", "radius": Double.infinity]
        XCTAssertNil(parsed(modal { $0["buttons"] = [infRadiusBorder] }), "non-finite button border.radius must be invalid")
    }

    // MARK: - Action

    /// Verifies strict action parsing: `type` is case-insensitive (matching Android), url required and non-empty for url actions.
    func testActionStrictness() {
        var uppercase = button
        uppercase["action"] = ["type": "URL", "url": "https://x.co"]
        guard case .modal(let uppercaseContent)? = parsed(modal { $0["buttons"] = [uppercase] })?.layout,
              case .url = uppercaseContent.buttons[0].action else {
            return XCTFail("uppercase url action type must parse")
        }

        var unknown = button
        unknown["action"] = ["type": "deeplink"]
        XCTAssertNil(parsed(modal { $0["buttons"] = [unknown] }))

        var emptyURL = button
        emptyURL["action"] = ["type": "url", "url": ""]
        XCTAssertNil(parsed(modal { $0["buttons"] = [emptyURL] }))

        var close = button
        close["action"] = ["type": "close"]
        guard case .modal(let content)? = parsed(modal { $0["buttons"] = [close] })?.layout,
              case .close = content.buttons[0].action else {
            return XCTFail("close action must parse")
        }
    }

    // MARK: - Carousel

    /// Verifies that carousel requires a non-empty items array and keeps items without visible content.
    func testCarouselItemsRules() {
        XCTAssertNil(parsed(["displayType": "carousel", "carousel": ["showClose": true, "items": [[AnyHashable: Any]]()]]))
        XCTAssertNil(parsed(["displayType": "carousel", "carousel": ["showClose": true]]))
        XCTAssertNil(parsed(["displayType": "carousel", "carousel": [["title": ["text": "Bare", "color": "#FFFFFFFF"]]]]))

        let empty: [AnyHashable: Any] = ["displayType": "carousel",
                                         "carousel": ["showClose": true, "items": [[AnyHashable: Any]()]]]
        guard case .carousel(let content)? = parsed(empty)?.layout else {
            return XCTFail("carousel with an empty item must parse (preview semantics)")
        }
        XCTAssertEqual(content.items.count, 1)
    }

    // MARK: - Stories

    /// Verifies canonical stories parsing, the required duration and the upper-only clamp.
    func testStoriesDurationRules() {
        guard case .stories(let content)? = parsed(stories())?.layout else {
            return XCTFail("canonical stories must parse")
        }
        XCTAssertEqual(content.items[0].duration, 4)
        XCTAssertEqual(content.items[0].buttons.count, 1)

        XCTAssertNil(parsed(stories { block in
            var item = (block["items"] as! [[AnyHashable: Any]])[0]
            item["duration"] = nil
            block["items"] = [item]
        }))
        XCTAssertNil(parsed(stories { block in
            var item = (block["items"] as! [[AnyHashable: Any]])[0]
            item["duration"] = 0
            block["items"] = [item]
        }))

        func duration(_ value: Any) -> TimeInterval? {
            let config = stories { block in
                var item = (block["items"] as! [[AnyHashable: Any]])[0]
                item["duration"] = value
                block["items"] = [item]
            }
            guard case .stories(let content)? = parsed(config)?.layout else { return nil }
            return content.items[0].duration
        }
        XCTAssertEqual(duration(61), 30)
        XCTAssertEqual(duration(0.5), 0.5)
    }

    /// Verifies that stories require showClose, loop and per-item buttons keys.
    func testStoriesRequiredKeys() {
        XCTAssertNil(parsed(stories { $0["loop"] = nil }))
        XCTAssertNil(parsed(stories { $0["showClose"] = nil }))
        XCTAssertNil(parsed(stories { block in
            var item = (block["items"] as! [[AnyHashable: Any]])[0]
            item["buttons"] = nil
            block["items"] = [item]
        }))
    }

    // MARK: - Banner

    /// Verifies banner required fields, the position enum (case-insensitive, matching Android) and autoDismiss > 0 when present.
    func testBannerRules() {
        guard case .banner(let content)? = parsed(banner())?.layout else {
            return XCTFail("canonical banner must parse")
        }
        XCTAssertEqual(content.autoDismiss, 0)

        guard case .banner(let nullAuto)? = parsed(banner { $0["autoDismiss"] = NSNull() })?.layout else {
            return XCTFail("explicit null autoDismiss must fall back to default (0), not drop the config")
        }
        XCTAssertEqual(nullAuto.autoDismiss, 0)

        guard case .banner(let uppercasePosition)? = parsed(banner { $0["position"] = "TOP" })?.layout,
              case .top = uppercasePosition.position else {
            return XCTFail("uppercase position must parse as .top")
        }

        XCTAssertNil(parsed(banner { $0["position"] = "left" }))
        XCTAssertNil(parsed(banner { $0["position"] = nil }))
        XCTAssertNil(parsed(banner { $0["action"] = nil }))
        XCTAssertNil(parsed(banner { $0["background"] = nil }))
        XCTAssertNil(parsed(banner { $0["autoDismiss"] = 0 }))
        XCTAssertNil(parsed(banner { $0["autoDismiss"] = -3 }))

        guard case .banner(let timed)? = parsed(banner { $0["autoDismiss"] = 6 })?.layout else {
            return XCTFail("banner with autoDismiss must parse")
        }
        XCTAssertEqual(timed.autoDismiss, 6)
    }

    // MARK: - Fullscreen

    /// Verifies that fullscreen requires the cover block with a background color.
    func testFullscreenCoverRules() {
        let canonical: [AnyHashable: Any] = ["displayType": "fullscreen",
                                             "fullscreen": ["showClose": true,
                                                            "cover": ["image": "https://x.co/hero.jpg",
                                                                      "background": "#1A1A1EFF"],
                                                            "buttons": [[AnyHashable: Any]]()]]
        guard case .fullscreen(let content)? = parsed(canonical)?.layout else {
            return XCTFail("canonical fullscreen must parse")
        }
        XCTAssertEqual(content.imageURL?.absoluteString, "https://x.co/hero.jpg")

        XCTAssertNil(parsed(["displayType": "fullscreen",
                             "fullscreen": ["showClose": true, "buttons": [[AnyHashable: Any]]()]]))
        XCTAssertNil(parsed(["displayType": "fullscreen",
                             "fullscreen": ["showClose": true,
                                            "cover": ["image": "https://x.co/hero.jpg"],
                                            "buttons": [[AnyHashable: Any]]()]]))
    }

    // MARK: - Video

    /// Verifies that video requires url, playback flags and the buttons key.
    func testVideoRequiredKeys() {
        let canonical: [AnyHashable: Any] = ["displayType": "video",
                                             "video": ["showClose": true, "loop": true, "muted": true,
                                                       "url": "https://x.co/v.mp4",
                                                       "buttons": [button]]]
        guard case .video(let content)? = parsed(canonical)?.layout else {
            return XCTFail("canonical video must parse")
        }
        XCTAssertEqual(content.buttons.count, 1)

        for key in ["url", "loop", "muted", "showClose", "buttons"] {
            var block = canonical["video"] as! [AnyHashable: Any]
            block[key] = nil
            XCTAssertNil(parsed(["displayType": "video", "video": block]), "video without \(key) must be invalid")
        }
    }

    // MARK: - Pip

    /// Verifies pip's corner enum, required geometry and the borderRadius default.
    func testPipRules() {
        let canonical: [AnyHashable: Any] = ["displayType": "pip",
                                             "pip": ["showClose": true,
                                                     "position": "bottom-right",
                                                     "loop": true, "muted": true,
                                                     "url": "https://x.co/v.mp4",
                                                     "width": 40, "aspectRatio": 0.5625]]
        guard case .pip(let content)? = parsed(canonical)?.layout else {
            return XCTFail("canonical pip must parse")
        }
        XCTAssertEqual(content.widthFraction, 0.4, accuracy: 0.001)
        XCTAssertEqual(content.cornerRadius, 16)

        var block = canonical["pip"] as! [AnyHashable: Any]
        block["position"] = "topleft"
        XCTAssertNil(parsed(["displayType": "pip", "pip": block]))
        for key in ["width", "aspectRatio", "position"] {
            var broken = canonical["pip"] as! [AnyHashable: Any]
            broken[key] = nil
            XCTAssertNil(parsed(["displayType": "pip", "pip": broken]), "pip without \(key) must be invalid")
        }

        var radius = canonical["pip"] as! [AnyHashable: Any]
        radius["borderRadius"] = 9
        guard case .pip(let rounded)? = parsed(["displayType": "pip", "pip": radius])?.layout else {
            return XCTFail("pip with borderRadius must parse")
        }
        XCTAssertEqual(rounded.cornerRadius, 9)

        var nullRadius = canonical["pip"] as! [AnyHashable: Any]
        nullRadius["borderRadius"] = NSNull()
        guard case .pip(let nulled)? = parsed(["displayType": "pip", "pip": nullRadius])?.layout else {
            return XCTFail("explicit null borderRadius must fall back to default (16), not drop the config")
        }
        XCTAssertEqual(nulled.cornerRadius, 16)

        var upperPos = canonical["pip"] as! [AnyHashable: Any]
        upperPos["position"] = "BOTTOM-RIGHT"
        guard case .pip? = parsed(["displayType": "pip", "pip": upperPos])?.layout else {
            return XCTFail("upper-case pip.position must parse (case-insensitive, like banner)")
        }

        var infRadius = canonical["pip"] as! [AnyHashable: Any]
        infRadius["borderRadius"] = Double.infinity
        XCTAssertNil(parsed(["displayType": "pip", "pip": infRadius]), "non-finite pip.borderRadius must drop the config")
    }

    // MARK: - Scratchcard

    /// Verifies scratchcard required fields, the reveal threshold range and the actionless reveal button.
    func testScratchcardRules() {
        let canonical: [AnyHashable: Any] = ["displayType": "scratchcard",
                                             "scratchcard": ["showClose": true,
                                                             "background": ["#3A1C71FF", "#B3227CFF"],
                                                             "revealThreshold": 0.55,
                                                             "cover": ["background": "#C9CDD6FF"],
                                                             "revealButton": actionlessButton,
                                                             "reward": reward]]
        guard case .scratchCard(let content)? = parsed(canonical)?.layout else {
            return XCTFail("canonical scratchcard must parse")
        }
        XCTAssertNotNil(content.backgroundGradient)
        XCTAssertEqual(content.revealButton?.text.text, "SPIN")

        for key in ["background", "revealThreshold", "cover", "reward", "showClose"] {
            var block = canonical["scratchcard"] as! [AnyHashable: Any]
            block[key] = nil
            XCTAssertNil(parsed(["displayType": "scratchcard", "scratchcard": block]),
                         "scratchcard without \(key) must be invalid")
        }

        var badThreshold = canonical["scratchcard"] as! [AnyHashable: Any]
        badThreshold["revealThreshold"] = 1.5
        XCTAssertNil(parsed(["displayType": "scratchcard", "scratchcard": badThreshold]))

        var emptyReward = canonical["scratchcard"] as! [AnyHashable: Any]
        emptyReward["reward"] = ["message": ["text": "no title or code", "color": "#111111FF"]]
        XCTAssertNil(parsed(["displayType": "scratchcard", "scratchcard": emptyReward]))
    }

    // MARK: - Spinwheel

    /// Verifies spinwheel segment rules, the required spin button and the winIndex clamp.
    func testSpinwheelRules() {
        let segments: [[AnyHashable: Any]] = [
            ["message": ["text": "5% off", "color": "#FFFFFFFF"], "weight": 1],
            ["message": ["text": "20% off", "color": "#FFFFFFFF"], "weight": 1]
        ]
        let canonical: [AnyHashable: Any] = ["displayType": "spinwheel",
                                             "spinwheel": ["showClose": true,
                                                           "background": "#1B1B46FF",
                                                           "winIndex": 7,
                                                           "spinButton": actionlessButton,
                                                           "reward": reward,
                                                           "segments": segments]]
        guard case .spinWheel(let content)? = parsed(canonical)?.layout else {
            return XCTFail("canonical spinwheel must parse")
        }
        XCTAssertEqual(content.winIndex, 1)
        XCTAssertEqual(content.spinButton.text.text, "SPIN")
        XCTAssertEqual(content.segments[0].text, "5% off")
        XCTAssertNotNil(content.segments[0].textColor)

        var single = canonical["spinwheel"] as! [AnyHashable: Any]
        single["segments"] = [segments[0]]
        XCTAssertNil(parsed(["displayType": "spinwheel", "spinwheel": single]))

        for key in ["spinButton", "winIndex", "reward", "background", "segments"] {
            var block = canonical["spinwheel"] as! [AnyHashable: Any]
            block[key] = nil
            XCTAssertNil(parsed(["displayType": "spinwheel", "spinwheel": block]),
                         "spinwheel without \(key) must be invalid")
        }

        var badSegment = canonical["spinwheel"] as! [AnyHashable: Any]
        badSegment["segments"] = [segments[0], ["weight": 1]]
        XCTAssertNil(parsed(["displayType": "spinwheel", "spinwheel": badSegment]))

        var hugeWin = canonical["spinwheel"] as! [AnyHashable: Any]
        hugeWin["winIndex"] = 1e308
        guard case .spinWheel(let hugeContent)? = parsed(["displayType": "spinwheel", "spinwheel": hugeWin])?.layout else {
            return XCTFail("huge finite winIndex must clamp, not trap Int()")
        }
        XCTAssertEqual(hugeContent.winIndex, hugeContent.segments.count - 1)

        var infWin = canonical["spinwheel"] as! [AnyHashable: Any]
        infWin["winIndex"] = Double.infinity
        XCTAssertNil(parsed(["displayType": "spinwheel", "spinwheel": infWin]),
                     "non-finite winIndex must drop, not crash")

        for badWeight in [Double.infinity, Double.nan, -1] {
            var block = canonical["spinwheel"] as! [AnyHashable: Any]
            block["segments"] = [segments[0],
                                 ["message": ["text": "x", "color": "#FFFFFFFF"], "weight": badWeight]]
            XCTAssertNil(parsed(["displayType": "spinwheel", "spinwheel": block]),
                         "segment weight \(badWeight) must drop, not skew the draw")
        }
    }

    // MARK: - Envelope (deliberate extension, stays tolerant)

    /// Verifies that envelope fields keep tolerant parsing, including numbers arriving as strings.
    func testEnvelopeToleranceKept() {
        var config = modal()
        config["inAppId"] = "promo-1"
        config["maxDisplays"] = "5"
        config["cooldown"] = 60

        let model = parsed(config)

        XCTAssertEqual(model?.id, "promo-1")
        XCTAssertEqual(model?.maxDisplays, 5)
        XCTAssertEqual(model?.cooldown, 60)

        var boolConfig = modal()
        boolConfig["maxDisplays"] = true
        XCTAssertNil(parsed(boolConfig)?.maxDisplays, "JSON boolean must not coerce to a number")
    }

    /// Verifies a numeric inAppId is coerced to its string form (Android envelopeString parity), not dropped to nil.
    func testNumericInAppIdCoercedToString() {
        var numeric = modal(); numeric["inAppId"] = 123
        XCTAssertEqual(parsed(numeric)?.id, "123", "numeric inAppId must coerce to its string form")

        var string = modal(); string["inAppId"] = "promo-1"
        XCTAssertEqual(parsed(string)?.id, "promo-1")

        var empty = modal(); empty["inAppId"] = ""
        XCTAssertNil(parsed(empty)?.id, "empty inAppId must be treated as absent")
    }

    /// Verifies that expireDate wins over ttl, and ttl alone derives an expiry from now.
    func testExpireDatePriorityOverTtl() {
        var config = modal()
        config["expireDate"] = Date(timeIntervalSinceNow: 100).timeIntervalSince1970
        config["ttl"] = 5000

        let expiry = parsed(config)?.expireDate
        XCTAssertNotNil(expiry)
        XCTAssertLessThan(abs(expiry!.timeIntervalSinceNow - 100), 5)

        var ttlOnly = modal()
        ttlOnly["ttl"] = 200
        let ttlExpiry = parsed(ttlOnly)?.expireDate
        XCTAssertNotNil(ttlExpiry)
        XCTAssertLessThan(abs(ttlExpiry!.timeIntervalSinceNow - 200), 5)
    }

    /// Verifies that an explicit JSON null in an optional field is treated as absent, not a fail-closed drop of the whole config.
    func testExplicitNullInOptionalFieldIsTreatedAsAbsent() {
        guard case .modal(let content)? = parsed(modal { $0["title"] = NSNull() })?.layout else {
            return XCTFail("explicit JSON null in optional 'title' must not drop the whole config")
        }
        XCTAssertNil(content.title, "JSON null must be treated as an absent field, not a parse failure")
    }
}
#endif
