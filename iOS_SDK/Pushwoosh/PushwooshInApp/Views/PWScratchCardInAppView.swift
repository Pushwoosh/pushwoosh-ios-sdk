//
//  PWScratchCardInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 02.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Scratch-off promo card. The reward panel sits under a foil layer (campaign
//  image or a silver gradient); finger strokes erase the foil through a mask,
//  and once the configured fraction is cleared the card auto-reveals with a
//  success haptic and a confetti burst. Native counterpart of CleverTap's
//  webview scratch card: no canvas JS, Reduce Motion honored, VoiceOver users
//  get a double-tap reveal instead of the gesture.
//
//  The backdrop deliberately does NOT close on tap — a stray touch while
//  scratching must not dismiss the game. Close is explicit: chip or CTA.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWScratchCardInAppView: UIView, PWInAppRenderable, PWInAppRewardReporting {

    private enum Metrics {
        static let maxCardWidth: CGFloat = 400
        static let sideInset: CGFloat = 28
        static let textInset: CGFloat = 24
        static let areaInset: CGFloat = 16
        static let areaAspect: CGFloat = 0.62
        static let areaCornerRadius: CGFloat = 18
        static let strokeWidth: CGFloat = 46
        static let closeInset: CGFloat = 16
        // Fixed light "ticket" under the foil — never theme-adaptive, so the
        // campaign's reward colors read the same on every device.
        static let ticketColor = UIColor(white: 0.97, alpha: 1)
    }

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?
    var onRewardRevealed: ((String?) -> Void)?
    var onRewardClaimed: ((String) -> Void)?

    private let content: PWInAppScratchCardContent
    private var backdrop: UIView?
    private var card: UIView!
    private var foil: UIView!
    private var scratchMask: PWScratchMaskView!
    private var scratchArea: UIView!
    private var rewardView: PWInAppRewardView!
    private var revealed = false

    init(content: PWInAppScratchCardContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Non-blocking like a banner: touches outside the card pass through to the
    // host app; only the card is interactive.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    private func buildUI() {
        let backdrop = PWInAppStyle.makeBackdrop()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        self.backdrop = backdrop

        let contentHost: UIView
        if let gradientColors = content.backgroundGradient {
            let (surface, host) = PWInAppStyle.makeGradientSurface(
                colors: gradientColors, cornerRadius: PWInAppStyle.cardCornerRadius)
            card = surface
            contentHost = host
        } else {
            let background = content.backgroundColor ?? .systemBackground
            let (surface, host, isGlass) = PWInAppStyle.makeSurface(
                glassTint: background.withAlphaComponent(0.55),
                solidColor: background,
                cornerRadius: PWInAppStyle.cardCornerRadius)
            if !isGlass {
                PWInAppStyle.applyCardShadow(surface)
            }
            card = surface
            contentHost = host
        }
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 28, left: Metrics.textInset,
                                           bottom: Metrics.areaInset, right: Metrics.textInset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(stack)

        let cardBase = content.backgroundGradient?.first ?? content.backgroundColor
        let cardText = cardBase.map { PWInAppStyle.contrastColor(on: $0) }
        if let title = content.title {
            stack.addArrangedSubview(PWInAppStyle.makeLabel(
                title, font: PWInAppStyle.rounded(24, .heavy),
                fallback: cardText ?? .label, alignment: .center))
        }
        if let message = content.message {
            stack.addArrangedSubview(PWInAppStyle.makeLabel(
                message, font: PWInAppStyle.rounded(15, .regular),
                fallback: cardText?.withAlphaComponent(0.72) ?? .secondaryLabel, alignment: .center))
        }
        stack.addArrangedSubview(makeScratchArea())

        if let revealModel = content.revealButton {
            let reveal = PWInAppStyle.makeContractButton(revealModel)
            reveal.addTarget(self, action: #selector(revealTapped), for: .touchUpInside)
            stack.addArrangedSubview(reveal)
        }

        let fillWidth = card.widthAnchor.constraint(equalTo: widthAnchor,
                                                    constant: -Metrics.sideInset * 2)
        fillWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.maxCardWidth),
            fillWidth,

            stack.topAnchor.constraint(equalTo: contentHost.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
        ])

        // The backdrop is inert by design and revealing only shows the prize —
        // neither dismisses. The only ways out are the close chip and the reward's
        // action button, so with no reward button the chip must always show.
        let hasGuaranteedDismissPath = content.reward.button != nil
        if content.showCloseButton || !hasGuaranteedDismissPath {
            let close = PWInAppStyle.makeCloseButton()
            contentHost.addSubview(close)
            close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            NSLayoutConstraint.activate([
                close.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: Metrics.closeInset),
                close.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor, constant: -Metrics.closeInset),
            ])
        }
    }

    private func makeScratchArea() -> UIView {
        let area = PWScratchAreaView()
        area.onAccessibilityActivate = { [weak self] in
            self?.reveal()
        }
        area.layer.cornerRadius = Metrics.areaCornerRadius
        area.layer.cornerCurve = .continuous
        area.clipsToBounds = true
        area.backgroundColor = Metrics.ticketColor
        area.heightAnchor.constraint(equalTo: area.widthAnchor,
                                     multiplier: Metrics.areaAspect).isActive = true

        rewardView = PWInAppRewardView(reward: content.reward, onBackground: Metrics.ticketColor)
        rewardView.onCopy = { [weak self] code in
            self?.onRewardClaimed?(code)
        }
        rewardView.onAction = { [weak self] action in
            self?.onAction?(action)
        }
        rewardView.translatesAutoresizingMaskIntoConstraints = false
        area.addSubview(rewardView)
        NSLayoutConstraint.activate([
            rewardView.centerYAnchor.constraint(equalTo: area.centerYAnchor),
            rewardView.leadingAnchor.constraint(equalTo: area.leadingAnchor, constant: Metrics.areaInset),
            rewardView.trailingAnchor.constraint(equalTo: area.trailingAnchor, constant: -Metrics.areaInset),
        ])

        foil = makeFoil()
        foil.translatesAutoresizingMaskIntoConstraints = false
        area.addSubview(foil)
        NSLayoutConstraint.activate([
            foil.topAnchor.constraint(equalTo: area.topAnchor),
            foil.bottomAnchor.constraint(equalTo: area.bottomAnchor),
            foil.leadingAnchor.constraint(equalTo: area.leadingAnchor),
            foil.trailingAnchor.constraint(equalTo: area.trailingAnchor),
        ])

        scratchMask = PWScratchMaskView()
        scratchMask.strokeWidth = Metrics.strokeWidth

        let pan = UIPanGestureRecognizer(target: self, action: #selector(scratchPan(_:)))
        pan.maximumNumberOfTouches = 1
        area.addGestureRecognizer(pan)

        area.isAccessibilityElement = true
        area.accessibilityLabel = "Scratch card. Double tap to reveal your reward."
        area.accessibilityTraits = .button

        scratchArea = area
        return area
    }

    private func makeFoil() -> UIView {
        if let imageURL = content.coverImageURL {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = content.coverColor ?? .systemGray3
            PWInAppImageLoader.shared.load(imageURL, into: imageView)
            return imageView
        }

        let foil = PWFoilGradientView()
        foil.baseColor = content.coverColor
        let hintColor = PWInAppStyle.contrastColor(
            on: content.coverColor ?? UIColor(white: 0.78, alpha: 1)).withAlphaComponent(0.45)

        let hintIcon = UIImageView(image: UIImage(
            systemName: "hand.draw",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)))
        hintIcon.tintColor = hintColor

        let hintLabel = UILabel()
        hintLabel.text = "Scratch here"
        hintLabel.font = PWInAppStyle.rounded(14, .semibold)
        hintLabel.textColor = hintColor

        let hint = UIStackView(arrangedSubviews: [hintIcon, hintLabel])
        hint.axis = .vertical
        hint.spacing = 6
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        foil.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: foil.centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: foil.centerYAnchor),
        ])
        return foil
    }

    // MARK: - Scratching

    @objc private func scratchPan(_ recognizer: UIPanGestureRecognizer) {
        guard !revealed, let area = recognizer.view else {
            return
        }
        let point = recognizer.location(in: area)

        switch recognizer.state {
        case .began:
            // The mask attaches on first touch: a UIView mask with an empty
            // frame would hide the whole foil before the layout settles.
            scratchMask.frame = area.bounds
            if foil.mask == nil {
                foil.mask = scratchMask
            }
            scratchMask.beginStroke(at: point)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .changed:
            scratchMask.continueStroke(to: point)
            if scratchMask.scratchedFraction >= content.revealThreshold {
                reveal()
            }
        default:
            break
        }
    }

    @objc private func revealTapped() {
        reveal()
    }

    private func reveal() {
        guard !revealed else {
            return
        }
        revealed = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.45,
                       delay: 0,
                       options: [.curveEaseOut]) {
            self.foil.alpha = 0
        } completion: { _ in
            self.foil.isHidden = true
            self.glowScratchArea()
            self.rewardView.celebrate()
        }
        PWInAppConfetti.burst(in: card, colors: [])

        if let announcement = content.reward.title?.text ?? content.reward.promoCode {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        onRewardRevealed?(content.reward.promoCode)
    }

    private func glowScratchArea() {
        scratchArea.layer.borderColor = UIColor.systemYellow.withAlphaComponent(0.85).cgColor
        scratchArea.layer.borderWidth = 2.5
        let glow = CABasicAnimation(keyPath: "borderWidth")
        glow.fromValue = 0
        glow.toValue = 2.5
        glow.duration = UIAccessibility.isReduceMotionEnabled ? 0.15 : 0.4
        scratchArea.layer.add(glow, forKey: "pw.glow")
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: - PWInAppRenderable

    func present(in container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        container.layoutIfNeeded()
        PWInAppStyle.animateIn(card: card, backdrop: backdrop ?? self)
    }

    func dismiss(completion: @escaping () -> Void) {
        PWInAppStyle.animateOut(card: card, backdrop: backdrop ?? self) {
            self.removeFromSuperview()
            completion()
        }
    }
}

/// Scratch surface that exposes VoiceOver activation — the system double-tap
/// reveals the reward instead of requiring the scratch gesture.
final class PWScratchAreaView: UIView {
    var onAccessibilityActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        onAccessibilityActivate?()
        return true
    }
}

/// Alpha mask driven by finger strokes: opaque everywhere (foil visible), with
/// erased round-cap stroke lines. Coverage is tracked on a coarse grid — cheap
/// and stable, no pixel readbacks.
final class PWScratchMaskView: UIView {

    var strokeWidth: CGFloat = 46

    private(set) var scratchedFraction: CGFloat = 0

    private let path = UIBezierPath()
    private var grid = [Bool](repeating: false, count: gridColumns * gridRows)
    private static let gridColumns = 16
    private static let gridRows = 10
    private var lastPoint: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginStroke(at point: CGPoint) {
        path.move(to: point)
        lastPoint = point
        markGrid(at: point)
        setNeedsDisplay()
    }

    func continueStroke(to point: CGPoint) {
        guard let last = lastPoint else {
            beginStroke(at: point)
            return
        }
        path.addLine(to: point)

        let distance = hypot(point.x - last.x, point.y - last.y)
        let steps = max(1, Int(distance / (strokeWidth * 0.4)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            markGrid(at: CGPoint(x: last.x + (point.x - last.x) * t,
                                 y: last.y + (point.y - last.y) * t))
        }
        lastPoint = point
        setNeedsDisplay()
    }

    private func markGrid(at point: CGPoint) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }
        let cellWidth = bounds.width / CGFloat(Self.gridColumns)
        let cellHeight = bounds.height / CGFloat(Self.gridRows)
        let radius = strokeWidth / 2

        let minCol = max(0, Int((point.x - radius) / cellWidth))
        let maxCol = min(Self.gridColumns - 1, Int((point.x + radius) / cellWidth))
        let minRow = max(0, Int((point.y - radius) / cellHeight))
        let maxRow = min(Self.gridRows - 1, Int((point.y + radius) / cellHeight))
        guard minCol <= maxCol, minRow <= maxRow else {
            return
        }
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                grid[row * Self.gridColumns + col] = true
            }
        }
        let cleared = grid.lazy.filter { $0 }.count
        scratchedFraction = CGFloat(cleared) / CGFloat(grid.count)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.setFillColor(UIColor.black.cgColor)
        context.fill(bounds)

        context.setBlendMode(.clear)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path.cgPath)
        context.strokePath()
    }
}

/// Silver-foil gradient used when the campaign supplies no cover image. Every
/// stop is fully opaque — the reward must not shine through before scratching.
final class PWFoilGradientView: UIView {

    var baseColor: UIColor? {
        didSet { setNeedsLayout() }
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let gradient = layer as? CAGradientLayer else {
            return
        }
        let base = baseColor ?? UIColor(white: 0.78, alpha: 1)
        backgroundColor = base

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let sheen = UIColor(hue: hue, saturation: saturation,
                            brightness: min(brightness + 0.12, 1), alpha: 1)
        let shade = UIColor(hue: hue, saturation: saturation,
                            brightness: max(brightness - 0.10, 0), alpha: 1)
        gradient.colors = [shade.cgColor, sheen.cgColor, shade.cgColor, sheen.cgColor]
        gradient.locations = [0, 0.35, 0.7, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
    }
}
#endif
