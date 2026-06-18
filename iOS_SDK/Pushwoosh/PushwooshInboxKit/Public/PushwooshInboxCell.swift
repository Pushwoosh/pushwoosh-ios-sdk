//
//  PushwooshInboxCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

/// Default inbox table-view cell. Subclass this type and register it under a
/// custom kind via ``PushwooshInboxKitAttributes/cells`` to ship bespoke
/// layouts.
@objc(PushwooshInboxCell)
open class PushwooshInboxCell: UITableViewCell {

    public let messageImageView = UIImageView()
    public let titleLabel = UILabel()
    public let bodyLabel = UILabel()
    public let dateLabel = UILabel()
    public let unreadIndicatorView = UIView()

    /// Horizontal stack that hosts inline CTA buttons (`PushwooshInboxButton`).
    /// Subclasses are expected to add this view to their own card chrome —
    /// `applyButtons(_:style:onTap:)` populates it.
    public let buttonsStack = UIStackView()

    /// Small pin glyph rendered when the message carries
    /// `actionParams["pinned"] == true` and ``PushwooshInboxKitAttributes/pinningEnabled``
    /// is `true`. Subclasses position it; the base class only owns the
    /// instance.
    public let pinIndicatorView = UIImageView()

    /// Captured tap handler for buttons rendered via `applyButtons(...)`.
    /// Subclasses call back into this when an inline CTA is tapped so the VC
    /// can route to the delegate.
    public var onInlineButtonTap: ((PushwooshInboxButton) -> Void)?

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageLeadingConstraint: NSLayoutConstraint?
    private var lastAppliedAttributes: PushwooshInboxKitAttributes?
    private var lastAppliedMessage: PWInboxMessageProtocol?
    private var cardGlassEffectView: UIVisualEffectView?
    private var cardGlassBackdropView: UIView?
    private var cardGlassBlurView: UIVisualEffectView?
    private var glassBackdropImageView: UIImageView?
    private var glassBackdropBlur: UIVisualEffectView?
    private var glassBackdropPlate: UIVisualEffectView?
    /// Not private: card subclasses (video) toggle its visibility from their own files.
    var textGlassPlate: UIVisualEffectView?

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    /// Renders an array of inline CTA buttons into ``buttonsStack`` using the
    /// supplied style. Empties the stack when `buttons` is empty. The cell's
    /// `onInlineButtonTap` is invoked with the tapped button.
    ///
    /// Each button is sized to a fixed 34pt height (Apple Mail / Wallet
    /// convention) and the stack itself is constrained to that height so it
    /// never stretches when the cell's vertical chain has slack.
    open func applyButtons(_ buttons: [PushwooshInboxButton],
                           style: PushwooshInboxKitAttributes.Style,
                           traits: UITraitCollection? = nil) {
        for view in buttonsStack.arrangedSubviews {
            buttonsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard !buttons.isEmpty else {
            buttonsStack.isHidden = true
            buttonsStackHeight?.isActive = false
            return
        }
        buttonsStack.isHidden = false
        buttonsStack.axis = .horizontal
        buttonsStack.distribution = .fillEqually
        buttonsStack.spacing = 8

        let resolvedTextColor = traits.flatMap { style.buttonTextColor.resolvedColor(with: $0) } ?? style.buttonTextColor
        let resolvedBg = traits.flatMap { style.buttonBackgroundColor.resolvedColor(with: $0) } ?? style.buttonBackgroundColor

        for button in buttons {
            let uiButton = InboxInlineButton(model: button)
            uiButton.titleLabel?.font = style.buttonFont
            uiButton.setTitleColor(resolvedTextColor, for: .normal)
            uiButton.setTitle(button.title, for: .normal)
            uiButton.backgroundColor = resolvedBg
            uiButton.layer.cornerRadius = style.buttonCornerRadius
            uiButton.layer.cornerCurve = .continuous
            // iOS 26: a Liquid Glass surface behind the title instead of a flat fill — the button
            // shimmers with motion. The button still handles the tap (glass is decorative).
            if #available(iOS 26.0, *) {
                let glassFX = UIVisualEffectView(effect: pwInboxGlassEffect())
                glassFX.translatesAutoresizingMaskIntoConstraints = false
                glassFX.isUserInteractionEnabled = false
                glassFX.clipsToBounds = true
                glassFX.layer.cornerRadius = style.buttonCornerRadius
                glassFX.layer.cornerCurve = .continuous
                uiButton.insertSubview(glassFX, at: 0)
                NSLayoutConstraint.activate([
                    glassFX.topAnchor.constraint(equalTo: uiButton.topAnchor),
                    glassFX.leadingAnchor.constraint(equalTo: uiButton.leadingAnchor),
                    glassFX.trailingAnchor.constraint(equalTo: uiButton.trailingAnchor),
                    glassFX.bottomAnchor.constraint(equalTo: uiButton.bottomAnchor)
                ])
                uiButton.backgroundColor = .clear
            }
            // No `contentEdgeInsets` — it conflicts with the fixed 34pt height
            // and produces inflated buttons on iOS 15+. Title is centered, the
            // height is explicit.
            uiButton.addTarget(self, action: #selector(handleInlineButtonTap(_:)), for: .touchUpInside)
            buttonsStack.addArrangedSubview(uiButton)
        }

        // Single constraint, reused across bind/unbind — never stacks duplicates.
        if buttonsStackHeight == nil {
            let h = buttonsStack.heightAnchor.constraint(equalToConstant: 34)
            h.priority = .required - 1   // yield to UIView-Encapsulated-Layout-Height (self-sizing)
            buttonsStackHeight = h
        }
        buttonsStackHeight?.isActive = true
    }

    private var buttonsStackHeight: NSLayoutConstraint?

    /// Applies the card's background surface honoring ``PushwooshInboxKitAttributes/Style/isLiquidGlass``:
    /// an Apple Liquid Glass effect on iOS 26+, with the solid `backgroundColor` as the fallback.
    /// Card subclasses call this from `apply(...)` instead of setting `card.backgroundColor` directly.
    /// A neutral opaque backdrop is inserted behind the glass so it refracts a known colour
    /// (`backgroundColor`) instead of tinting from whatever image/content the card holds; the glass
    /// sits above it, behind the card's content, and both are clipped by the card's rounded corners.
    open func applyCardSurface(_ card: UIView, style: PushwooshInboxKitAttributes.Style, cornerRadius: CGFloat) {
        if style.isLiquidGlass, #available(iOS 26.0, *) {
            card.backgroundColor = .clear

            let backdrop: UIView
            if let existing = cardGlassBackdropView {
                backdrop = existing
            } else {
                backdrop = UIView()
                backdrop.translatesAutoresizingMaskIntoConstraints = false
                backdrop.isUserInteractionEnabled = false
                backdrop.clipsToBounds = true
                card.insertSubview(backdrop, at: 0)
                NSLayoutConstraint.activate([
                    backdrop.topAnchor.constraint(equalTo: card.topAnchor),
                    backdrop.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                    backdrop.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    backdrop.bottomAnchor.constraint(equalTo: card.bottomAnchor)
                ])
                cardGlassBackdropView = backdrop
            }
            backdrop.backgroundColor = style.backgroundColor
            backdrop.layer.cornerRadius = cornerRadius
            backdrop.layer.cornerCurve = .continuous
            backdrop.isHidden = false

            // Frosted blur between the backdrop and the Liquid Glass — makes the base look more
            // matte / diffuse ("milkier"). Tune the mattness via `blur.alpha` or the blur style.
            let blur: UIVisualEffectView
            if let existing = cardGlassBlurView {
                blur = existing
            } else {
                blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                blur.translatesAutoresizingMaskIntoConstraints = false
                blur.isUserInteractionEnabled = false
                blur.clipsToBounds = true
                card.insertSubview(blur, aboveSubview: backdrop)
                NSLayoutConstraint.activate([
                    blur.topAnchor.constraint(equalTo: card.topAnchor),
                    blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                    blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    blur.bottomAnchor.constraint(equalTo: card.bottomAnchor)
                ])
                cardGlassBlurView = blur
            }
            blur.layer.cornerRadius = cornerRadius
            blur.layer.cornerCurve = .continuous
            blur.alpha = 0.6
            blur.isHidden = false

            let glass: UIVisualEffectView
            if let existing = cardGlassEffectView {
                glass = existing
            } else {
                glass = UIVisualEffectView(effect: pwInboxGlassEffect())
                glass.translatesAutoresizingMaskIntoConstraints = false
                glass.isUserInteractionEnabled = false
                glass.clipsToBounds = true
                card.insertSubview(glass, aboveSubview: blur)
                NSLayoutConstraint.activate([
                    glass.topAnchor.constraint(equalTo: card.topAnchor),
                    glass.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                    glass.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    glass.bottomAnchor.constraint(equalTo: card.bottomAnchor)
                ])
                cardGlassEffectView = glass
            }
            glass.layer.cornerRadius = cornerRadius
            glass.layer.cornerCurve = .continuous
            glass.isHidden = false
        } else {
            cardGlassEffectView?.isHidden = true
            cardGlassBlurView?.isHidden = true
            cardGlassBackdropView?.isHidden = true
            card.backgroundColor = style.backgroundColor
        }
    }

    /// Like ``applyCardSurface(_:style:cornerRadius:)``, but the glass refracts a blurred copy of the
    /// message image rather than a flat colour — the carousel "frosted glass over a photo" look,
    /// reusable by any card. Stack (bottom→top): blurred image → frosted blur → Liquid Glass, all
    /// filling `card` behind its content. Falls back to the solid background when off / pre-iOS 26 /
    /// no image. Card content (image blocks, text) sits above and lets the glass show in the gaps.
    open func applyGlassBackdrop(in card: UIView,
                                 imageURL: String?,
                                 style: PushwooshInboxKitAttributes.Style,
                                 cornerRadius: CGFloat) {
        guard style.isLiquidGlass, #available(iOS 26.0, *), let urlString = imageURL, !urlString.isEmpty else {
            glassBackdropImageView?.isHidden = true
            glassBackdropBlur?.isHidden = true
            glassBackdropPlate?.isHidden = true
            card.backgroundColor = style.backgroundColor
            return
        }
        card.backgroundColor = .clear

        let backdrop: UIImageView
        if let existing = glassBackdropImageView {
            backdrop = existing
        } else {
            backdrop = UIImageView()
            backdrop.translatesAutoresizingMaskIntoConstraints = false
            backdrop.contentMode = .scaleAspectFill
            backdrop.clipsToBounds = true
            // Never let the backdrop image drive the cell's height.
            backdrop.setContentHuggingPriority(.defaultLow, for: .vertical)
            backdrop.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            card.insertSubview(backdrop, at: 0)
            NSLayoutConstraint.activate([
                backdrop.topAnchor.constraint(equalTo: card.topAnchor),
                backdrop.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                backdrop.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])
            glassBackdropImageView = backdrop
        }
        backdrop.layer.cornerRadius = cornerRadius
        backdrop.layer.cornerCurve = .continuous
        backdrop.isHidden = false

        let blur: UIVisualEffectView
        if let existing = glassBackdropBlur {
            blur = existing
        } else {
            blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
            blur.translatesAutoresizingMaskIntoConstraints = false
            blur.isUserInteractionEnabled = false
            blur.clipsToBounds = true
            card.insertSubview(blur, aboveSubview: backdrop)
            NSLayoutConstraint.activate([
                blur.topAnchor.constraint(equalTo: card.topAnchor),
                blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                blur.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])
            glassBackdropBlur = blur
        }
        blur.layer.cornerRadius = cornerRadius
        blur.layer.cornerCurve = .continuous
        blur.isHidden = false

        let plate: UIVisualEffectView
        if let existing = glassBackdropPlate {
            plate = existing
        } else {
            plate = UIVisualEffectView(effect: pwInboxGlassEffect())
            plate.translatesAutoresizingMaskIntoConstraints = false
            plate.isUserInteractionEnabled = false
            plate.clipsToBounds = true
            card.insertSubview(plate, aboveSubview: blur)
            NSLayoutConstraint.activate([
                plate.topAnchor.constraint(equalTo: card.topAnchor),
                plate.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                plate.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                plate.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])
            glassBackdropPlate = plate
        }
        plate.layer.cornerRadius = cornerRadius
        plate.layer.cornerCurve = .continuous
        plate.isHidden = false

        MessageImageLoader.shared.load(urlString, into: backdrop, placeholder: nil)
    }

    /// Inserts a frosted, semi-transparent Liquid Glass plate behind a text block (iOS 26+), centred
    /// on `card` with symmetric horizontal insets and top/bottom hugging `textBlock`. Call from the
    /// cell's layout after `textBlock` is added with its constraints. No-op pre-iOS 26. The returned
    /// view (stored in `textGlassPlate`) can be hidden by the caller when there's no text.
    @discardableResult
    open func installTextGlassPlate(behind textBlock: UIView,
                                    in card: UIView,
                                    horizontalInset: CGFloat = 5.5,
                                    cornerRadius: CGFloat = 16) -> UIView? {
        guard #available(iOS 26.0, *) else { return nil }
        guard textGlassPlate == nil else { return textGlassPlate }
        let plate = UIVisualEffectView(effect: pwInboxGlassEffect())
        plate.translatesAutoresizingMaskIntoConstraints = false
        plate.isUserInteractionEnabled = false
        plate.clipsToBounds = true
        plate.layer.cornerRadius = cornerRadius
        plate.layer.cornerCurve = .continuous
        plate.alpha = 0.45
        card.insertSubview(plate, belowSubview: textBlock)
        NSLayoutConstraint.activate([
            plate.topAnchor.constraint(equalTo: textBlock.topAnchor, constant: -10),
            plate.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: horizontalInset),
            plate.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -horizontalInset),
            plate.bottomAnchor.constraint(equalTo: textBlock.bottomAnchor, constant: 10)
        ])
        textGlassPlate = plate
        return plate
    }

    @objc private func handleInlineButtonTap(_ sender: InboxInlineButton) {
        guard let model = sender.model else { return }
        onInlineButtonTap?(model)
    }

    /// Detaches every inherited subview from the contentView and removes the
    /// fixed-size self-constraints (width/height) that were added by the
    /// default layout in `setupSubviews()`. Subclasses call this before
    /// installing their own chrome to avoid Auto Layout conflicts.
    open func resetInheritedLayout() {
        for v in [messageImageView, titleLabel, bodyLabel, dateLabel, unreadIndicatorView] {
            v.removeFromSuperview()
            v.removeConstraints(v.constraints)
        }
        imageWidthConstraint = nil
        imageLeadingConstraint = nil
    }

    private func setupSubviews() {
        selectionStyle = .default

        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 4
        contentView.addSubview(unreadIndicatorView)

        messageImageView.translatesAutoresizingMaskIntoConstraints = false
        messageImageView.contentMode = .scaleAspectFill
        messageImageView.clipsToBounds = true
        contentView.addSubview(messageImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        contentView.addSubview(titleLabel)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 2
        contentView.addSubview(bodyLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.numberOfLines = 1
        dateLabel.textAlignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        contentView.addSubview(dateLabel)

        let imgWidth = messageImageView.widthAnchor.constraint(equalToConstant: 56)
        let imgLeading = messageImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 16)
        imageWidthConstraint = imgWidth
        imageLeadingConstraint = imgLeading

        NSLayoutConstraint.activate([
            unreadIndicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            unreadIndicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            unreadIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicatorView.heightAnchor.constraint(equalToConstant: 8),

            imgLeading,
            messageImageView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            imgWidth,
            messageImageView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.leadingAnchor.constraint(equalTo: messageImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    /// Configures the cell for the given message and attributes. Subclasses may
    /// override to render bespoke layouts; call `super.apply(...)` to inherit
    /// dark-mode reactivity.
    open func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        lastAppliedAttributes = attributes
        lastAppliedMessage = message

        let resolvedTraits: UITraitCollection? = attributes.enableDarkTheme
            ? nil
            : UITraitCollection(userInterfaceStyle: .light)

        let style = attributes.style

        backgroundColor = resolved(style.backgroundColor, against: resolvedTraits)
        contentView.backgroundColor = backgroundColor

        titleLabel.text = message.title
        titleLabel.font = style.titleFont
        titleLabel.textColor = resolved(message.isRead ? style.titleColorRead : style.titleColorUnread, against: resolvedTraits)

        bodyLabel.text = message.message
        bodyLabel.font = style.bodyFont
        bodyLabel.textColor = resolved(message.isRead ? style.bodyColorRead : style.bodyColorUnread, against: resolvedTraits)

        dateLabel.text = style.dateFormatter(message.sendDate ?? Date())
        dateLabel.font = style.dateFont
        dateLabel.textColor = resolved(style.dateColor, against: resolvedTraits)

        unreadIndicatorView.backgroundColor = resolved(style.unreadBadgeColor, against: resolvedTraits)
        unreadIndicatorView.isHidden = message.isRead

        let hasImage = !(message.imageUrl?.isEmpty ?? true)
        if hasImage, let urlString = message.imageUrl {
            messageImageView.isHidden = false
            messageImageView.layer.cornerRadius = style.imageCornerRadius
            imageWidthConstraint?.constant = 56
            imageLeadingConstraint?.constant = 16
            MessageImageLoader.shared.load(urlString, into: messageImageView, placeholder: style.imagePlaceholder)
        } else {
            messageImageView.isHidden = true
            messageImageView.image = nil
            imageWidthConstraint?.constant = 0
            imageLeadingConstraint?.constant = 0
            MessageImageLoader.shared.cancelLoad(for: messageImageView)
        }
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: messageImageView)
        messageImageView.image = nil
        // The glass backdrop also loads an image — cancel + clear it so a recycled cell doesn't
        // flash the previous message's photo behind the frosted glass before apply() runs.
        if let backdrop = glassBackdropImageView {
            MessageImageLoader.shared.cancelLoad(for: backdrop)
            backdrop.image = nil
        }
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let message = lastAppliedMessage, let attrs = lastAppliedAttributes {
            apply(message: message, attributes: attrs)
        }
    }

    private func resolved(_ color: UIColor, against traits: UITraitCollection?) -> UIColor {
        guard let traits = traits else { return color }
        return color.resolvedColor(with: traits)
    }
}

/// Lightweight UIButton subclass that retains the originating
/// `PushwooshInboxButton` model so tap handlers can look it up.
final class InboxInlineButton: UIButton {
    var model: PushwooshInboxButton?
    convenience init(model: PushwooshInboxButton) {
        self.init(type: .system)
        self.model = model
    }
}

// MARK: - Liquid Glass effect factory

/// A Liquid Glass effect on the iOS 26 SDK (Xcode 26+ toolchain), at runtime on iOS 26+, otherwise a
/// frosted blur. The compiler guard keeps `UIGlassEffect` — which doesn't exist in older SDKs — out of
/// the compile on older Xcode (e.g. CI), where the blur fallback is built instead.
func pwInboxGlassEffect(interactive: Bool = false) -> UIVisualEffect {
#if compiler(>=6.2)
    if #available(iOS 26.0, *) {
        let effect = UIGlassEffect()
        effect.isInteractive = interactive
        return effect
    }
#endif
    return UIBlurEffect(style: .systemThinMaterial)
}

/// A `UIGlassContainerEffect` (glass elements merge within `spacing`) on Xcode 26+/iOS 26+, else blur.
func pwInboxGlassContainerEffect(spacing: CGFloat) -> UIVisualEffect {
#if compiler(>=6.2)
    if #available(iOS 26.0, *) {
        let effect = UIGlassContainerEffect()
        effect.spacing = spacing
        return effect
    }
#endif
    return UIBlurEffect(style: .systemThinMaterial)
}
#endif
