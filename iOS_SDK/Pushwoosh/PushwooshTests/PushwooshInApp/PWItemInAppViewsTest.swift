//
//  PWItemInAppViewsTest.swift
//  PushwooshTests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWItemInAppViewsTest: XCTestCase {

    private func recognizers<T: UIGestureRecognizer>(_ type: T.Type, in view: UIView) -> [T] {
        var found = (view.gestureRecognizers ?? []).compactMap { $0 as? T }
        for sub in view.subviews { found += recognizers(type, in: sub) }
        return found
    }

    private func firstPageControl(in view: UIView) -> UIPageControl? {
        if let pc = view as? UIPageControl { return pc }
        for sub in view.subviews {
            if let pc = firstPageControl(in: sub) { return pc }
        }
        return nil
    }

    private func layout(_ v: UIView) {
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        v.layoutIfNeeded()
    }

    private func txt(_ s: String) -> PWInAppText { PWInAppText(text: s, color: nil) }

    /// Carousel builds a page indicator with one dot per item.
    /// Verifies that the close chip carries a circular dark scrim, so its white glyph stays readable over any background.
    func testCloseChipHasCircularDarkScrim() throws {
        let chip = PWInAppStyle.makeCloseButton()
        chip.frame = CGRect(x: 0, y: 0, width: PWInAppStyle.closeSize, height: PWInAppStyle.closeSize)
        chip.layoutIfNeeded()

        let effect = try XCTUnwrap(chip.subviews.compactMap { $0 as? UIVisualEffectView }.first,
                                   "the chip is a glass/blur circle")
        let scrim = try XCTUnwrap(effect.contentView.subviews.first { $0 !== effect.contentView && !($0 is UIImageView) },
                                  "the glyph needs a scrim behind it — glass alone takes the tone of the backdrop")

        var alpha: CGFloat = 0
        scrim.backgroundColor?.getWhite(nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0.2, "the scrim must actually darken, not be transparent")
        XCTAssertEqual(scrim.layer.cornerRadius, PWInAppStyle.closeSize / 2, accuracy: 0.5,
                       "the scrim must be a circle — the effect view does not clip its content view on iOS 26, "
                       + "so a square scrim shows through as a black box")
        XCTAssertTrue(scrim.clipsToBounds, "without clipping the corner radius does nothing")
    }

    func testCarouselRendersAllItems() {
        let items = (0..<3).map {
            PWInAppCarouselItem(imageURL: nil, title: txt("slide \($0)"), subtitle: nil, action: nil)
        }
        let view = PWCarouselInAppView(content: PWInAppCarouselContent(items: items, showCloseButton: true))
        layout(view)
        XCTAssertEqual(firstPageControl(in: view)?.numberOfPages, 3,
                       "carousel page control must have one page per item")
    }

    /// Stories wires up tap (advance), long-press (pause) and swipe-down (dismiss) gestures.
    func testStoriesHasNavigationGestures() {
        let item = PWInAppStoryItem(imageURL: nil, title: txt("T"), subtitle: nil,
                                    buttons: [], duration: 5)
        let view = PWStoriesInAppView(content: PWInAppStoriesContent(items: [item],
                                                                     loops: false,
                                                                     showCloseButton: true))
        layout(view)
        XCTAssertFalse(recognizers(UITapGestureRecognizer.self, in: view).isEmpty,
                       "stories must have a tap gesture (advance)")
        XCTAssertFalse(recognizers(UILongPressGestureRecognizer.self, in: view).isEmpty,
                       "stories must have a long-press gesture (pause)")
        XCTAssertFalse(recognizers(UISwipeGestureRecognizer.self, in: view).isEmpty,
                       "stories must have a swipe-down gesture (dismiss)")
    }
}
#endif
