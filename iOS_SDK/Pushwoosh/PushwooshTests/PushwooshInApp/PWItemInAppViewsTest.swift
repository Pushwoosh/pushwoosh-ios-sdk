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
