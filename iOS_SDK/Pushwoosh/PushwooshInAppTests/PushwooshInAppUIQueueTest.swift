//
//  PushwooshInAppUIQueueTest.swift
//  PushwooshTests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
@testable import PushwooshInApp

// Returns false from shouldDisplay so presentation short-circuits before any
// window/view is built — lets the FIFO queue / dedup / pause logic be exercised
// headlessly, counting how many messages reached the show gate.
private final class QueueSpyDelegate: NSObject, PWInAppMessageDelegate {
    var shouldDisplayCount = 0
    func pushwooshInAppShouldDisplay(messageId: String?) -> Bool {
        shouldDisplayCount += 1
        return false
    }
}

// Records the delegate callback order and can call back into the presenter from
// inside a callback — the re-entrancy a host integration can produce.
private final class ReentrantSpyDelegate: NSObject, PWInAppMessageDelegate {
    enum Event: Equatable {
        case shouldDisplay(String?)
        case willPresent(String?)
        case didPresent(String?)
        case didClose(String?)
    }

    var events: [Event] = []
    var onShouldDisplay: ((String?) -> Bool)?
    var onWillPresent: ((String?) -> Void)?
    var onDidClose: ((String?) -> Void)?

    func pushwooshInAppShouldDisplay(messageId: String?) -> Bool {
        events.append(.shouldDisplay(messageId))
        return onShouldDisplay?(messageId) ?? true
    }

    func pushwooshInAppWillPresent(messageId: String?) {
        events.append(.willPresent(messageId))
        onWillPresent?(messageId)
    }

    func pushwooshInAppDidPresent(messageId: String?) {
        events.append(.didPresent(messageId))
    }

    func pushwooshInAppDidClose(messageId: String?) {
        events.append(.didClose(messageId))
        onDidClose?(messageId)
    }
}

class PushwooshInAppUIQueueTest: XCTestCase {

    private let ui = PushwooshInAppUI.shared
    private var spy: QueueSpyDelegate!
    private var savedForegroundProvider: (() -> Bool)!

    override func setUp() {
        super.setUp()
        ui.dismissVisible()
        ui.isPaused = false
        savedForegroundProvider = ui.foregroundProvider
        ui.foregroundProvider = { true }
        spy = QueueSpyDelegate()
        ui.delegate = spy
    }

    override func tearDown() {
        ui.isPaused = false
        ui.delegate = nil
        ui.dismissVisible()
        ui.foregroundProvider = savedForegroundProvider
        spy = nil
        super.tearDown()
    }

    private func modal(id: String) -> PWInAppMessageModel {
        let content = PWInAppModalContent(backgroundColor: .white,
                                          title: PWInAppText(text: "T", color: nil),
                                          message: nil,
                                          imageURL: nil,
                                          showCloseButton: true,
                                          buttons: [],
                                          dimsBackground: false)
        return PWInAppMessageModel(id: id,
                                   layout: .modal(content),
                                   maxDisplays: nil,
                                   cooldown: nil,
                                   expireDate: nil)
    }

    /// Two messages with the same id queued while paused collapse to one (dedup by message.id).
    func testDuplicateIdCollapsedInQueue() {
        ui.isPaused = true
        ui.present(modal(id: "dup"))
        ui.present(modal(id: "dup"))
        ui.isPaused = false
        XCTAssertEqual(spy.shouldDisplayCount, 1, "duplicate id must be dropped from the queue")
    }

    /// Distinct ids both drain through the FIFO queue on resume.
    func testDistinctIdsBothDrain() {
        ui.isPaused = true
        ui.present(modal(id: "a"))
        ui.present(modal(id: "b"))
        ui.isPaused = false
        XCTAssertEqual(spy.shouldDisplayCount, 2, "both distinct messages must reach the show gate")
    }

    /// A paused queue holds messages and drains them only on resume.
    func testPausedHoldsUntilResume() {
        ui.isPaused = true
        ui.present(modal(id: "held"))
        XCTAssertEqual(spy.shouldDisplayCount, 0, "paused queue must not present")
        ui.isPaused = false
        XCTAssertEqual(spy.shouldDisplayCount, 1, "resume drains the queue")
    }

    /// A message dequeued while the app is not foreground is held and drained on the next foreground, not presented into an invisible window.
    func testBackgroundDequeueHoldsUntilForeground() {
        ui.foregroundProvider = { false }
        ui.present(modal(id: "bg"))
        XCTAssertEqual(spy.shouldDisplayCount, 0, "message must be held while backgrounded, not presented")

        ui.foregroundProvider = { true }
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let drained = expectation(description: "held message drains on foreground")
        OperationQueue.main.addOperation { drained.fulfill() }
        wait(for: [drained], timeout: 2.0)
        XCTAssertEqual(spy.shouldDisplayCount, 1, "held message drains on the next foreground")
    }

    /// A host calling present() from pushwooshInAppShouldDisplay does not get a second show nested inside the running one.
    func testPresentFromShouldDisplayDoesNotNest() {
        let reentrant = ReentrantSpyDelegate()
        ui.delegate = reentrant
        reentrant.onShouldDisplay = { [unowned self] id in
            if id == "first" {
                PushwooshInAppUI.shared.present(self.modal(id: "second"))
            }
            return true
        }

        ui.present(modal(id: "first"))

        XCTAssertEqual(reentrant.events,
                       [.shouldDisplay("first"), .willPresent("first"), .didPresent("first")],
                       "the re-entrant message must wait in the queue instead of nesting inside the running show")

        reentrant.onShouldDisplay = { _ in false }
        let drained = expectation(description: "queued sibling drains without being presented")
        reentrant.onDidClose = { _ in drained.fulfill() }
        ui.dismissVisible()
        wait(for: [drained], timeout: 2.0)
        XCTAssertFalse(ui.isPresenting, "the sibling was rejected on its turn, so nothing stays on screen")
    }

    private func pipContent() -> PWInAppPipContent {
        let config: [AnyHashable: Any] = ["displayType": "pip",
                                          "pip": ["showClose": true, "position": "bottom-right",
                                                  "loop": true, "muted": true,
                                                  "url": "https://x.co/v.mp4",
                                                  "width": 40, "aspectRatio": 0.5625]]
        guard case .pip(let content)? = PWInAppConfigParser.parse(config)?.layout else {
            fatalError("pip config must parse")
        }
        return content
    }

    /// A pip's onClosed fires exactly once on dismiss, and a repeated dismiss is a no-op.
    func testPipOnClosedFiresOnceOnDismiss() {
        var closed = 0
        PWInAppPipController.shared.present(pipContent(), messageId: "P", onClosed: { closed += 1 })
        PWInAppPipController.shared.dismiss(animated: false)
        PWInAppPipController.shared.dismiss(animated: false)
        XCTAssertEqual(closed, 1, "pip onClosed must fire once, even on a repeated dismiss")
    }

    /// Replacing a pip fires the OUTGOING pip's onClosed exactly once (not zero, not twice).
    func testPipReplaceFiresOutgoingOnClosedOnce() {
        var closedA = 0
        PWInAppPipController.shared.present(pipContent(), messageId: "A", onClosed: { closedA += 1 })
        PWInAppPipController.shared.present(pipContent(), messageId: "B", onClosed: { })
        XCTAssertEqual(closedA, 1, "replacing a pip must fire the outgoing onClosed exactly once")
        PWInAppPipController.shared.dismiss(animated: false)
    }

    /// Re-presenting a pip with the SAME id while it is showing is a no-op: no teardown, no extra onClosed.
    func testPipSameIdRepresentIsSkipped() {
        var closed = 0
        PWInAppPipController.shared.present(pipContent(), messageId: "same", onClosed: { closed += 1 })
        PWInAppPipController.shared.present(pipContent(), messageId: "same", onClosed: { closed += 1 })
        XCTAssertEqual(closed, 0, "same-id re-present must not tear down the showing pip")
        PWInAppPipController.shared.dismiss(animated: false)
        XCTAssertEqual(closed, 1, "dismiss then fires the original onClosed exactly once")
    }
}
#endif
