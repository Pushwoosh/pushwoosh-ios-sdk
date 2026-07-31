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

    private func firstButton(in view: UIView) -> UIButton? {
        for sub in view.subviews {
            if let button = sub as? UIButton { return button }
            if let found = firstButton(in: sub) { return found }
        }
        return nil
    }

    private func firstImageView(in view: UIView) -> UIImageView? {
        for sub in view.subviews {
            if let image = sub as? UIImageView { return image }
            if let found = firstImageView(in: sub) { return found }
        }
        return nil
    }

    private func square(_ side: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
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

    /// A sheet with a cover builds at all: the cover's height cap references the view's own safe
    /// area, so the cover must be in the hierarchy before that constraint is activated — otherwise
    /// Auto Layout throws "no common ancestor" and the app dies on every sheet carrying an image.
    func testSheetWithCoverBuilds() {
        let content = PWInAppSheetContent(backgroundColor: .white, title: txt("T"), message: nil,
                                          imageURL: URL(string: "file:///dev/null"),
                                          showCloseButton: true, buttons: [],
                                          dimsBackground: false)
        let view = PWSheetInAppView(content: content)
        layout(view)
        XCTAssertGreaterThan(view.subviews.first?.bounds.height ?? 0, 0,
                             "sheet with a cover must lay out with a resolved height")
    }

    /// A dimmed sheet darkens the host, claims touches outside the card and offers the outside tap
    /// as a way out — the flag used to build a transparent, untouchable backdrop, so dimBackground
    /// true and false looked identical on iOS while Android dimmed and blocked.
    func testDimmedSheetBlocksTheHost() {
        let content = PWInAppSheetContent(backgroundColor: .white, title: txt("T"), message: nil,
                                          imageURL: nil, showCloseButton: false, buttons: [],
                                          dimsBackground: true)
        let view = PWSheetInAppView(content: content)
        layout(view)

        guard let hit = view.hitTest(CGPoint(x: 195, y: 40), with: nil), hit !== view else {
            return XCTFail("a dimmed sheet must claim touches outside the card")
        }
        XCTAssertEqual(hit.backgroundColor?.cgColor.alpha ?? 0, 0.6, accuracy: 0.01,
                       "the scrim must dim the host")
        XCTAssertFalse(recognizers(UITapGestureRecognizer.self, in: hit).isEmpty,
                       "the scrim must dismiss the sheet on an outside tap")
    }

    /// A floating sheet stays non-blocking: touches outside the card reach the app underneath.
    func testFloatingSheetPassesOutsideTouchesThrough() {
        let content = PWInAppSheetContent(backgroundColor: .white, title: txt("T"), message: nil,
                                          imageURL: nil, showCloseButton: false, buttons: [],
                                          dimsBackground: false)
        let view = PWSheetInAppView(content: content)
        layout(view)
        XCTAssertNil(view.hitTest(CGPoint(x: 195, y: 40), with: nil),
                     "a floating sheet must pass outside touches to the app")
    }

    /// The sheet's cover keeps its width × 0.52 proportion even when the image that lands in it is
    /// square — the image view's own compression resistance used to fight the ratio at equal
    /// priority, so the cover came out taller and cropped differently than the Android sheet.
    func testSheetCoverKeepsItsRatioWithASquareImage() {
        let content = PWInAppSheetContent(backgroundColor: .white, title: txt("T"), message: nil,
                                          imageURL: URL(string: "https://example.com/cover.png"),
                                          showCloseButton: false, buttons: [],
                                          dimsBackground: false)
        let view = PWSheetInAppView(content: content)
        layout(view)

        guard let cover = firstImageView(in: view) else {
            return XCTFail("a sheet with a cover must build an image view")
        }
        cover.image = square(1200)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertGreaterThan(cover.bounds.width, 0, "cover must be laid out")
        XCTAssertEqual(cover.bounds.height / cover.bounds.width, 0.52, accuracy: 0.02,
                       "cover must follow the configured ratio, not the image's own size")
    }

    /// A sheet taller than the screen keeps its close button on screen instead of letting it ride
    /// the card's top edge off the top (where the status bar hides it and eats the tap).
    func testTallSheetKeepsCloseButtonOnScreen() {
        let content = PWInAppSheetContent(backgroundColor: .white, title: txt("T"),
                                          message: txt(String(repeating: "long message ", count: 300)),
                                          imageURL: nil, showCloseButton: true, buttons: [],
                                          dimsBackground: false)
        let view = PWSheetInAppView(content: content)
        layout(view)
        guard let close = firstButton(in: view) else {
            return XCTFail("a sheet with showClose must carry a close button")
        }
        XCTAssertGreaterThanOrEqual(close.convert(close.bounds, to: view).minY, 0,
                                    "close button must stay on screen when the sheet outgrows it")
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
