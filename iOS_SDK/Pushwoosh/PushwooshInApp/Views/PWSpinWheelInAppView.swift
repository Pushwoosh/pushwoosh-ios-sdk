//
//  PWSpinWheelInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 02.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Fortune wheel. Segments render into a single image (rotating one layer stays
//  smooth at any slice count); the spin is a predetermined deceleration onto the
//  server-chosen `winIndex` with light haptic ticks on every segment boundary,
//  then the wheel collapses into the shared reward panel. One spin per
//  presentation. Reduce Motion shortens the spin to a brief settle.
//
//  The backdrop does not close on tap — same reasoning as the scratch card: a
//  game in progress must not be lost to a stray touch.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWSpinWheelInAppView: UIView, PWInAppRenderable, PWInAppRewardReporting {

    private enum Metrics {
        static let maxCardWidth: CGFloat = 400
        static let sideInset: CGFloat = 28
        static let textInset: CGFloat = 24
        static let wheelInset: CGFloat = 30
        static let hubSize: CGFloat = 72
        static let pointerSize: CGFloat = 26
        static let closeInset: CGFloat = 16
        // The 4+s long-tail deceleration is the feel the webview competitors
        // converged on; ours adds the haptic ticks they can't do.
        static let spinDuration: TimeInterval = 4.2
        static let fullTurns: CGFloat = 5
    }

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?
    var onRewardRevealed: ((String?) -> Void)?
    var onRewardClaimed: ((String) -> Void)?

    private let content: PWInAppSpinWheelContent
    private var backdrop: UIView?
    private var card: UIView!
    private var wheelContainer: UIView!
    private var wheelImageView: PWWheelCanvasView!
    private var hubButton: UIButton!
    private var rewardView: PWInAppRewardView!
    private var tickLink: CADisplayLink?
    private var lastTickSlot: Int = 0
    private var spun = false

    private static let defaultPalette: [UIColor] = [
        .systemIndigo, .systemPink, .systemTeal,
        .systemOrange, .systemPurple, .systemGreen,
    ]

    /// Prize of the winning segment: its own reward, else the wheel-level one,
    /// else a synthesized "no win" panel built from `loseTitle`.
    private var resolvedReward: PWInAppReward {
        if let own = content.segments[content.winIndex].reward {
            return own
        }
        if let fallback = content.reward {
            return fallback
        }
        return PWInAppReward(
            title: content.loseTitle ?? PWInAppText(text: "Better luck next time!", color: nil),
            message: nil, promoCode: nil, button: nil)
    }

    init(content: PWInAppSpinWheelContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        tickLink?.invalidate()
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
                                           bottom: Metrics.textInset, right: Metrics.textInset)
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
        stack.addArrangedSubview(makeWheel())

        rewardView = PWInAppRewardView(reward: resolvedReward, onBackground: cardBase)
        rewardView.onCopy = { [weak self] code in
            self?.onRewardClaimed?(code)
        }
        rewardView.onAction = { [weak self] action in
            self?.onAction?(action)
        }
        rewardView.isHidden = true
        rewardView.alpha = 0
        stack.addArrangedSubview(rewardView)

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

        // The backdrop is inert and spinning only reveals the prize — neither
        // dismisses. The only ways out are the close chip and the resolved
        // reward's action button, so with no such button the chip must always show.
        let hasGuaranteedDismissPath = resolvedReward.button != nil
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

    private func makeWheel() -> UIView {
        wheelContainer = UIView()
        wheelContainer.heightAnchor.constraint(equalTo: wheelContainer.widthAnchor).isActive = true

        wheelImageView = PWWheelCanvasView()
        wheelImageView.onSideChange = { [weak self] side in
            self?.renderWheelIfNeeded(side: side)
        }
        wheelImageView.translatesAutoresizingMaskIntoConstraints = false
        wheelContainer.addSubview(wheelImageView)

        let pointer = makePointer()
        pointer.translatesAutoresizingMaskIntoConstraints = false
        wheelContainer.addSubview(pointer)

        hubButton = UIButton(type: .system)
        hubButton.setTitle(content.spinButton.text.text, for: .normal)
        hubButton.titleLabel?.font = PWInAppStyle.rounded(17, .heavy)
        hubButton.setTitleColor(content.spinButton.text.color ?? .label, for: .normal)
        hubButton.backgroundColor = content.spinButton.backgroundColor
        hubButton.layer.borderColor = content.spinButton.borderColor.cgColor
        hubButton.layer.borderWidth = 2
        hubButton.layer.cornerRadius = Metrics.hubSize / 2
        hubButton.layer.shadowColor = UIColor.black.cgColor
        hubButton.layer.shadowOpacity = 0.25
        hubButton.layer.shadowRadius = 8
        hubButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        hubButton.accessibilityLabel = "Spin the wheel"
        hubButton.addTarget(self, action: #selector(spinTapped), for: .touchUpInside)
        hubButton.translatesAutoresizingMaskIntoConstraints = false
        wheelContainer.addSubview(hubButton)

        NSLayoutConstraint.activate([
            wheelImageView.topAnchor.constraint(equalTo: wheelContainer.topAnchor, constant: Metrics.wheelInset),
            wheelImageView.bottomAnchor.constraint(equalTo: wheelContainer.bottomAnchor, constant: -Metrics.wheelInset),
            wheelImageView.leadingAnchor.constraint(equalTo: wheelContainer.leadingAnchor, constant: Metrics.wheelInset),
            wheelImageView.trailingAnchor.constraint(equalTo: wheelContainer.trailingAnchor, constant: -Metrics.wheelInset),

            pointer.centerXAnchor.constraint(equalTo: wheelContainer.centerXAnchor),
            pointer.topAnchor.constraint(equalTo: wheelContainer.topAnchor, constant: 4),
            pointer.widthAnchor.constraint(equalToConstant: Metrics.pointerSize),
            pointer.heightAnchor.constraint(equalToConstant: Metrics.pointerSize),

            hubButton.centerXAnchor.constraint(equalTo: wheelImageView.centerXAnchor),
            hubButton.centerYAnchor.constraint(equalTo: wheelImageView.centerYAnchor),
            hubButton.widthAnchor.constraint(equalToConstant: Metrics.hubSize),
            hubButton.heightAnchor.constraint(equalToConstant: Metrics.hubSize),
        ])
        return wheelContainer
    }

    private func makePointer() -> UIView {
        let pointer = UIView()
        let shape = CAShapeLayer()
        let size = Metrics.pointerSize
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: size, y: 0))
        path.addLine(to: CGPoint(x: size / 2, y: size))
        path.close()
        shape.path = path.cgPath
        shape.fillColor = UIColor.label.cgColor
        shape.shadowColor = UIColor.black.cgColor
        shape.shadowOpacity = 0.3
        shape.shadowRadius = 3
        shape.shadowOffset = CGSize(width: 0, height: 2)
        pointer.layer.addSublayer(shape)
        return pointer
    }

    private func renderWheelIfNeeded(side: CGFloat) {
        guard side > 0, wheelImageView.image?.size.width != side else {
            return
        }
        wheelImageView.image = renderWheelImage(side: side)
    }

    /// Draws all segments and labels into one image — segment 0 starts at the
    /// top (pointer position) and slices proceed clockwise.
    private func renderWheelImage(side: CGFloat) -> UIImage {
        let segmentAngle = 2 * CGFloat.pi / CGFloat(content.segments.count)
        let radius = side / 2
        let center = CGPoint(x: radius, y: radius)

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            for (index, segment) in content.segments.enumerated() {
                let start = -CGFloat.pi / 2 + CGFloat(index) * segmentAngle
                let fill = segment.color ?? Self.defaultPalette[index % Self.defaultPalette.count]
                let path = UIBezierPath()
                path.move(to: center)
                path.addArc(withCenter: center, radius: radius,
                            startAngle: start, endAngle: start + segmentAngle, clockwise: true)
                path.close()
                fill.setFill()
                path.fill()

                UIColor.white.withAlphaComponent(0.35).setStroke()
                path.lineWidth = 1
                path.stroke()

                drawLabel(segment, at: start + segmentAngle / 2, fill: fill,
                          center: center, radius: radius, cgContext: context.cgContext)
            }
        }
    }

    private func drawLabel(_ segment: PWInAppWheelSegment, at angle: CGFloat, fill: UIColor,
                           center: CGPoint, radius: CGFloat, cgContext: CGContext) {
        let text = segment.text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: PWInAppStyle.rounded(14, .bold),
            .foregroundColor: segment.textColor ?? PWInAppStyle.contrastColor(on: fill),
        ]
        let size = text.size(withAttributes: attributes)

        cgContext.saveGState()
        cgContext.translateBy(x: center.x, y: center.y)
        cgContext.rotate(by: angle)
        text.draw(at: CGPoint(x: radius * 0.55 - size.width / 2, y: -size.height / 2),
                  withAttributes: attributes)
        cgContext.restoreGState()
    }

    // MARK: - Spin

    @objc private func spinTapped() {
        guard !spun else {
            return
        }
        spun = true
        hubButton.isEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.hubButton.alpha = 0.35
        }

        let segmentAngle = 2 * CGFloat.pi / CGFloat(content.segments.count)
        let jitter = segmentAngle * 0.3 * CGFloat.random(in: -1...1)
        let winCenter = (CGFloat(content.winIndex) + 0.5) * segmentAngle
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let turns = reduceMotion ? 1 : Metrics.fullTurns
        let finalRotation = -(2 * .pi * turns) - winCenter + jitter
        let duration = reduceMotion ? 0.7 : Metrics.spinDuration

        if !reduceMotion {
            startTickHaptics(segmentAngle: segmentAngle)
        }

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.spinFinished()
        }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = finalRotation
        spin.duration = duration
        spin.timingFunction = CAMediaTimingFunction(controlPoints: 0.12, 0.64, 0.18, 1.0)
        wheelImageView.layer.add(spin, forKey: "pw.spin")
        wheelImageView.layer.setValue(finalRotation, forKeyPath: "transform.rotation.z")
        CATransaction.commit()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func startTickHaptics(segmentAngle: CGFloat) {
        lastTickSlot = 0
        // Weak proxy so the run loop's retain of the display link never keeps the
        // view alive (CADisplayLink retains its target strongly) — same reason as
        // PWStoriesInAppView.
        let link = CADisplayLink(target: PWSpinWheelDisplayLinkProxy(self),
                                 selector: #selector(PWSpinWheelDisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        tickLink = link
    }

    fileprivate func tickHaptics() {
        guard let rotation = wheelImageView.layer.presentation()?
            .value(forKeyPath: "transform.rotation.z") as? CGFloat else {
            return
        }
        let segmentAngle = 2 * CGFloat.pi / CGFloat(content.segments.count)
        let slot = Int(abs(rotation) / segmentAngle)
        if slot != lastTickSlot {
            lastTickSlot = slot
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        }
    }

    private func spinFinished() {
        tickLink?.invalidate()
        tickLink = nil
        let reward = resolvedReward
        let won = reward.promoCode != nil || content.segments[content.winIndex].reward != nil
            || content.reward != nil
        UINotificationFeedbackGenerator().notificationOccurred(won ? .success : .warning)
        if won {
            PWInAppConfetti.burst(in: card, colors: content.segments.compactMap { $0.color })
        }

        if let announcement = reward.title?.text ?? reward.promoCode {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        onRewardRevealed?(reward.promoCode)

        // The dramatic beat before the prize — the wheel rests on the winning
        // slice long enough to be read.
        let pause: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0.4 : 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { [weak self] in
            self?.collapseWheelIntoReward()
        }
    }

    // The wheel leaves the stack entirely: hiding it in place would keep its
    // required square-aspect constraint alive against the stack's zero-height
    // hiding constraint, and the solver resolves that conflict by crushing the
    // card's width.
    private func collapseWheelIntoReward() {
        let reduce = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduce ? 0.15 : 0.25, animations: {
            self.wheelContainer.alpha = 0
        }, completion: { _ in
            self.wheelContainer.removeFromSuperview()
            self.rewardView.isHidden = false
            self.rewardView.alpha = 0
            UIView.animate(withDuration: reduce ? 0.15 : 0.3, animations: {
                self.rewardView.alpha = 1
                self.layoutIfNeeded()
            }, completion: { _ in
                self.rewardView.celebrate()
            })
        })
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
        tickLink?.invalidate()
        tickLink = nil
        PWInAppStyle.animateOut(card: card, backdrop: backdrop ?? self) {
            self.removeFromSuperview()
            completion()
        }
    }
}

/// Image view that reports its own size changes — the wheel bitmap can only be
/// rendered once the real side length is known, and a deep descendant getting
/// its bounds does not re-run any ancestor's `layoutSubviews`.
private final class PWWheelCanvasView: UIImageView {
    var onSideChange: ((CGFloat) -> Void)?

    override var bounds: CGRect {
        didSet {
            if bounds.size != oldValue.size {
                onSideChange?(bounds.width)
            }
        }
    }
}

/// Weak forwarder for the tick `CADisplayLink` so the run loop never retains the
/// spin-wheel view through the link's strong target reference.
final class PWSpinWheelDisplayLinkProxy: NSObject {
    private weak var owner: PWSpinWheelInAppView?

    init(_ owner: PWSpinWheelInAppView) {
        self.owner = owner
    }

    @objc func tick() {
        owner?.tickHaptics()
    }
}
#endif
