//
//  PWModalInAppViewTest.swift
//  PushwooshTests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWModalInAppViewTest: XCTestCase {

    private func makeContent(dims: Bool, imageURL: URL? = nil) -> PWInAppModalContent {
        PWInAppModalContent(backgroundColor: .white,
                            title: PWInAppText(text: "Title", color: nil),
                            message: PWInAppText(text: "Body", color: nil),
                            imageURL: imageURL,
                            showCloseButton: true,
                            buttons: [],
                            dimsBackground: dims)
    }

    private func makeModal(dims: Bool, imageURL: URL? = nil) -> PWModalInAppView {
        let modal = PWModalInAppView(content: makeContent(dims: dims, imageURL: imageURL))
        modal.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        modal.layoutIfNeeded()
        return modal
    }

    /// Seeds the loader's memory cache so layout runs against a known image, with no network.
    private func seedImage(ratio: CGFloat) -> URL {
        let size = CGSize(width: 100, height: 100 * ratio)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let url = URL(string: "https://example.test/pw-modal-\(UUID().uuidString).png")!
        PWInAppImageLoader.shared.seedMemoryCache(image, for: url)
        return url
    }

    private func mediaView(in view: UIView) -> UIImageView? {
        if let found = view as? UIImageView {
            return found
        }
        for subview in view.subviews {
            if let found = mediaView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func cardHeight(of modal: PWModalInAppView, imageView: UIImageView) -> CGFloat {
        var view: UIView? = imageView
        while let current = view, current.superview !== modal {
            view = current.superview
        }
        return view?.bounds.height ?? 0
    }

    /// Verifies that dimBackground=true installs a blocking dim scrim and swallows touches outside the card (parity with Android's modal).
    func testDimBackgroundTrueBlocksAndDims() {
        let modal = makeModal(dims: true)
        XCTAssertNotNil(modal.backdrop, "dimBackground=true must install a dim scrim")

        // (1,1) is the top-left corner — outside the centered card for any content.
        let outside = modal.hitTest(CGPoint(x: 1, y: 1), with: nil)
        XCTAssertNotNil(outside, "the scrim must swallow touches outside the card")
        XCTAssertFalse(outside === modal, "empty-area touches hit the scrim, not the passthrough root")
    }

    /// Verifies that dimBackground=false stays a floating passthrough card with no scrim and lets outside touches fall through to the host.
    func testDimBackgroundFalseIsFloatingPassthrough() {
        let modal = makeModal(dims: false)
        XCTAssertNil(modal.backdrop, "dimBackground=false must not install a scrim")

        // (1,1) is the top-left corner — outside the centered card for any content.
        let outside = modal.hitTest(CGPoint(x: 1, y: 1), with: nil)
        XCTAssertNil(outside, "empty-area touches must pass through to the host app")
    }

    /// Verifies that a tap on the dim scrim dismisses the modal (tap-outside-to-dismiss, parity with Android).
    func testDimBackgroundTapDismisses() {
        let modal = makeModal(dims: true)
        var closed = false
        modal.onClose = { closed = true }

        modal.perform(Selector(("backdropTapped")))

        XCTAssertTrue(closed, "tapping the scrim must fire onClose")
    }

    /// Verifies that a normal-proportion image drives the well's height, so it is shown whole at full width.
    func testNormalImageKeepsItsAspectRatio() throws {
        let modal = makeModal(dims: true, imageURL: seedImage(ratio: 0.6))
        let media = try XCTUnwrap(mediaView(in: modal), "the card must contain the media view")

        XCTAssertEqual(media.bounds.height / media.bounds.width, 0.6, accuracy: 0.02,
                       "the well must take the image's real ratio, not a fixed one")
        XCTAssertEqual(media.contentMode, .scaleAspectFit,
                       "the image must be fitted, never cropped")
    }

    /// Verifies that an image far taller than the card is scaled down whole instead of cropping the card or shrinking it into a column.
    func testTallImageIsScaledDownInsteadOfCropping() throws {
        let modal = makeModal(dims: true, imageURL: seedImage(ratio: 4))
        let media = try XCTUnwrap(mediaView(in: modal), "the card must contain the media view")
        let cap = modal.bounds.height - 48

        XCTAssertEqual(media.contentMode, .scaleAspectFit,
                       "a tall image must be fitted whole, not cropped top and bottom")
        XCTAssertLessThanOrEqual(cardHeight(of: modal, imageView: media), cap + 0.5,
                                 "the card must stay within the safe-area cap")
        XCTAssertEqual(media.bounds.width, 390 - 56 - 28, accuracy: 0.5,
                       "a tall image must not shrink the card into a narrow column")
        XCTAssertLessThan(media.bounds.height, media.bounds.width * 4,
                          "the well must stop at the cap rather than grow to the image's full height")
    }
}
#endif
