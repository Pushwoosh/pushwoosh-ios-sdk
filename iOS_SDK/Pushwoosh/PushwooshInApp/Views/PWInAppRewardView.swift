//
//  PWInAppRewardView.swift
//  PushwooshInApp
//
//  Created by André Kis on 02.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  The prize panel shared by the gamified templates: reward title/message, a
//  dashed promo-code chip that copies on tap (with haptic + "Copied!" feedback),
//  and an optional CTA button. The hosting view reveals it after the game is
//  played (foil scratched off / wheel stopped).
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Implemented by game templates so the presenter can route reward lifecycle
/// (prize revealed, promo code copied) to the public delegate — analytics no
/// webview-based competitor emits.
protocol PWInAppRewardReporting: AnyObject {
    /// The game finished and the prize (promo code, if any) is on screen.
    var onRewardRevealed: ((String?) -> Void)? { get set }
    /// The user copied the promo code.
    var onRewardClaimed: ((String) -> Void)? { get set }
}

final class PWInAppRewardView: UIView {

    private enum Metrics {
        static let codeChipHeight: CGFloat = 48
        static let buttonHeight: CGFloat = 52
        static let copyResetDelay: TimeInterval = 1.6
    }

    var onCopy: ((String) -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let reward: PWInAppReward
    private var codeLabel: UILabel?
    private let primaryFallback: UIColor
    private let secondaryFallback: UIColor
    private let chipBackground: UIColor

    /// `background` is the surface the panel sits on. A known campaign color
    /// yields deterministic contrast fallbacks; `nil` keeps system-adaptive
    /// defaults for system surfaces.
    init(reward: PWInAppReward, onBackground background: UIColor? = nil) {
        self.reward = reward
        if let background {
            let contrast = PWInAppStyle.contrastColor(on: background)
            primaryFallback = contrast
            secondaryFallback = contrast.withAlphaComponent(0.72)
            chipBackground = PWInAppStyle.isLightSurface(background)
                ? UIColor.black.withAlphaComponent(0.06)
                : UIColor.white.withAlphaComponent(0.16)
        } else {
            primaryFallback = .label
            secondaryFallback = .secondaryLabel
            chipBackground = .secondarySystemFill
        }
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        if let title = reward.title {
            stack.addArrangedSubview(PWInAppStyle.makeLabel(
                title, font: PWInAppStyle.rounded(22, .heavy),
                fallback: primaryFallback, alignment: .center))
        }
        if let message = reward.message {
            stack.addArrangedSubview(PWInAppStyle.makeLabel(
                message, font: PWInAppStyle.rounded(15, .regular),
                fallback: secondaryFallback, alignment: .center))
        }
        if let code = reward.promoCode {
            stack.addArrangedSubview(makeCodeChip(code))
        }
        if let button = reward.button {
            stack.addArrangedSubview(makeCTA(button))
        }
    }

    private func makeCodeChip(_ code: String) -> UIView {
        let chip = PWDashedChipControl()
        chip.layer.cornerRadius = 12
        chip.layer.cornerCurve = .continuous
        chip.backgroundColor = chipBackground
        chip.dashColor = primaryFallback.withAlphaComponent(0.4)
        chip.heightAnchor.constraint(equalToConstant: Metrics.codeChipHeight).isActive = true
        chip.accessibilityLabel = "Promo code \(code). Double tap to copy."

        let label = UILabel()
        label.text = code
        label.font = PWInAppStyle.rounded(17, .bold)
        label.textColor = reward.title?.color ?? primaryFallback
        label.textAlignment = .center

        let icon = UIImageView(image: UIImage(
            systemName: "doc.on.doc",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
        icon.tintColor = (reward.title?.color ?? primaryFallback).withAlphaComponent(0.7)

        let row = UIStackView(arrangedSubviews: [label, icon])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
        ])

        chip.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        codeLabel = label
        return chip
    }

    private func makeCTA(_ model: PWInAppButton) -> UIButton {
        let button = PWInAppStyle.makeContractButton(model)
        button.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
        return button
    }

    @objc private func copyTapped() {
        guard let code = reward.promoCode else {
            return
        }
        UIPasteboard.general.string = code
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCopy?(code)
        PWInAppConfetti.burst(in: self, colors: [])

        codeLabel?.text = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.copyResetDelay) { [weak self] in
            self?.codeLabel?.text = code
        }
    }

    @objc private func ctaTapped() {
        onAction?(reward.button?.action ?? .close)
    }

    /// Post-reveal celebration: a diagonal shimmer sweep across the panel plus a
    /// soft pulse — the CleverTap signature moves, GPU-cheap and Reduce
    /// Motion-aware.
    func celebrate() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        layoutIfNeeded()

        let shimmer = CAGradientLayer()
        shimmer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor,
        ]
        shimmer.startPoint = CGPoint(x: 0, y: 0.4)
        shimmer.endPoint = CGPoint(x: 1, y: 0.6)
        let bandWidth = bounds.width * 0.6
        shimmer.frame = CGRect(x: -bandWidth, y: 0, width: bandWidth, height: bounds.height)
        layer.addSublayer(shimmer)

        let sweep = CABasicAnimation(keyPath: "position.x")
        sweep.fromValue = -bandWidth / 2
        sweep.toValue = bounds.width + bandWidth / 2
        sweep.duration = 0.9
        sweep.repeatCount = 2
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmer.add(sweep, forKey: "pw.shimmer")
        DispatchQueue.main.asyncAfter(deadline: .now() + sweep.duration * 2) {
            shimmer.removeFromSuperlayer()
        }

        UIView.animateKeyframes(withDuration: 0.9, delay: 0.1) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.4) {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.6) {
                self.transform = .identity
            }
        }
    }
}

/// Promo-code chip with a dashed border that tracks the control's final size.
private final class PWDashedChipControl: UIControl {
    private let border = CAShapeLayer()

    var dashColor: UIColor = .separator {
        didSet { border.strokeColor = dashColor.cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        border.strokeColor = dashColor.cgColor
        border.fillColor = UIColor.clear.cgColor
        border.lineDashPattern = [6, 4]
        border.lineWidth = 1.5
        layer.addSublayer(border)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        border.frame = bounds
        border.path = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}

/// One-shot confetti burst over the winning moment. A `CAEmitterLayer` volley of
/// small rounded rects in the campaign palette; skipped under Reduce Motion.
enum PWInAppConfetti {
    static func burst(in view: UIView, colors: [UIColor]) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -8)
        emitter.emitterSize = CGSize(width: view.bounds.width * 0.8, height: 1)
        emitter.emitterShape = .line
        emitter.birthRate = 1

        let palette = colors.isEmpty
            ? [.systemPink, .systemYellow, .systemTeal, .systemOrange, .systemPurple]
            : colors
        emitter.emitterCells = palette.map { color in
            let cell = CAEmitterCell()
            cell.contents = confettiImage(color).cgImage
            cell.birthRate = 8
            cell.lifetime = 3.2
            cell.velocity = 190
            cell.velocityRange = 70
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 5
            cell.spin = 3.4
            cell.spinRange = 2.5
            cell.scale = 0.7
            cell.scaleRange = 0.35
            cell.yAcceleration = 110
            return cell
        }
        view.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            emitter.removeFromSuperlayer()
        }
    }

    private static func confettiImage(_ color: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 5)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill()
        }
    }
}
#endif
