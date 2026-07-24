//
//  PWInAppPipController.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Owns the floating PiP's dedicated window and lifecycle. Unlike the other
//  templates it does not go through the one-at-a-time shared-window presenter —
//  it coexists with the app (and with a modal/banner) in its own window.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWInAppPipController {

    static let shared = PWInAppPipController()

    /// Receives lifecycle callbacks (forwarded from the main presenter's delegate).
    weak var delegate: PWInAppMessageDelegate?
    /// Runs a CTA action (opening URLs + notifying the click delegate). Set via
    /// `present(...)` and cleared on dismiss so a closed pip doesn't pin the
    /// captured message (and its Core hooks) on this singleton.
    private var onAction: ((PWInAppAction, String?) -> Void)?

    private var window: PWInAppPipWindow?
    private var container: PWInAppPipContainerView?
    private var currentMessageId: String?
    /// Close statistics hook for the current presentation; fired once on dismiss.
    private var onClosedCurrent: (() -> Void)?

    var isShowing: Bool {
        window != nil
    }

    private init() {
        // Our pip window rides on the scene it was built in; if that scene is
        // torn down (iPad multi-window / Stage Manager) drop the window so it
        // doesn't orphan (isShowing stuck true, close callbacks never fired).
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
        dismiss(animated: false)
    }

    func present(_ content: PWInAppPipContent,
                 messageId: String?,
                 onClosed: (() -> Void)? = nil,
                 onAction: ((PWInAppAction, String?) -> Void)? = nil) {
        if let messageId, messageId == currentMessageId, window != nil {
            return
        }
        // Dismiss the old pip BEFORE assigning the new handlers below, so its
        // finish() clears the outgoing onAction, not the incoming one.
        if window != nil {
            dismiss(animated: false)
        }

        let window: PWInAppPipWindow
        if let scene = PWInAppScene.active() {
            window = PWInAppPipWindow(frame: scene.coordinateSpace.bounds)
            window.windowScene = scene
        } else {
            window = PWInAppPipWindow(frame: UIScreen.main.bounds)
        }
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear

        let root = PWInAppViewController()
        window.rootViewController = root

        let container = PWInAppPipContainerView(content: content)
        container.onClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        container.onAction = { [weak self] action in
            guard let self = self else { return }
            self.onAction?(action, self.currentMessageId)
            self.dismiss(animated: true)
        }
        root.view.addSubview(container)
        window.contentView = container

        self.window = window
        self.container = container
        self.currentMessageId = messageId
        self.onClosedCurrent = onClosed
        self.onAction = onAction

        window.isHidden = false
        root.view.layoutIfNeeded()
        container.place(in: root.view)

        delegate?.pushwooshInAppWillPresent?(messageId: messageId)
        delegate?.pushwooshInAppDidPresent?(messageId: messageId)
    }

    func dismiss(animated: Bool) {
        guard let window = window else { return }
        let container = self.container
        let messageId = currentMessageId
        let onClosed = onClosedCurrent

        let finish: () -> Void = { [weak self] in
            container?.teardown()
            window.isHidden = true
            // A replacement pip may have been presented while the dismiss
            // animation ran. Everything below — state teardown, the didClose
            // delegate and the close hook, and releasing the captured message via
            // onAction — must run once and only for the window still on screen, so
            // a re-entrant dismiss inside the animation window can't double-fire
            // didClose or clear the replacement's state.
            guard self?.window === window else {
                return
            }
            self?.window = nil
            self?.container = nil
            self?.currentMessageId = nil
            self?.onAction = nil
            self?.onClosedCurrent = nil
            self?.delegate?.pushwooshInAppDidClose?(messageId: messageId)
            onClosed?()
        }

        if animated, let container = container {
            UIView.animate(withDuration: 0.22, animations: {
                container.alpha = 0
                container.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            }, completion: { _ in finish() })
        } else {
            finish()
        }
    }

}
#endif
