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
        card.addSubview(imageHost)

        messageImageView.translatesAutoresizingMaskIntoConstraints = false
        messageImageView.contentMode = .scaleAspectFill
        messageImageView.clipsToBounds = true
        imageHost.addSubview(messageImageView)

        pinChip.translatesAutoresizingMaskIntoConstraints = false
        pinChip.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        pinChip.layer.cornerRadius = 14
        if #available(iOS 13.0, *) { pinChip.layer.cornerCurve = .continuous }
        pinChip.isHidden = true
        imageHost.addSubview(pinChip)

        pinIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        pinIndicatorView.contentMode = .scaleAspectFit
        pinIndicatorView.tintColor = .white
        pinChip.addSubview(pinIndicatorView)

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
        unreadIndicatorView.layer.cornerRadius = 4
        card.addSubview(unreadIndicatorView)

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

            imageHost.topAnchor.constraint(equalTo: card.topAnchor),
            imageHost.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageHost.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageHost.heightAnchor.constraint(equalToConstant: 178),

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

            bodyStack.topAnchor.constraint(equalTo: imageHost.bottomAnchor, constant: 14),
            // bodyStack inset 32pt from card.leading — leaves a 16pt gutter
            // for the unread dot (8pt dot + 8pt spacing).
            bodyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            bodyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            bodyStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            unreadIndicatorView.trailingAnchor.constraint(equalTo: bodyStack.leadingAnchor, constant: -8),
            unreadIndicatorView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            unreadIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicatorView.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor)
        ])
    }

    open override func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        let style = attributes.style

        card.backgroundColor = style.backgroundColor
        card.layer.cornerRadius = 18
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }

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

        let isPinned = attributes.pinningEnabled && PushwooshInboxKitAttributes.isPinned(message)
        pinChip.isHidden = !isPinned
        if isPinned {
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else if #available(iOS 13.0, *) {
                let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        if let urlString = message.imageUrl, !urlString.isEmpty {
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
    }
}
#endif
