//
//  PWGamifiedInAppViewsTest.swift
//  PushwooshTests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

class PWGamifiedInAppViewsTest: XCTestCase {

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
    private func reward() -> PWInAppReward {
        PWInAppReward(title: txt("Prize"), message: nil, promoCode: "CODE10", button: nil)
    }

    /// Scratch card with no reveal/reward button and showClose=false still forces a close affordance.
    func testScratchCardForcesCloseWhenHidden() {
        let content = PWInAppScratchCardContent(backgroundColor: .white, backgroundGradient: nil,
                                                title: nil, message: nil,
                                                coverImageURL: nil, coverColor: .gray,
                                                revealThreshold: 0.55, revealButton: nil,
                                                reward: reward(), showCloseButton: false)
        let view = PWScratchCardInAppView(content: content)
        layout(view)
        XCTAssertGreaterThan(buttonCount(in: view), 0,
                             "scratch card must force a close affordance when nothing else dismisses it")
    }

    /// Spin wheel builds without crashing for a valid winIndex (segments[winIndex] must stay in bounds).
    func testSpinWheelBuildsWithValidWinIndex() {
        let seg = PWInAppWheelSegment(text: "A", color: nil, textColor: nil, weight: 1, reward: nil)
        let spin = PWInAppButton(text: txt("Spin"), backgroundColor: .blue,
                                 borderColor: .clear, cornerRadius: 8, action: .close)
        let content = PWInAppSpinWheelContent(backgroundColor: .white, backgroundGradient: nil,
                                              title: nil, message: nil,
                                              segments: [seg, seg], winIndex: 1,
                                              spinButton: spin, reward: reward(),
                                              loseTitle: nil, showCloseButton: true)
        let view = PWSpinWheelInAppView(content: content)
        layout(view)
        XCTAssertNotNil(view.superview ?? view, "spin wheel must build for an in-bounds winIndex")
        XCTAssertGreaterThan(buttonCount(in: view), 0, "spin wheel has at least the spin button")
    }
}
#endif
