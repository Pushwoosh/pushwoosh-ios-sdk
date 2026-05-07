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
            if #available(iOS 13.0, *) { uiButton.layer.cornerCurve = .continuous }
            // No `contentEdgeInsets` — it conflicts with the fixed 34pt height
            // and produces inflated buttons on iOS 15+. Title is centered, the
            // height is explicit.
            uiButton.addTarget(self, action: #selector(handleInlineButtonTap(_:)), for: .touchUpInside)
            buttonsStack.addArrangedSubview(uiButton)
        }

        // Single constraint, reused across bind/unbind — never stacks duplicates.
        if buttonsStackHeight == nil {
            let h = buttonsStack.heightAnchor.constraint(equalToConstant: 34)
            h.priority = .required
            buttonsStackHeight = h
        }
        buttonsStackHeight?.isActive = true
    }

    private var buttonsStackHeight: NSLayoutConstraint?

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
#endif
