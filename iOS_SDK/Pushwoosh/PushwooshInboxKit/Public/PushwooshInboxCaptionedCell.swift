//
//  PushwooshInboxCaptionedCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 30.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Apple-stock baseline: hero image on top + body, single rounded card,
//  glass pin chip, tinted CTA buttons, native iOS surfaces. Mirrors Braze's
//  "Captioned Image" card type.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

@objc(PushwooshInboxCaptionedCell)
open class PushwooshInboxCaptionedCell: PushwooshInboxCell {

    private let card = UIView()
    private let imageHost = UIView()
    /// Round message icon in the title row. Distinct from the hero image above:
    /// the hero is the push attachment, this is the message's own icon.
    private let iconView = UIImageView()
    /// Swapped in `apply`: the whole text block starts in the unread-dot gutter when
    /// there is no icon, and after the icon when there is one.
    private var bodyLeadingWithoutIcon: NSLayoutConstraint?
    private var bodyLeadingWithIcon: NSLayoutConstraint?
    /// Spans title + body, so the icon can be centred on the copy alone.
    private let textBlockGuide = UILayoutGuide()
    private let bodyStack = UIStackView()
    private let titleRow = UIView()
    private let pinChip = UIView()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installCaptionedLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installCaptionedLayout()
    }

    private func installCaptionedLayout() {
        resetInheritedLayout()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.masksToBounds = true
        contentView.addSubview(card)

        imageHost.translatesAutoresizingMaskIntoConstraints = false
        imageHost.clipsToBounds = true
        imageHost.layer.cornerRadius = 16
        imageHost.layer.cornerCurve = .continuous
        card.addSubview(imageHost)

        messageImageView.translatesAutoresizingMaskIntoConstraints = false
        messageImageView.contentMode = .scaleAspectFill
        messageImageView.clipsToBounds = true
        imageHost.addSubview(messageImageView)

        pinChip.translatesAutoresizingMaskIntoConstraints = false
        pinChip.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        pinChip.layer.cornerRadius = 14
        pinChip.layer.cornerCurve = .continuous
        pinChip.isHidden = true
        imageHost.addSubview(pinChip)

        pinIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        pinIndicatorView.contentMode = .scaleAspectFit
        pinIndicatorView.tintColor = .white
        pinChip.addSubview(pinIndicatorView)

        // Round message icon, leading the text block: title and body both sit to the
        // right of it, the same arrangement the classic card uses for its avatar.
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 16
        iconView.isHidden = true
        card.addSubview(iconView)
        card.addLayoutGuide(textBlockGuide)

        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.axis = .vertical
        bodyStack.alignment = .fill
        bodyStack.distribution = .fill
        bodyStack.spacing = 4
        card.addSubview(bodyStack)

        // The unread dot floats to the left of the body block; title, body
        // and buttons share the same leading x via bodyStack.
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.addArrangedSubview(titleRow)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        titleRow.addSubview(titleLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textAlignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addSubview(dateLabel)

        // Unread dot — sits in the gutter to the left of the body block,
        // vertically centred on the title. Hidden = invisible but layout
        // unchanged (title stays put when read).
        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 5
        imageHost.addSubview(unreadIndicatorView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 3
        bodyStack.addArrangedSubview(bodyLabel)

        // Custom spacing — 12pt above buttons (only applied when both visible).
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.isHidden = true
        bodyStack.addArrangedSubview(buttonsStack)
        bodyStack.setCustomSpacing(12, after: bodyLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            imageHost.topAnchor.constraint(equalTo: card.topAnchor, constant: 5.5),
            imageHost.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 5.5),
            imageHost.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -5.5),
            {
                let c = imageHost.heightAnchor.constraint(equalToConstant: 178)
                c.priority = .required - 1   // yield to UIView-Encapsulated-Layout-Height (self-sizing)
                return c
            }(),

            messageImageView.topAnchor.constraint(equalTo: imageHost.topAnchor),
            messageImageView.leadingAnchor.constraint(equalTo: imageHost.leadingAnchor),
            messageImageView.trailingAnchor.constraint(equalTo: imageHost.trailingAnchor),
            messageImageView.bottomAnchor.constraint(equalTo: imageHost.bottomAnchor),

            pinChip.topAnchor.constraint(equalTo: imageHost.topAnchor, constant: 10),
            pinChip.trailingAnchor.constraint(equalTo: imageHost.trailingAnchor, constant: -10),
            pinChip.widthAnchor.constraint(equalToConstant: 28),
            pinChip.heightAnchor.constraint(equalToConstant: 28),

            pinIndicatorView.centerXAnchor.constraint(equalTo: pinChip.centerXAnchor),
            pinIndicatorView.centerYAnchor.constraint(equalTo: pinChip.centerYAnchor),
            pinIndicatorView.widthAnchor.constraint(equalToConstant: 13),
            pinIndicatorView.heightAnchor.constraint(equalToConstant: 13),

            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            // Centred on the text itself — the guide spans the title row and the body
            // label, so the buttons row (when a message carries CTAs) does not drag the
            // icon down past the copy it belongs to.
            iconView.centerYAnchor.constraint(equalTo: textBlockGuide.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            textBlockGuide.topAnchor.constraint(equalTo: titleRow.topAnchor),
            textBlockGuide.bottomAnchor.constraint(equalTo: bodyLabel.bottomAnchor),

            bodyStack.topAnchor.constraint(equalTo: imageHost.bottomAnchor, constant: 14),
            bodyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            bodyStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            // Top-left corner of the hero image, mirroring the pin chip on the right.
            unreadIndicatorView.topAnchor.constraint(equalTo: imageHost.topAnchor, constant: 10),
            unreadIndicatorView.leadingAnchor.constraint(equalTo: imageHost.leadingAnchor, constant: 10),
            unreadIndicatorView.widthAnchor.constraint(equalToConstant: 10),
            unreadIndicatorView.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor)
        ])

        bodyLeadingWithoutIcon = bodyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16)
        bodyLeadingWithIcon = bodyStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12)
        bodyLeadingWithoutIcon?.isActive = true

        installTextGlassPlate(behind: bodyStack, in: card)
    }

    open override func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        let style = attributes.style
        // Hero slot takes the push attachment; the round icon in the title row takes
        // the message icon. When the payload carries only one picture the resolver
        // returns the same URL for both, and the icon is dropped so it is not shown twice.
        let imageURL = PushwooshInboxKitAttributes.resolvedBannerURL(from: message)
        let iconURL = PushwooshInboxKitAttributes.resolvedImageURL(from: message)
        let showsIcon = iconURL != nil && iconURL != imageURL

        iconView.isHidden = !showsIcon
        bodyLeadingWithoutIcon?.isActive = !showsIcon
        bodyLeadingWithIcon?.isActive = showsIcon
        if let iconURL, showsIcon {
            MessageImageLoader.shared.load(iconURL, into: iconView, placeholder: style.imagePlaceholder)
        } else {
            iconView.image = nil
        }

        applyGlassBackdrop(in: card, imageURL: imageURL, style: style, cornerRadius: 18)
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        imageHost.backgroundColor = .secondarySystemFill

        titleLabel.text = message.title
        titleLabel.font = style.titleFont
        titleLabel.textColor = message.isRead ? style.titleColorRead : style.titleColorUnread

        bodyLabel.text = message.message
        bodyLabel.font = style.bodyFont
        bodyLabel.textColor = message.isRead ? style.bodyColorRead : style.bodyColorUnread

        dateLabel.text = style.dateFormatter(message.sendDate ?? Date())
        dateLabel.font = style.dateFont
        dateLabel.textColor = style.dateColor

        unreadIndicatorView.backgroundColor = style.unreadBadgeColor
        unreadIndicatorView.isHidden = message.isRead

        // Gate on isLiquidGlass (opt-in) and re-assert visibility after a prepareForReuse hide,
        // so a recycled cell doesn't lose the glass plate behind its caption.
        textGlassPlate?.isHidden = !style.isLiquidGlass

        let isPinned = attributes.pinningEnabled && PushwooshInboxKitAttributes.isPinned(message)
        pinChip.isHidden = !isPinned || !attributes.pinIndicatorVisible
        if isPinned && attributes.pinIndicatorVisible {
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else {                let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        if let urlString = imageURL, !urlString.isEmpty {
            MessageImageLoader.shared.load(urlString, into: messageImageView, placeholder: style.imagePlaceholder)
        } else {
            messageImageView.image = style.imagePlaceholder
        }

        let buttons = attributes.inlineButtonsEnabled ? PushwooshInboxButton.decode(from: message) : []
        applyButtons(buttons, style: style)
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: messageImageView)
        messageImageView.image = nil
        pinChip.isHidden = true
        buttonsStack.isHidden = true
        unreadIndicatorView.isHidden = true
        textGlassPlate?.isHidden = true
    }
}
#endif
