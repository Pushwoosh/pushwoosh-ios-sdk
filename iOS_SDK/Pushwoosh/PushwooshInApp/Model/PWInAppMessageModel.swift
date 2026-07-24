//
//  PWInAppMessageModel.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Typed in-app message — a layout discriminator plus its decoded content.
/// Mirrors the Braze "enum with associated values" model: each case carries a
/// dedicated content struct, so adding a new template is one new case + one new
/// view, with no untyped dictionary access leaking into the UI layer.
enum PWInAppLayout {
    case modal(PWInAppModalContent)
    case sheet(PWInAppSheetContent)
    case carousel(PWInAppCarouselContent)
    case stories(PWInAppStoriesContent)
    case banner(PWInAppBannerContent)
    case fullscreen(PWInAppFullscreenContent)
    case video(PWInAppVideoContent)
    case pip(PWInAppPipContent)
    case scratchCard(PWInAppScratchCardContent)
    case spinWheel(PWInAppSpinWheelContent)
}

struct PWInAppMessageModel {
    let id: String?
    let layout: PWInAppLayout
    /// Max times this `id` may ever be shown (nil = unlimited). Opt-in via config.
    let maxDisplays: Int?
    /// Min seconds between two shows of this `id` (nil = none).
    let cooldown: TimeInterval?
    /// Drop the message if shown after this date (nil = never expires).
    let expireDate: Date?
    /// Fired when the message is actually displayed — Core hooks show
    /// statistics here for ZIP-delivered in-apps. Nil for manual `present()`.
    var onShown: (() -> Void)? = nil
    var onClicked: (() -> Void)? = nil
    var onClosed: (() -> Void)? = nil
}

/// A piece of styled text (label + optional color).
struct PWInAppText {
    let text: String
    let color: UIColor?
}

/// What happens when an element is tapped.
enum PWInAppAction {
    case url(URL)
    case close
}

/// Contract `Button`: every field is required — one render path, no positional
/// heuristics. `spinButton`/`revealButton` are the same shape without `action`
/// (their behavior is built in; the parser stores `.close` there).
struct PWInAppButton {
    let text: PWInAppText
    let backgroundColor: UIColor
    let borderColor: UIColor
    let cornerRadius: CGFloat
    let action: PWInAppAction
}

struct PWInAppModalContent {
    let backgroundColor: UIColor
    let title: PWInAppText?
    let message: PWInAppText?
    let imageURL: URL?
    let showCloseButton: Bool
    let buttons: [PWInAppButton]
    /// `true` dims the backdrop (solid 60% black) and blocks the app until the
    /// modal is dismissed; a tap outside the card also dismisses it. `false`
    /// floats the card with no backdrop and lets the rest of the UI stay
    /// interactive (dismiss via close button or an action).
    let dimsBackground: Bool
}

/// Bottom sheet — slides up from the bottom edge with a grabber, drag-to-dismiss
/// and auto height. The iOS-native middle ground between the compact banner and
/// the centered modal; mirrors Braze / CleverTap "half interstitial".
struct PWInAppSheetContent {
    let backgroundColor: UIColor
    let title: PWInAppText?
    let message: PWInAppText?
    let imageURL: URL?
    let showCloseButton: Bool
    let buttons: [PWInAppButton]
    /// `true` (default) dims the backdrop and blocks the app until dismissed.
    /// `false` floats the sheet, the app above stays interactive.
    let dimsBackground: Bool
}

struct PWInAppCarouselContent {
    let items: [PWInAppCarouselItem]
    let showCloseButton: Bool
}

struct PWInAppCarouselItem {
    let imageURL: URL?
    let title: PWInAppText?
    /// Contract key `message`.
    let subtitle: PWInAppText?
    let action: PWInAppAction?
}

/// Full-screen, Instagram-style "stories": tap-through pages with segmented
/// progress bars and auto-advance — mirrors the Push Stories notification UI.
struct PWInAppStoriesContent {
    let items: [PWInAppStoryItem]
    let loops: Bool
    let showCloseButton: Bool
}

struct PWInAppStoryItem {
    static let maxDuration: TimeInterval = 30

    let imageURL: URL?
    let title: PWInAppText?
    /// Contract key `message`.
    let subtitle: PWInAppText?
    /// CTA buttons at the bottom of the slide; may be empty.
    let buttons: [PWInAppButton]
    let duration: TimeInterval
}

/// Compact, non-blocking bar pinned to the top or bottom edge — mirrors
/// CleverTap's header/footer templates. Slides in, optionally auto-dismisses,
/// and lets touches outside the bar pass through to the app.
struct PWInAppBannerContent {
    enum Position {
        case top
        case bottom
    }

    let position: Position
    let imageURL: URL?
    let title: PWInAppText?
    let message: PWInAppText?
    let backgroundColor: UIColor
    let action: PWInAppAction
    /// Seconds before the banner auto-dismisses. `0` keeps it until dismissed.
    let autoDismiss: TimeInterval
    let showCloseButton: Bool
}

/// Edge-to-edge takeover — full-bleed image with overlaid title, message and
/// buttons. Mirrors CleverTap's cover / interstitial.
struct PWInAppFullscreenContent {
    /// Contract `cover.image` — optional picture over the background color.
    let imageURL: URL?
    /// Contract `cover.background` — surface color under/without the image.
    let backgroundColor: UIColor
    let title: PWInAppText?
    let message: PWInAppText?
    let buttons: [PWInAppButton]
    let showCloseButton: Bool
}

/// Full-screen autoplaying video — `AVPlayer` with a poster, mute/close, an
/// optional CTA, looping, and an image fallback. Mirrors CleverTap's
/// interstitial-video path (its draggable floating PiP is a separate, heavier
/// feature on top of the same player engine).
struct PWInAppVideoContent {
    let videoURL: URL
    let posterURL: URL?
    let fallbackImageURL: URL?
    let title: PWInAppText?
    let message: PWInAppText?
    /// CTA buttons at the bottom; may be empty.
    let buttons: [PWInAppButton]
    let loop: Bool
    let muted: Bool
    let showCloseButton: Bool
}

/// Floating, draggable picture-in-picture video that lives in its own window and
/// coexists with the app (touches outside it pass through). Mirrors CleverTap's
/// PiP. Reuses the same `PWInAppVideoPlayerView` engine as `.video`.
enum PWInAppPipPosition {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct PWInAppPipContent {
    let videoURL: URL
    let posterURL: URL?
    let fallbackImageURL: URL?
    let position: PWInAppPipPosition
    /// Collapsed width as a fraction of screen width (0...1), clamped 0.15–0.7.
    let widthFraction: CGFloat
    /// Height ÷ width of the collapsed card (default 0.5625 = 16:9 landscape).
    let aspectRatio: CGFloat
    let cornerRadius: CGFloat
    let loop: Bool
    let muted: Bool
    /// Tap action of the pip window itself; the window controls are system ones.
    let action: PWInAppAction?
    let showCloseButton: Bool
}

/// Prize payload shared by the gamified templates (scratch card, spin wheel).
/// The outcome is predetermined by the campaign config — the client only plays
/// the reveal, so odds stay under server control and can't be replay-cheated.
struct PWInAppReward {
    let title: PWInAppText?
    let message: PWInAppText?
    /// Promo code shown after the reveal; tapping it copies to the pasteboard.
    let promoCode: String?
    /// Confirmation button with its own tap action.
    let button: PWInAppButton?
}

/// Scratch-off promo card — a foil layer the user erases with a finger to
/// reveal the reward underneath. Native counterpart of CleverTap's webview
/// scratch card: honors Reduce Motion, haptics on reveal, VoiceOver reveal.
struct PWInAppScratchCardContent {
    /// Matches the scratch feel competitors converged on (~55% erased).
    static let defaultRevealThreshold: CGFloat = 0.55

    let backgroundColor: UIColor?
    /// Two or more colors turn the card into a festive gradient surface.
    let backgroundGradient: [UIColor]?
    let title: PWInAppText?
    let message: PWInAppText?
    /// Image drawn on the foil. `nil` falls back to a silver gradient.
    let coverImageURL: URL?
    let coverColor: UIColor?
    /// Fraction of the foil (0.1–0.9) to erase before the card auto-reveals.
    let revealThreshold: CGFloat
    /// Optional "skip the gesture" button under the scratch area. Its action is
    /// built in (reveal), so the parser ignores any configured one.
    let revealButton: PWInAppButton?
    let reward: PWInAppReward
    let showCloseButton: Bool
}

struct PWInAppWheelSegment {
    let text: String
    let color: UIColor?
    let textColor: UIColor?
    /// Relative odds for the client-side fallback draw when the campaign does
    /// not predetermine `winIndex`. Ignored otherwise.
    let weight: Double
    /// Segment-specific prize. `nil` falls back to the wheel-level reward —
    /// a segment with neither is a "better luck next time" slice.
    let reward: PWInAppReward?
}

/// Fortune wheel — spins with tick haptics and decelerates onto the winning
/// segment, then collapses into the reward panel. The outcome is the campaign's
/// `winIndex` when present (server-controlled odds — something no webview
/// competitor offers), else a weighted client draw. One spin per presentation.
struct PWInAppSpinWheelContent {
    let backgroundColor: UIColor?
    /// Two or more colors turn the card into a festive gradient surface.
    let backgroundGradient: [UIColor]?
    let title: PWInAppText?
    let message: PWInAppText?
    /// 2–12 slices; the parser rejects anything outside that range.
    let segments: [PWInAppWheelSegment]
    let winIndex: Int
    /// Hub button in the wheel center. Its action is built in (spin).
    let spinButton: PWInAppButton
    /// Wheel-level fallback prize for segments without their own reward.
    let reward: PWInAppReward?
    /// Shown when the winning segment carries no reward at all.
    let loseTitle: PWInAppText?
    let showCloseButton: Bool
}

extension PWInAppMessageModel {
    /// Image URLs this message will render — prefetched before display so cards
    /// don't pop in blank.
    func imageURLs() -> [URL] {
        switch layout {
        case .modal(let content):
            return [content.imageURL].compactMap { $0 }
        case .sheet(let content):
            return [content.imageURL].compactMap { $0 }
        case .carousel(let content):
            return content.items.compactMap { $0.imageURL }
        case .stories(let content):
            return content.items.compactMap { $0.imageURL }
        case .banner(let content):
            return [content.imageURL].compactMap { $0 }
        case .fullscreen(let content):
            return [content.imageURL].compactMap { $0 }
        case .video(let content):
            return [content.posterURL, content.fallbackImageURL].compactMap { $0 }
        case .pip(let content):
            return [content.posterURL, content.fallbackImageURL].compactMap { $0 }
        case .scratchCard(let content):
            return [content.coverImageURL].compactMap { $0 }
        case .spinWheel:
            return []
        }
    }
}
#endif
