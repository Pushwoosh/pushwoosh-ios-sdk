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

    private func makeContent(dims: Bool) -> PWInAppModalContent {
        PWInAppModalContent(backgroundColor: .white,
                            title: PWInAppText(text: "Title", color: nil),
                            message: PWInAppText(text: "Body", color: nil),
                            imageURL: nil,
                            showCloseButton: true,
                            buttons: [],
                            dimsBackground: dims)
    }

    private func makeModal(dims: Bool) -> PWModalInAppView {
        let modal = PWModalInAppView(content: makeContent(dims: dims))
        modal.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        modal.layoutIfNeeded()
        return modal
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
}
#endif
