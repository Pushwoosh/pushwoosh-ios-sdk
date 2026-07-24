//
//  PWCardInAppViewsTest.swift
//  PushwooshTests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWCardInAppViewsTest: XCTestCase {

    private func recognizers<T: UIGestureRecognizer>(_ type: T.Type, in view: UIView) -> [T] {
        var found = (view.gestureRecognizers ?? []).compactMap { $0 as? T }
        for sub in view.subviews { found += recognizers(type, in: sub) }
        return found
    }

    private func buttonCount(in view: UIView) -> Int {
        var n = view.subviews.filter { $0 is UIButton }.count
        for sub in view.subviews { n += buttonCount(in: sub) }
        return n
    }

    private func layout(_ v: UIView) {
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        v.layoutIfNeeded()
    }

    private func txt(_ s: String) -> PWInAppText { PWInAppText(text: s, color: nil) }

    /// Fullscreen with no buttons and showClose=false still forces a close button (guaranteed dismiss).
    func testFullscreenForcesCloseWhenNoButtons() {
        let content = PWInAppFullscreenContent(imageURL: nil, backgroundColor: .black,
                                               title: txt("T"), message: nil,
                                               buttons: [], showCloseButton: false)
        let view = PWFullscreenInAppView(content: content)
        layout(view)
        XCTAssertGreaterThan(buttonCount(in: view), 0,
                             "fullscreen must force a close button when there are no buttons")
    }

    /// Banner can always be dismissed by a swipe toward its edge (even without a close button).
    func testBannerHasSwipeToDismiss() {
        let content = PWInAppBannerContent(position: .top, imageURL: nil,
                                           title: txt("T"), message: nil,
                                           backgroundColor: .white, action: .close,
                                           autoDismiss: 0, showCloseButton: false)
        let view = PWBannerInAppView(content: content)
        layout(view)
        XCTAssertFalse(recognizers(UISwipeGestureRecognizer.self, in: view).isEmpty,
                       "banner must carry a swipe-to-dismiss gesture")
    }

    /// Sheet can always be dismissed by a downward pan/drag (even without a close button).
    func testSheetHasPanToDismiss() {
        let content = PWInAppSheetContent(backgroundColor: .white, title: txt("T"),
                                          message: nil, imageURL: nil,
                                          showCloseButton: false, buttons: [],
                                          dimsBackground: false)
        let view = PWSheetInAppView(content: content)
        layout(view)
        XCTAssertFalse(recognizers(UIPanGestureRecognizer.self, in: view).isEmpty,
                       "sheet must carry a pan-to-dismiss gesture")
    }

    /// load(nil) on a reused image view clears the stale image and any spinner, so a late result
    /// for a previous url can't land on it (regression for the carousel cell-reuse bug).
    func testImageLoaderNilURLClearsReusedView() {
        let iv = UIImageView()
        iv.image = UIImage()
        PWInAppImageLoader.shared.load(nil, into: iv)
        XCTAssertNil(iv.image, "load(nil) must clear a stale image on a reused view")
        XCTAssertFalse(iv.subviews.contains { $0 is UIActivityIndicatorView },
                       "load(nil) must leave no spinner on the view")
    }
}
#endif
