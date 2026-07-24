//
//  PWInAppViewController.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Root controller of the in-app window. Hosts the active in-app view; keeps its
/// own view transparent so non-covered areas stay see-through.
final class PWInAppViewController: UIViewController {

    override func loadView() {
        let container = UIView()
        container.backgroundColor = .clear
        view = container
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Frame-based PiP cards don't reflow on their own; nudge them to the new
        // bounds. Auto-Layout-pinned views (modal/banner/etc.) need nothing here.
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            for case let pip as PWInAppPipContainerView in self.view.subviews {
                pip.relayout(in: self.view)
            }
        })
    }
}
#endif
