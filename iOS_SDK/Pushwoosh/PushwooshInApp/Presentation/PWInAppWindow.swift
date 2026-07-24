//
//  PWInAppWindow.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Dedicated window the in-app is presented in, above the app's own UI. Bound to
/// the active `UIWindowScene` so it works in SwiftUI / scene-based / classic
/// UIKit hosts alike. Touches that miss the in-app view pass through to the app.
final class PWInAppWindow: UIWindow {

    static func make() -> PWInAppWindow {
        let window: PWInAppWindow
        if let scene = PWInAppScene.active() {
            window = PWInAppWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds
        } else {
            window = PWInAppWindow(frame: UIScreen.main.bounds)
        }
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.rootViewController = PWInAppViewController()
        return window
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else {
            return nil
        }
        if hit == rootViewController?.view {
            return nil
        }
        return hit
    }
}

/// Resolves the `UIWindowScene` an in-app attaches to. Prefers a
/// foreground-active application scene, then any active scene, then any
/// application scene — steering clear of CarPlay / external-display scenes.
/// Shared by the shared-window and PiP presenters so the choice lives in one place.
enum PWInAppScene {
    static func active() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive && $0.session.role == .windowApplication }) {
            return scene
        }
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return scene
        }
        if let scene = scenes.first(where: { $0.session.role == .windowApplication }) {
            return scene
        }
        return scenes.first
    }

    static func hasForegroundActive() -> Bool {
        return UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive }
    }
}
#endif
