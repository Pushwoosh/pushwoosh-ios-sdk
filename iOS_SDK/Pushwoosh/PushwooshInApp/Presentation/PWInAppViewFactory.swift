//
//  PWInAppViewFactory.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Maps a typed layout to its concrete view. Adding a template type is one new
/// `case` here plus the view itself — the rest of the pipeline is type-agnostic.
enum PWInAppViewFactory {
    static func makeView(for layout: PWInAppLayout) -> PWInAppRenderable? {
        switch layout {
        case .modal(let content):
            return PWModalInAppView(content: content)
        case .sheet(let content):
            return PWSheetInAppView(content: content)
        case .carousel(let content):
            return PWCarouselInAppView(content: content)
        case .stories(let content):
            return PWStoriesInAppView(content: content)
        case .banner(let content):
            return PWBannerInAppView(content: content)
        case .fullscreen(let content):
            return PWFullscreenInAppView(content: content)
        case .video(let content):
            return PWVideoInAppView(content: content)
        case .pip:
            // PiP runs in its own floating window via PWInAppPipController; the
            // presenter routes it before reaching the factory, so this is unreachable.
            return nil
        case .scratchCard(let content):
            return PWScratchCardInAppView(content: content)
        case .spinWheel(let content):
            return PWSpinWheelInAppView(content: content)
        }
    }
}
#endif
