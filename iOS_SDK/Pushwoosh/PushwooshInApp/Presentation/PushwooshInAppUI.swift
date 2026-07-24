//
//  PushwooshInAppUI.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Default in-app presenter: owns a dedicated window, a FIFO display queue, and
/// enforces one-at-a-time presentation. New messages enqueue; the next is shown
/// when the current is dismissed. All access is main-thread only.
final class PushwooshInAppUI: PWInAppPresenting {

    static let shared = PushwooshInAppUI()

    weak var delegate: PWInAppMessageDelegate?

    // A host (RN/Flutter bridge) may flip `isPaused` from a background thread
    // while main reads/resumes it; the lock gives the flag itself atomic
    // read/write (matching Android's `@Volatile`), independent of the
    // main-thread marshaling below for the resume side-effect.
    private let isPausedLock = NSLock()
    private var _isPaused = false

    var isPaused: Bool {
        get {
            isPausedLock.lock()
            defer { isPausedLock.unlock() }
            return _isPaused
        }
        set {
            isPausedLock.lock()
            let wasPaused = _isPaused
            _isPaused = newValue
            isPausedLock.unlock()

            guard wasPaused, !newValue else { return }
            // Resuming touches the window, which must happen on main.
            if Thread.isMainThread {
                resumeDisplay()
            } else {
                DispatchQueue.main.async { [weak self] in self?.resumeDisplay() }
            }
        }
    }

    private var window: PWInAppWindow?
    private var queue: [PWInAppMessageModel] = []
    private var current: (model: PWInAppMessageModel, view: PWInAppRenderable)?
    /// PiPs delivered while paused — shown in order when display resumes. A list,
    /// not a single slot, so a second paused pip doesn't silently drop the first
    /// (which would also lose its onShown show-statistic).
    private var pendingPips: [PWInAppMessageModel] = []

    // Presentation is gated on the app being foreground: dequeuing while backgrounded
    // would present into an invisible window, burning the frequency cap and firing
    // onShown unseen. Held messages drain on the next foreground. Injectable for tests
    // (mirrors Android's foregroundProvider seam).
    var foregroundProvider: () -> Bool = { PWInAppScene.hasForegroundActive() }
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        // Our cached window rides on the scene it was built in; if that scene is
        // torn down (iPad multi-window / Stage Manager), drop the window so the
        // next message rebuilds on a live scene instead of a dead one.
        NotificationCenter.default.addObserver(
            forName: UIScene.didDisconnectNotification,
            object: nil,
            queue: .main) { [weak self] note in
            self?.handleSceneDisconnect(note)
        }
    }

    private func handleSceneDisconnect(_ note: Notification) {
        guard let scene = note.object as? UIWindowScene, window?.windowScene === scene else {
            return
        }
        window?.isHidden = true
        window = nil
        if let active = current {
            current = nil
            delegate?.pushwooshInAppDidClose?(messageId: active.model.id)
            active.model.onClosed?()
        }
        showNextIfIdle()
    }

    func present(_ message: PWInAppMessageModel) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.present(message) }
            return
        }

        // Opt-in frequency capping (show-once / max / cooldown / expiry). No caps
        // in the config → always allowed (behaviour unchanged).
        guard PWInAppFrequencyStore.shared.canShow(message) else {
            return
        }

        // Warm image caches for this message before it's shown.
        PWInAppImageLoader.shared.prefetch(message.imageURLs())

        // PiP runs in its own floating window and coexists with the app, so it
        // bypasses the one-at-a-time shared-window queue.
        if case .pip(let content) = message.layout {
            if isPaused {
                pendingPips.append(message)
                return
            }
            if delegate?.pushwooshInAppShouldDisplay?(messageId: message.id) == false {
                return
            }
            PWInAppFrequencyStore.shared.recordShown(message)
            let controller = PWInAppPipController.shared
            controller.delegate = delegate
            controller.present(content, messageId: message.id, onClosed: message.onClosed) { [weak self] action, _ in
                self?.openAction(action, for: message)
            }
            message.onShown?()
            return
        }

        if isDuplicate(message) {
            return
        }
        queue.append(message)
        showNextIfIdle()
    }

    // MARK: - Queue

    private func isDuplicate(_ message: PWInAppMessageModel) -> Bool {
        guard let id = message.id else {
            return false
        }
        if current?.model.id == id {
            return true
        }
        return queue.contains { $0.id == id }
    }

    private func resumeDisplay() {
        let pips = pendingPips
        pendingPips = []
        for pip in pips {
            present(pip)
        }
        showNextIfIdle()
    }

    private func showNextIfIdle() {
        guard current == nil, !isPaused, !queue.isEmpty else {
            return
        }
        guard foregroundProvider() else {
            observeForegroundForRetry()
            return
        }
        let next = queue.removeFirst()
        show(next)
    }

    private func observeForegroundForRetry() {
        guard foregroundObserver == nil else {
            return
        }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                                    object: nil,
                                                                    queue: .main) { [weak self] _ in
            guard let self = self else {
                return
            }
            if let observer = self.foregroundObserver {
                NotificationCenter.default.removeObserver(observer)
                self.foregroundObserver = nil
            }
            self.showNextIfIdle()
        }
    }

    private func show(_ message: PWInAppMessageModel) {
        if delegate?.pushwooshInAppShouldDisplay?(messageId: message.id) == false {
            showNextIfIdle()
            return
        }
        // Re-check caps at show time: a sibling with the same id may have been
        // shown while this one waited in the queue.
        guard PWInAppFrequencyStore.shared.canShow(message) else {
            showNextIfIdle()
            return
        }
        guard let view = PWInAppViewFactory.makeView(for: message.layout) else {
            showNextIfIdle()
            return
        }
        let window = ensureWindow()
        guard let container = window.rootViewController?.view else {
            showNextIfIdle()
            return
        }
        // Record only once we're actually presenting.
        PWInAppFrequencyStore.shared.recordShown(message)

        view.onClose = { [weak self] in
            self?.dismissCurrent()
        }
        view.onAction = { [weak self] action in
            self?.handle(action, for: message)
        }
        if let game = view as? PWInAppRewardReporting {
            game.onRewardRevealed = { [weak self] code in
                self?.delegate?.pushwooshInAppRewardRevealed?(promoCode: code, messageId: message.id)
            }
            game.onRewardClaimed = { [weak self] code in
                self?.delegate?.pushwooshInAppRewardClaimed?(promoCode: code, messageId: message.id)
            }
        }

        current = (message, view)
        delegate?.pushwooshInAppWillPresent?(messageId: message.id)
        window.isHidden = false
        view.present(in: container)
        delegate?.pushwooshInAppDidPresent?(messageId: message.id)
        message.onShown?()
    }

    private func handle(_ action: PWInAppAction, for message: PWInAppMessageModel) {
        openAction(action, for: message)
        dismissCurrent()
    }

    /// Runs an action's side effect — opens the URL, notifies the click
    /// delegate and fires the message's click statistics hook. A close action
    /// is not a click. Does not dismiss; the caller decides. Reused by PiP.
    func openAction(_ action: PWInAppAction, for message: PWInAppMessageModel) {
        switch action {
        case .url(let url):
            delegate?.pushwooshInAppClickedAction?(url: url.absoluteString, messageId: message.id)
            message.onClicked?()
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .close:
            break
        }
    }

    // Host bridges (RN/Flutter/Unity) may query this off-main; `current` and the
    // pip `window` are mutated only on main, so the read is marshaled there to
    // avoid a data race — same host-facing threat model as `isPaused`.
    var isPresenting: Bool {
        if Thread.isMainThread {
            return current != nil || PWInAppPipController.shared.isShowing
        }
        return DispatchQueue.main.sync {
            current != nil || PWInAppPipController.shared.isShowing
        }
    }

    func dismissVisible() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.dismissVisible() }
            return
        }
        dismissCurrent()
        PWInAppPipController.shared.dismiss(animated: true)
    }

    private func dismissCurrent() {
        guard let active = current else {
            return
        }
        // Clear `current` before the dismiss animation so a second call within the
        // animation window (auto-dismiss timer racing a tap, action + close) hits
        // the guard and returns — no duplicate didClose, no double queue advance.
        current = nil
        active.view.dismiss { [weak self] in
            guard let self = self else {
                return
            }
            self.delegate?.pushwooshInAppDidClose?(messageId: active.model.id)
            active.model.onClosed?()
            // Don't tear down the window if a present() during the dismiss
            // animation already reused it for the next message.
            if self.current == nil && self.queue.isEmpty {
                self.window?.isHidden = true
                self.window = nil
            }
            self.showNextIfIdle()
        }
    }

    private func ensureWindow() -> PWInAppWindow {
        if let existing = window {
            return existing
        }
        let created = PWInAppWindow.make()
        window = created
        return created
    }
}
#endif
