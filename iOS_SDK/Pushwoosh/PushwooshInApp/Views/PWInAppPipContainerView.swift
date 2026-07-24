//
//  PWInAppPipContainerView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  The floating PiP card: a rounded video tile that can be dragged around and
//  snaps to the nearest corner, expands to full screen and back, with close /
//  mute / expand controls and a tap-to-act CTA. Frame-based (it moves and
//  resizes), with the player + controls laid out by Auto Layout inside it.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWInAppPipContainerView: UIView, UIGestureRecognizerDelegate {

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private static let controlSize: CGFloat = 26

    private let content: PWInAppPipContent
    private let playerView = PWInAppVideoPlayerView()
    private let closeButton = PWInAppChipButton(size: controlSize)
    private let muteButton = PWInAppChipButton(size: controlSize)
    private let expandButton = PWInAppChipButton(size: controlSize)
    private var clipView: UIView!

    private var isExpanded = false
    private var collapsedFrame: CGRect = .zero
    private let edgeMargin: CGFloat = 14

    init(content: PWInAppPipContent) {
        self.content = content
        super.init(frame: .zero)
        // Shadow on self (no clipping); the rounded corners live on the inner
        // `clip` wrapper. self stays clear so no square peeks behind the radius.
        backgroundColor = .clear
        clipsToBounds = false
        PWInAppStyle.applyCardShadow(self)
        buildUI()
        setupGestures()

        playerView.onFailed = { [weak self] in
            self?.onClose?()
        }
        playerView.configure(videoURL: content.videoURL,
                             posterURL: content.posterURL,
                             fallbackImageURL: content.fallbackImageURL,
                             loop: content.loop,
                             muted: content.muted)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        // A clipping wrapper keeps rounded corners while the card layer keeps its shadow.
        let clip = UIView()
        clipView = clip
        clip.layer.cornerRadius = content.cornerRadius
        clip.layer.cornerCurve = .continuous
        clip.clipsToBounds = true
        clip.backgroundColor = .black
        clip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clip)

        playerView.translatesAutoresizingMaskIntoConstraints = false
        clip.addSubview(playerView)

        configureControl(closeButton, symbol: "xmark", label: "Close", action: #selector(closeTapped))
        configureControl(muteButton, symbol: content.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                         label: content.muted ? "Unmute" : "Mute", action: #selector(muteTapped))
        configureControl(expandButton, symbol: "arrow.up.left.and.arrow.down.right",
                         label: "Expand", action: #selector(expandTapped))
        clip.addSubview(closeButton)
        clip.addSubview(muteButton)
        clip.addSubview(expandButton)

        NSLayoutConstraint.activate([
            clip.topAnchor.constraint(equalTo: topAnchor),
            clip.bottomAnchor.constraint(equalTo: bottomAnchor),
            clip.leadingAnchor.constraint(equalTo: leadingAnchor),
            clip.trailingAnchor.constraint(equalTo: trailingAnchor),

            playerView.topAnchor.constraint(equalTo: clip.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: clip.trailingAnchor),

            // Pinned to the safe-area guide, not the raw edges: collapsed the card
            // sits inside the safe area (insets 0 → flush to edges), expanded it
            // fills the screen so the controls stay clear of the notch / home bar.
            closeButton.topAnchor.constraint(equalTo: clip.safeAreaLayoutGuide.topAnchor, constant: 6),
            closeButton.trailingAnchor.constraint(equalTo: clip.safeAreaLayoutGuide.trailingAnchor, constant: -6),

            muteButton.bottomAnchor.constraint(equalTo: clip.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            muteButton.trailingAnchor.constraint(equalTo: clip.safeAreaLayoutGuide.trailingAnchor, constant: -6),

            expandButton.bottomAnchor.constraint(equalTo: clip.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            expandButton.leadingAnchor.constraint(equalTo: clip.safeAreaLayoutGuide.leadingAnchor, constant: 6),
        ])
    }

    private func configureControl(_ button: PWInAppChipButton, symbol: String, label: String, action: Selector) {
        button.setSymbol(symbol, pointSize: 11)
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view is UIControl)
    }

    // MARK: - Placement

    func place(in parent: UIView) {
        reposition(in: parent)

        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    /// Computes the collapsed corner frame for the parent's current size.
    private func reposition(in parent: UIView) {
        let width = parent.bounds.width * content.widthFraction
        let height = width * content.aspectRatio
        let insets = parent.safeAreaInsets

        let x: CGFloat
        let y: CGFloat
        switch content.position {
        case .topLeft:
            x = insets.left + edgeMargin
            y = insets.top + edgeMargin
        case .topRight:
            x = parent.bounds.width - insets.right - edgeMargin - width
            y = insets.top + edgeMargin
        case .bottomLeft:
            x = insets.left + edgeMargin
            y = parent.bounds.height - insets.bottom - edgeMargin - height
        case .bottomRight:
            x = parent.bounds.width - insets.right - edgeMargin - width
            y = parent.bounds.height - insets.bottom - edgeMargin - height
        }

        collapsedFrame = CGRect(x: x, y: y, width: width, height: height)
        frame = collapsedFrame
    }

    /// Re-applies placement after a rotation / size change: expanded fills the new
    /// bounds, collapsed re-derives its corner frame so the card never strands
    /// off-screen with a frame captured before the transition.
    func relayout(in parent: UIView) {
        if isExpanded {
            frame = parent.bounds
            clipView.layer.cornerRadius = 0
        } else {
            reposition(in: parent)
        }
    }

    // MARK: - Drag + snap

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isExpanded, let parent = superview else { return }
        let translation = gesture.translation(in: parent)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: parent)

        if gesture.state == .ended || gesture.state == .cancelled {
            snapToNearestCorner(in: parent)
        }
    }

    private func snapToNearestCorner(in parent: UIView) {
        let insets = parent.safeAreaInsets
        let size = bounds.size
        let left = insets.left + edgeMargin + size.width / 2
        let right = parent.bounds.width - insets.right - edgeMargin - size.width / 2
        let top = insets.top + edgeMargin + size.height / 2
        let bottom = parent.bounds.height - insets.bottom - edgeMargin - size.height / 2

        let corners = [
            CGPoint(x: left, y: top),
            CGPoint(x: right, y: top),
            CGPoint(x: left, y: bottom),
            CGPoint(x: right, y: bottom),
        ]
        let target = corners.min { a, b in
            hypot(a.x - center.x, a.y - center.y) < hypot(b.x - center.x, b.y - center.y)
        } ?? center

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            self.center = target
        } completion: { _ in
            self.collapsedFrame = self.frame
        }
    }

    // MARK: - Actions

    @objc private func handleTap() {
        if let action = content.action {
            onAction?(action)
        } else {
            toggleExpand()
        }
    }

    @objc private func expandTapped() {
        toggleExpand()
    }

    private func toggleExpand() {
        guard let parent = superview else { return }
        isExpanded.toggle()

        let symbol = isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        expandButton.setSymbol(symbol, pointSize: 11)
        expandButton.accessibilityLabel = isExpanded ? "Collapse" : "Expand"

        let targetFrame = isExpanded ? parent.bounds : collapsedFrame
        let targetRadius: CGFloat = isExpanded ? 0 : content.cornerRadius

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.3, options: [.allowUserInteraction]) {
            self.frame = targetFrame
            self.clipView.layer.cornerRadius = targetRadius
            self.layoutIfNeeded()
        }
    }

    @objc private func muteTapped() {
        playerView.setMuted(!playerView.isMuted)
        let symbol = playerView.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.setSymbol(symbol, pointSize: 11)
        muteButton.accessibilityLabel = playerView.isMuted ? "Unmute" : "Mute"
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: - Lifecycle

    func teardown() {
        playerView.teardown()
    }
}
#endif
