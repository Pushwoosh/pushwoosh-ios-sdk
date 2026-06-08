//
//  StoriesPlayerTests.swift
//  PushwooshNotificationUITests
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import XCTest
@testable import PushwooshNotificationUI

private final class ManualScheduler: StoriesTimerScheduling {
    private var fire: (() -> Void)?
    private(set) var lastDuration: TimeInterval?
    var isScheduled: Bool { fire != nil }

    func schedule(after duration: TimeInterval, _ block: @escaping () -> Void) {
        lastDuration = duration
        fire = block
    }
    func cancel() { fire = nil }
    func tick() {
        let f = fire
        fire = nil
        f?()
    }
}

final class StoriesPlayerTests: XCTestCase {

    private func makePages(_ count: Int) -> [StoryPage] {
        (0..<count).map {
            StoryPage(imageURL: URL(string: "https://e.com/\($0).jpg")!,
                      duration: TimeInterval($0 + 1))
        }
    }

    /// Starts on the first page and schedules its duration.
    func testStartsOnFirstPage() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(3), scheduler: scheduler)
        var observed: [Int] = []
        player.onIndexChange = { observed.append($0) }

        player.start()

        XCTAssertEqual(player.currentIndex, 0)
        XCTAssertEqual(observed, [0])
        XCTAssertEqual(scheduler.lastDuration, 1)
    }

    /// Auto-advances to the next page when the timer fires.
    func testTimerAdvances() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(3), scheduler: scheduler)
        player.start()

        scheduler.tick()

        XCTAssertEqual(player.currentIndex, 1)
        XCTAssertEqual(scheduler.lastDuration, 2)
    }

    /// goNext / goPrevious respect bounds.
    func testManualNavigationBounds() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(2), scheduler: scheduler)
        player.start()

        player.goPrevious()
        XCTAssertEqual(player.currentIndex, 0)

        player.goNext()
        XCTAssertEqual(player.currentIndex, 1)

        player.goNext()
        XCTAssertEqual(player.currentIndex, 1)
    }

    /// Reaching the end fires onComplete once and stops scheduling.
    func testCompletionFiresOnce() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(2), scheduler: scheduler)
        var completions = 0
        player.onComplete = { completions += 1 }
        player.start()

        scheduler.tick()
        scheduler.tick()

        XCTAssertEqual(completions, 1)
        XCTAssertFalse(scheduler.isScheduled)
    }

    /// Manual navigation still works after auto-play completed (tap back to replay).
    func testNavigationWorksAfterCompletion() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(2), scheduler: scheduler)
        var observed: [Int] = []
        player.onIndexChange = { observed.append($0) }
        player.start()
        scheduler.tick()
        scheduler.tick()

        player.goPrevious()

        XCTAssertEqual(player.currentIndex, 0)
        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(observed, [0, 1, 0])
    }

    /// A forward tap on the last page is ignored — the timer keeps running so the last
    /// segment finishes filling on its own instead of freezing or completing early.
    func testForwardTapOnLastPageIsIgnored() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(2), scheduler: scheduler)
        var completions = 0
        player.onComplete = { completions += 1 }
        player.start()
        scheduler.tick()

        player.goNext()

        XCTAssertEqual(player.currentIndex, 1)
        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(completions, 0)
    }

    /// stop() cancels the scheduler and suppresses any further auto-advance / completion.
    func testStopCancelsSchedulerAndSuppressesCallbacks() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(3), scheduler: scheduler)
        var completions = 0
        player.onComplete = { completions += 1 }
        player.start()

        player.stop()
        scheduler.tick()

        XCTAssertFalse(scheduler.isScheduled)
        XCTAssertEqual(player.currentIndex, 0)
        XCTAssertEqual(completions, 0)
    }

    /// A single-page story completes on the first timer tick (timerFired -> complete, no advance).
    func testSinglePageCompletesOnFirstTick() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(1), scheduler: scheduler)
        var completions = 0
        player.onComplete = { completions += 1 }
        player.start()

        scheduler.tick()

        XCTAssertEqual(completions, 1)
        XCTAssertFalse(scheduler.isScheduled)
    }

    /// pause() cancels the running auto-advance timer without changing the current page.
    func testPauseCancelsScheduler() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(3), scheduler: scheduler)
        player.start()

        player.pause()

        XCTAssertFalse(scheduler.isScheduled)
        XCTAssertEqual(player.currentIndex, 0)
    }

    /// resume(after:) reschedules only the remaining time and then advances when that time elapses.
    func testResumeReschedulesForRemaining() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(3), scheduler: scheduler)
        player.start()
        player.pause()

        player.resume(after: 0.3)
        XCTAssertEqual(scheduler.lastDuration, 0.3)

        scheduler.tick()
        XCTAssertEqual(player.currentIndex, 1)
    }

    /// resume(after:) after the story already completed does nothing (no reschedule).
    func testResumeAfterCompletionIsNoOp() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: makePages(1), scheduler: scheduler)
        player.start()
        scheduler.tick()

        player.resume(after: 1)

        XCTAssertFalse(scheduler.isScheduled)
    }

    /// An empty page list completes immediately on start.
    func testEmptyCompletesImmediately() {
        let scheduler = ManualScheduler()
        let player = StoriesPlayer(pages: [], scheduler: scheduler)
        var completions = 0
        player.onComplete = { completions += 1 }

        player.start()

        XCTAssertEqual(completions, 1)
        XCTAssertFalse(scheduler.isScheduled)
    }
}
