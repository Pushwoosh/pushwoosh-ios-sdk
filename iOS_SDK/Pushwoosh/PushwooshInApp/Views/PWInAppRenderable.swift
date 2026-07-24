//
//  PWInAppRenderable.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// A self-contained in-app view. The presenter wires `onClose`/`onAction`, adds
/// the view to its window container, and drives present/dismiss — the view owns
/// only its own layout and animation. Each template type implements this once.
protocol PWInAppRenderable: UIView {
    var onClose: (() -> Void)? { get set }
    var onAction: ((PWInAppAction) -> Void)? { get set }

    func present(in container: UIView)
    func dismiss(completion: @escaping () -> Void)
}
#endif
