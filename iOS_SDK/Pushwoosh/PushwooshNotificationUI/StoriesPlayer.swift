//
//  StoriesPlayer.swift
//  PushwooshNotificationUI
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import Foundation

protocol StoriesTimerScheduling: AnyObject {
    func schedule(after duration: TimeInterval, _ block: @escaping () -> Void)
    func cancel()
}

final class RealStoriesTimerScheduler: StoriesTimerScheduling {
    private var timer: Timer?

    func schedule(after duration: TimeInterval, _ block: @escaping () -> Void) {
        cancel()
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            block()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

final class StoriesPlayer {

    let pages: [StoryPage]
    private(set) var currentIndex: Int = 0

    var onIndexChange: ((Int) -> Void)?
    var onComplete: (() -> Void)?

    private let scheduler: StoriesTimerScheduling
    private var completed = false

    init(pages: [StoryPage],
         scheduler: StoriesTimerScheduling = RealStoriesTimerScheduler()) {
        self.pages = pages
        self.scheduler = scheduler
    }

    func start() {
        guard !pages.isEmpty else {
            complete()
            return
        }
        completed = false
        currentIndex = 0
        onIndexChange?(0)
        scheduleCurrent()
    }

    func goNext() {
        guard currentIndex + 1 < pages.count else { return }
        advance()
    }

    func goPrevious() {
        completed = false
        if currentIndex > 0 {
            currentIndex -= 1
        }
        onIndexChange?(currentIndex)
        scheduleCurrent()
    }

    func stop() {
        scheduler.cancel()
    }

    /// Freezes auto-advance (e.g. while the user long-presses to hold the current page).
    /// Pairs with ``resume(after:)`` — the caller supplies the remaining segment time.
    func pause() {
        scheduler.cancel()
    }

    /// Resumes auto-advance for the remaining time of the current page after a ``pause()``.
    func resume(after remaining: TimeInterval) {
        guard !completed else { return }
        scheduler.schedule(after: max(remaining, 0)) { [weak self] in
            self?.timerFired()
        }
    }

    private func advance() {
        completed = false
        currentIndex += 1
        onIndexChange?(currentIndex)
        scheduleCurrent()
    }

    private func scheduleCurrent() {
        scheduler.schedule(after: pages[currentIndex].duration) { [weak self] in
            self?.timerFired()
        }
    }

    private func timerFired() {
        if currentIndex + 1 < pages.count {
            advance()
        } else {
            complete()
        }
    }

    private func complete() {
        guard !completed else { return }
        completed = true
        scheduler.cancel()
        onComplete?()
    }
}
