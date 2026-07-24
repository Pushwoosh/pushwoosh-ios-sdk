//
//  PWInAppStyle.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Shared visual language for the in-app chrome — corner radii, the rounded
//  display face, a blurred backdrop, the close affordance, card shadow, and the
//  present/dismiss spring. Deliberately neutral-premium: it styles the frame the
//  SDK owns and never overrides the colors a campaign supplies.
//

#if canImport(UIKit) && os(iOS)
import UIKit

enum PWInAppStyle {
    static let cardCornerRadius: CGFloat = 24
    static let buttonCornerRadius: CGFloat = 14
    static let cardInset: CGFloat = 20
    static let closeSize: CGFloat = 34

    /// SF Rounded — friendlier than stock San Francisco, the single typographic
    /// signature carried across every template.
    static func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Shared label builder — text with a color fallback, alignment and line limit.
    /// Contract-styled action button — the single render path shared by every
    /// template: fill from `background`, 1.5pt stroke from `border.color`,
    /// radius from `border.radius`, title color from `text.color`. No
    /// positional prominent/outlined heuristics.
    static func makeContractButton(_ model: PWInAppButton) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(model.text.text, for: .normal)
        button.titleLabel?.font = rounded(16, .semibold)
        button.setTitleColor(model.text.color ?? .white, for: .normal)
        button.backgroundColor = model.backgroundColor
        button.layer.borderColor = model.borderColor.cgColor
        button.layer.borderWidth = 1.5
        button.layer.cornerRadius = model.cornerRadius
        button.layer.cornerCurve = .continuous
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }

    static func makeLabel(_ text: PWInAppText, font: UIFont, fallback: UIColor,
                          alignment: NSTextAlignment = .natural, lines: Int = 0) -> UILabel {
        let label = UILabel()
        label.text = text.text
        label.font = font
        label.textColor = text.color ?? fallback
        label.numberOfLines = lines
        label.textAlignment = alignment
        return label
    }

    /// Dimmed backdrop behind modal-style templates. On iOS 26+ it's a Liquid
    /// Glass sheet with a light wash — the app stays clearly visible beneath;
    /// before that, a darker thin-material blur. Animate its `alpha` to fade
    /// the whole backdrop.
    static func makeBackdrop() -> UIView {
        // No dimming/blur and non-interactive: a transparent pass-through layer so
        // in-app templates no longer darken, cover, or block the host screen.
        // Touches fall through it to the template root (whose hitTest forwards
        // empty-area touches to the app); templates dismiss via their own close.
        let container = UIView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        return container
    }

    /// Material for SDK-owned chrome: Liquid Glass on iOS 26+, chrome blur
    /// before. Gated on the compiler too — the pre-26 CI toolchain has no
    /// `UIGlassEffect` symbol.
    static func glassEffect(interactive: Bool = false) -> UIVisualEffect {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect()
            glass.isInteractive = interactive
            return glass
        }
        #endif
        return UIBlurEffect(style: .systemChromeMaterialDark)
    }

    /// Card surface: Liquid Glass tinted with the campaign color on iOS 26+, a
    /// solid view before. Returns the surface, the view content must be added
    /// to, and whether the glass path was taken (fallback callers own the shadow).
    static func makeSurface(glassTint: UIColor?, solidColor: UIColor?,
                            cornerRadius: CGFloat) -> (surface: UIView, contentHost: UIView, isGlass: Bool) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect()
            glass.tintColor = glassTint
            let surface = UIVisualEffectView(effect: glass)
            surface.layer.cornerRadius = cornerRadius
            surface.layer.cornerCurve = .continuous
            surface.clipsToBounds = true
            return (surface, surface.contentView, true)
        }
        #endif
        let surface = UIView()
        surface.backgroundColor = solidColor
        surface.layer.cornerRadius = cornerRadius
        surface.layer.cornerCurve = .continuous
        return (surface, surface, false)
    }

    static func makeCloseButton() -> UIButton {
        let chip = PWInAppChipButton(size: closeSize)
        chip.setSymbol("xmark", pointSize: 12)
        chip.accessibilityLabel = "Close"
        return chip
    }

    /// Legible text color for a known campaign surface: near-black on light,
    /// white on dark. Campaign colors are fixed, so contrast must be computed —
    /// system-adaptive `.label` follows the device theme, not the surface.
    static func contrastColor(on background: UIColor) -> UIColor {
        isLightSurface(background) ? UIColor(white: 0.12, alpha: 1) : .white
    }

    static func isLightSurface(_ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return true
        }
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.65
    }

    /// Festive gradient card surface for campaigns that supply multiple
    /// background colors (gamified templates). Fully opaque — celebration
    /// surfaces read better saturated than glassy.
    static func makeGradientSurface(colors: [UIColor],
                                    cornerRadius: CGFloat) -> (surface: UIView, contentHost: UIView) {
        let surface = PWInAppGradientCardView()
        surface.colors = colors
        surface.layer.cornerRadius = cornerRadius
        surface.layer.cornerCurve = .continuous
        surface.clipsToBounds = true
        return (surface, surface)
    }
}

/// Diagonal multi-stop gradient card — the layer-backed equivalent of the
/// full-bleed gradients CleverTap's festive templates use.
final class PWInAppGradientCardView: UIView {

    var colors: [UIColor] = [] {
        didSet { setNeedsLayout() }
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let gradient = layer as? CAGradientLayer else {
            return
        }
        gradient.colors = colors.map { $0.cgColor }
        gradient.startPoint = CGPoint(x: 0.1, y: 0)
        gradient.endPoint = CGPoint(x: 0.9, y: 1)
    }
}

/// Circular control chip — a symbol riding the chrome material (Liquid Glass on
/// iOS 26+, chrome blur before). The icon lives in the effect's contentView so
/// it always renders above the material; swap it via `setSymbol`.
final class PWInAppChipButton: UIButton {
    private let iconView = UIImageView()

    init(size: CGFloat) {
        super.init(frame: .zero)
        let effectView = UIVisualEffectView(effect: PWInAppStyle.glassEffect())
        effectView.isUserInteractionEnabled = false
        // Liquid Glass draws its highlights along its own corner geometry —
        // a hard layer mask clips them and looks broken. Use the iOS 26
        // corner API for glass; pre-26 blur keeps the plain layer rounding.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            effectView.cornerConfiguration = .capsule()
        } else {
            effectView.layer.cornerRadius = size / 2
            effectView.clipsToBounds = true
        }
        #else
        effectView.layer.cornerRadius = size / 2
        effectView.clipsToBounds = true
        #endif
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(iconView)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconView.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSymbol(_ name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight = .bold) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        iconView.image = UIImage(systemName: name, withConfiguration: config)
    }
}

extension PWInAppStyle {
    static func applyCardShadow(_ view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.28
        view.layer.shadowRadius = 28
        view.layer.shadowOffset = CGSize(width: 0, height: 16)
    }

    /// Spring entrance shared by the card templates: backdrop fades, card scales
    /// up from 88%.
    static func animateIn(card: UIView, backdrop: UIView) {
        backdrop.alpha = 0
        card.alpha = 0
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.2) {
                backdrop.alpha = 1
                card.alpha = 1
            }
            return
        }
        card.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.82,
                       initialSpringVelocity: 0.3,
                       options: [.allowUserInteraction]) {
            backdrop.alpha = 1
            card.alpha = 1
            card.transform = .identity
        }
    }

    static func animateOut(card: UIView, backdrop: UIView, completion: @escaping () -> Void) {
        let reduce = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduce ? 0.15 : 0.22, animations: {
            backdrop.alpha = 0
            card.alpha = 0
            if !reduce {
                card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }
        }, completion: { _ in
            completion()
        })
    }
}
#endif
