//
//  PWInAppPresenting.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import Foundation

/// Abstraction over the in-app presenter so the default UI can be swapped in
/// tests or by an advanced host. `PushwooshInAppUI` is the shipped implementation.
protocol PWInAppPresenting: AnyObject {
    func present(_ message: PWInAppMessageModel)
}
#endif
