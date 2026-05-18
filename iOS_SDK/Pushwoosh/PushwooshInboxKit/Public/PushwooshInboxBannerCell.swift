//
//  PushwooshInboxBannerCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 30.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Apple-stock baseline: full-bleed image, native iOS surfaces, no shadow,
//  glass pin chip, system blue accent. Mirrors Braze's "Banner" card type.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

@objc(PushwooshInboxBannerCell)
open class PushwooshInboxBannerCell: PushwooshInboxCell {

    private let card = UIView()
    private let imageHost = UIView()
    private let pinChip = UIView()
    private let placeholderGlyph = UIImageView()
    private let placeholderLabel = UILabel()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installBannerLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installBannerLayout()
    }

    private func installBannerLayout() {
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

        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 4
        unreadIndicatorView.layer.shadowColor = UIColor.black.cgColor
        unreadIndicatorView.layer.shadowOpacity = 0.25
        unreadIndicatorView.layer.shadowRadius = 2
        unreadIndicatorView.layer.shadowOffset = CGSize(width: 0, height: 1)
        imageHost.addSubview(unreadIndicatorView)

        placeholderGlyph.translatesAutoresizingMaskIntoConstraints = false
        placeholderGlyph.contentMode = .scaleAspectFit
        placeholderGlyph.tintColor = .tertiaryLabel
        placeholderGlyph.isHidden = true
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
            placeholderGlyph.image = UIImage(systemName: "envelope", withConfiguration: cfg)
        }
        imageHost.addSubview(placeholderGlyph)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = .systemFont(ofSize: 12, weight: .regular)
        placeholderLabel.textColor = .tertiaryLabel
        placeholderLabel.text = "No image"
        placeholderLabel.isHidden = true
        imageHost.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            imageHost.topAnchor.constraint(equalTo: card.topAnchor),
            imageHost.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageHost.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageHost.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            imageHost.heightAnchor.constraint(equalToConstant: 200),

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

            unreadIndicatorView.topAnchor.constraint(equalTo: imageHost.topAnchor, constant: 14),
            unreadIndicatorView.leadingAnchor.constraint(equalTo: imageHost.leadingAnchor, constant: 14),
            unreadIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicatorView.heightAnchor.constraint(equalToConstant: 8),

            placeholderGlyph.centerXAnchor.constraint(equalTo: imageHost.centerXAnchor),
            placeholderGlyph.centerYAnchor.constraint(equalTo: imageHost.centerYAnchor, constant: -10),
            placeholderGlyph.widthAnchor.constraint(equalToConstant: 34),
            placeholderGlyph.heightAnchor.constraint(equalToConstant: 26),

            placeholderLabel.centerXAnchor.constraint(equalTo: imageHost.centerXAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: placeholderGlyph.bottomAnchor, constant: 8)
        ])
    }

    open override func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        let style = attributes.style

        card.backgroundColor = style.backgroundColor
        card.layer.cornerRadius = 18
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }

        unreadIndicatorView.backgroundColor = style.unreadBadgeColor
        unreadIndicatorView.isHidden = message.isRead

        // Pin chip is image-friendly white-on-glass; only the glyph reacts to style.
        let isPinned = attributes.pinningEnabled && PushwooshInboxKitAttributes.isPinned(message)
        pinChip.isHidden = !isPinned || !attributes.pinIndicatorVisible
        if isPinned && attributes.pinIndicatorVisible {
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else if #available(iOS 13.0, *) {
                let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        let hasImage = !(message.imageUrl?.isEmpty ?? true)
        if hasImage, let urlString = message.imageUrl {
            placeholderGlyph.isHidden = true
            placeholderLabel.isHidden = true
            imageHost.backgroundColor = .secondarySystemFill
            messageImageView.isHidden = false
            MessageImageLoader.shared.load(urlString, into: messageImageView, placeholder: style.imagePlaceholder)
        } else if let placeholder = style.imagePlaceholder {
            placeholderGlyph.isHidden = true
            placeholderLabel.isHidden = true
            imageHost.backgroundColor = .secondarySystemFill
            messageImageView.isHidden = false
            messageImageView.image = placeholder
        } else {
            placeholderGlyph.isHidden = false
            placeholderLabel.isHidden = false
            imageHost.backgroundColor = .secondarySystemFill
            messageImageView.isHidden = true
            messageImageView.image = nil
        }
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: messageImageView)
        messageImageView.image = nil
        placeholderGlyph.isHidden = true
        placeholderLabel.isHidden = true
        pinChip.isHidden = true
    }
}
#endif
