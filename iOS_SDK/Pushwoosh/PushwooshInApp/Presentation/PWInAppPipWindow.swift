//
//  PWInAppPipWindow.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Dedicated window the floating PiP lives in so it persists across the host
//  app's navigation. Touches that miss the PiP card are forwarded to the app's
//  own windows — without this the transparent full-screen window would deaden
//  the UI behind it (ported from CleverTap's CTPiPPassThroughWindow).
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWInAppPipWindow: UIWindow {

    /// The PiP card. Only touches landing inside it are kept; everything else is
    /// forwarded to the app.
    weak var contentView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if let hit = hit, let content = contentView, hit.isDescendant(of: content) {
            return hit
        }

        // Forward to the app's own windows (handles the iPad scene quirk where a
        // nil hitTest isn't auto-forwarded).
        let windows = windowScene?.windows ?? []
        for window in windows.reversed() where window !== self && !window.isHidden && window.alpha > 0.01 {
            if let view = window.hitTest(window.convert(point, from: self), with: event) {
                return view
            }
        }
        return nil
    }
}
#endif
