//
//  PushwooshInboxRichCardsTest.swift
//  PushwooshTests
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
import PushwooshCore
@testable import PushwooshInboxKit

class PushwooshInboxRichCardsTest: XCTestCase {

    // MARK: - Carousel slide decoding

    /// Decodes carousel slides from the root `carousel` array, with per-slide title and url optional.
    func testCarouselDecodesSlidesFromRoot() {
        let message = FakeMessage()
        message.actionParams = ["carousel": [
            ["image": "https://x/1.jpg", "title": "A", "url": "myapp://1"],
            ["image": "https://x/2.jpg"]
        ]]
        let slides = PushwooshInboxCarouselSlide.decode(from: message)
        XCTAssertEqual(slides.count, 2)
        XCTAssertEqual(slides[0].imageUrl, "https://x/1.jpg")
        XCTAssertEqual(slides[0].title, "A")
        XCTAssertEqual(slides[0].url?.absoluteString, "myapp://1")
        XCTAssertNil(slides[1].title)
        XCTAssertNil(slides[1].url)
    }

    /// Drops slides that have no image so the gallery never renders an empty page.
    func testCarouselSkipsSlidesWithoutImage() {
        let message = FakeMessage()
        message.actionParams = ["carousel": [["title": "no image"], ["image": "https://x/ok.jpg"]]]
        XCTAssertEqual(PushwooshInboxCarouselSlide.decode(from: message).count, 1)
    }

    /// Keeps a slide whose tap URL has no scheme but drops the unusable URL, so a malformed
    /// link can't navigate anywhere while the slide image still renders.
    func testCarouselSlideDropsSchemelessURL() {
        let message = FakeMessage()
        message.actionParams = ["carousel": [["image": "https://x/1.jpg", "url": "p/1"]]]
        let slides = PushwooshInboxCarouselSlide.decode(from: message)
        XCTAssertEqual(slides.count, 1)
        XCTAssertEqual(slides[0].imageUrl, "https://x/1.jpg")
        XCTAssertNil(slides[0].url)
    }

    /// Reads carousel slides nested in the JSON-encoded `u` string the server commonly emits.
    func testCarouselDecodesFromStringEncodedU() {
        let message = FakeMessage()
        message.actionParams = ["u": "{\"carousel\":[{\"image\":\"https://x/1.jpg\"}]}"]
        XCTAssertEqual(PushwooshInboxCarouselSlide.decode(from: message).count, 1)
    }

    /// Reads carousel slides nested in the `u` dictionary form (not just the JSON string).
    func testCarouselDecodesFromDictEncodedU() {
        let message = FakeMessage()
        message.actionParams = ["u": ["carousel": [["image": "https://x/1.jpg"]]]]
        XCTAssertEqual(PushwooshInboxCarouselSlide.decode(from: message).count, 1)
    }

    /// Returns an empty slide list when no carousel data is present.
    func testCarouselReturnsEmptyWhenMissing() {
        XCTAssertTrue(PushwooshInboxCarouselSlide.decode(from: FakeMessage()).isEmpty)
    }

    // MARK: - Video content decoding

    /// Decodes a video descriptor — URL required, poster optional/absent.
    func testVideoDecodesURLOnly() {
        let message = FakeMessage()
        message.actionParams = ["video": ["url": "https://x/v.mp4"]]
        let content = PushwooshInboxVideoContent.decode(from: message)
        XCTAssertEqual(content?.videoURL.absoluteString, "https://x/v.mp4")
        XCTAssertNil(content?.posterURL)
    }

    /// Decodes the optional poster image used as the cell preview.
    func testVideoDecodesPoster() {
        let message = FakeMessage()
        message.actionParams = ["video": ["url": "https://x/v.mp4", "poster": "https://x/p.jpg"]]
        XCTAssertEqual(PushwooshInboxVideoContent.decode(from: message)?.posterURL, "https://x/p.jpg")
    }

    /// Returns nil when the video descriptor has no usable URL.
    func testVideoReturnsNilWithoutURL() {
        let message = FakeMessage()
        message.actionParams = ["video": ["poster": "https://x/p.jpg"]]
        XCTAssertNil(PushwooshInboxVideoContent.decode(from: message))
    }

    /// Returns nil when the video URL has no scheme (relative path).
    func testVideoReturnsNilForSchemelessURL() {
        let message = FakeMessage()
        message.actionParams = ["video": ["url": "clip.mp4"]]
        XCTAssertNil(PushwooshInboxVideoContent.decode(from: message))
    }

    /// Rejects a non-network scheme (e.g. file://): the URL is handed to AVPlayer, which — unlike
    /// UIApplication.open — would load a local resource named by the remote payload.
    func testVideoRejectsNonNetworkScheme() {
        let message = FakeMessage()
        message.actionParams = ["video": ["url": "file:///etc/passwd"]]
        XCTAssertNil(PushwooshInboxVideoContent.decode(from: message))
    }

    /// Reads a video descriptor nested in the JSON-encoded `u` string the server commonly emits.
    func testVideoDecodesFromStringEncodedU() {
        let message = FakeMessage()
        message.actionParams = ["u": "{\"video\":{\"url\":\"https://x/v.mp4\"}}"]
        XCTAssertEqual(PushwooshInboxVideoContent.decode(from: message)?.videoURL.absoluteString,
                       "https://x/v.mp4")
    }

    // MARK: - Wallet pass decoding

    /// Decodes a bare pass-URL string form.
    func testWalletDecodesBareString() {
        let message = FakeMessage()
        message.actionParams = ["wallet": "https://x/coupon.pkpass"]
        XCTAssertEqual(PushwooshInboxWalletPass.decode(from: message)?.passURL.absoluteString,
                       "https://x/coupon.pkpass")
    }

    /// Decodes the object form `{ "wallet": { "pass": "..." } }` at the payload root.
    func testWalletDecodesObjectFormAtRoot() {
        let message = FakeMessage()
        message.actionParams = ["wallet": ["pass": "https://x/coupon.pkpass"]]
        XCTAssertEqual(PushwooshInboxWalletPass.decode(from: message)?.passURL.absoluteString,
                       "https://x/coupon.pkpass")
    }

    /// Returns nil when the pass URL has no scheme (relative path).
    func testWalletReturnsNilForSchemelessURL() {
        let message = FakeMessage()
        message.actionParams = ["wallet": "coupon.pkpass"]
        XCTAssertNil(PushwooshInboxWalletPass.decode(from: message))
    }

    /// Rejects a non-network scheme (e.g. file://): the pass is fetched with URLSession, which —
    /// unlike UIApplication.open — would read a local resource named by the remote payload.
    func testWalletRejectsNonNetworkScheme() {
        let message = FakeMessage()
        message.actionParams = ["wallet": "file:///var/mobile/secret"]
        XCTAssertNil(PushwooshInboxWalletPass.decode(from: message))
    }

    /// Decodes the object form carrying a `pass` field, nested in `u`.
    func testWalletDecodesObjectFormNestedInU() {
        let message = FakeMessage()
        message.actionParams = ["u": ["wallet": ["pass": "https://x/coupon.pkpass"]]]
        XCTAssertEqual(PushwooshInboxWalletPass.decode(from: message)?.passURL.absoluteString,
                       "https://x/coupon.pkpass")
    }

    /// Returns nil when no pass URL is present.
    func testWalletReturnsNilWithoutPass() {
        let message = FakeMessage()
        message.actionParams = ["wallet": ["foo": "bar"]]
        XCTAssertNil(PushwooshInboxWalletPass.decode(from: message))
    }

    /// Reads a pass URL nested in the JSON-encoded `u` string.
    func testWalletDecodesFromStringEncodedU() {
        let message = FakeMessage()
        message.actionParams = ["u": "{\"wallet\":\"https://x/coupon.pkpass\"}"]
        XCTAssertEqual(PushwooshInboxWalletPass.decode(from: message)?.passURL.absoluteString,
                       "https://x/coupon.pkpass")
    }

    // MARK: - Resolver selection & degradation

    /// Resolver honours `carousel` when at least one slide is present.
    func testResolverPicksCarouselWithSlides() {
        let message = FakeMessage()
        message.actionParams = ["displayType": "carousel", "carousel": [["image": "https://x/1.jpg"]]]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "carousel")
    }

    /// Resolver degrades `carousel` to `classic` when there are no slides.
    func testResolverDegradesCarouselWithoutSlides() {
        let message = FakeMessage()
        message.actionParams = ["displayType": "carousel"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "classic")
    }

    /// Resolver honours `video` when a video descriptor is present.
    func testResolverPicksVideoWithContent() {
        let message = FakeMessage()
        message.actionParams = ["displayType": "video", "video": ["url": "https://x/v.mp4"]]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "video")
    }

    /// Resolver degrades `video` to `classic` when no descriptor is present.
    func testResolverDegradesVideoWithoutContent() {
        let message = FakeMessage()
        message.actionParams = ["displayType": "video"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "classic")
    }

    /// Resolver honours `wallet` when a pass URL is present.
    func testResolverPicksWalletWithPass() {
        let message = FakeMessage()
        message.actionParams = ["displayType": "wallet", "wallet": "https://x/c.pkpass"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "wallet")
    }

    /// Resolver degrades `wallet` to `classic` when no pass URL is present.
    func testResolverDegradesWalletWithoutPass() {
        let message = FakeMessage()
        message.actionParams = ["displayType": "wallet"]
        XCTAssertEqual(PushwooshInboxKitAttributes.defaultCellKindResolver(message), "classic")
    }

    // MARK: - Resolved image URL

    /// resolvedImageURL falls back to `image` inside the JSON-encoded `u` string when
    /// message.imageUrl is empty — how banner/captioned/wallet receive the image via push.
    func testResolvedImageURLFromStringEncodedU() {
        let message = FakeMessage()
        message.actionParams = ["u": "{\"displayType\":\"banner\",\"image\":\"https://x/b.jpg\"}"]
        XCTAssertEqual(PushwooshInboxKitAttributes.resolvedImageURL(from: message), "https://x/b.jpg")
    }

    /// resolvedImageURL prefers a non-empty message.imageUrl over the payload fallback.
    func testResolvedImageURLPrefersMessageImage() {
        let message = FakeMessage()
        message.imageUrl = "https://x/direct.jpg"
        message.actionParams = ["u": "{\"image\":\"https://x/other.jpg\"}"]
        XCTAssertEqual(PushwooshInboxKitAttributes.resolvedImageURL(from: message), "https://x/direct.jpg")
    }

    // MARK: - Registry

    /// The default registry includes the new rich-card kinds.
    func testRegistryIncludesRichCardKinds() {
        let attributes = PushwooshInboxKitAttributes()
        XCTAssertTrue(attributes.cells["carousel"] == PushwooshInboxCarouselCell.self)
        XCTAssertTrue(attributes.cells["video"] == PushwooshInboxVideoCell.self)
        #if os(iOS)
        XCTAssertTrue(attributes.cells["wallet"] == PushwooshInboxWalletCell.self)
        #endif
    }
}
