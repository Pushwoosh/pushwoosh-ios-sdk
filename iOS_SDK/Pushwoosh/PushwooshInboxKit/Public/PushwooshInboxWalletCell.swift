//
//  PushwooshInboxWalletCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Apple Wallet card: an optional hero image + title/body above the official
//  "Add to Apple Wallet" button. Tapping the button downloads the `.pkpass` and
//  presents the system add-passes sheet. iOS / Mac Catalyst only — PassKit's
//  add-pass UI is unavailable on tvOS.
//

#if canImport(UIKit) && !os(watchOS) && os(iOS)
import UIKit
import PassKit
import PushwooshCore

@objc(PushwooshInboxWalletCell)
open class PushwooshInboxWalletCell: PushwooshInboxCell {

    /// Invoked when the "Add to Apple Wallet" button is tapped. The controller
    /// downloads the `.pkpass` and presents the system add-passes sheet.
    public var onAddToWallet: ((URL) -> Void)?

    private let card = UIView()
    private let imageHost = UIView()
    private let bodyStack = UIStackView()
    private let titleRow = UIView()
    private let pinChip = UIView()
    private let addButton = PKAddPassButton(addPassButtonStyle: .black)

    private var currentPassURL: URL?
    private var imageHostHeight: NSLayoutConstraint?

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installWalletLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installWalletLayout()
    }

    private func installWalletLayout() {
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

        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.axis = .vertical
        bodyStack.alignment = .fill
        bodyStack.distribution = .fill
        bodyStack.spacing = 4
        card.addSubview(bodyStack)

        titleRow.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.addArrangedSubview(titleRow)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        titleRow.addSubview(titleLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textAlignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addSubview(dateLabel)

        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 4
        card.addSubview(unreadIndicatorView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 3
        bodyStack.addArrangedSubview(bodyLabel)

        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(handleAddTap), for: .touchUpInside)
        addButton.accessibilityIdentifier = "inboxkit.wallet.add"
        card.addSubview(addButton)

        let hostHeight = imageHost.heightAnchor.constraint(equalToConstant: 178)
        hostHeight.priority = .required - 1   // yield to UIView-Encapsulated-Layout-Height (self-sizing)
        imageHostHeight = hostHeight

        let addButtonHeight = addButton.heightAnchor.constraint(equalToConstant: 46)
        addButtonHeight.priority = .required - 1   // same: PKAddPassButton has its own intrinsic size

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            imageHost.topAnchor.constraint(equalTo: card.topAnchor, constant: 5.5),
            imageHost.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 5.5),
            imageHost.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -5.5),
            hostHeight,

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
            bodyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            bodyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            // Full-width, symmetric insets so the centered "Add to Apple Wallet" content sits in
            // the middle of the card (not offset right by the body block's unread-dot gutter).
            addButton.topAnchor.constraint(equalTo: bodyStack.bottomAnchor, constant: 14),
            addButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            addButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            addButtonHeight,

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

        installTextGlassPlate(behind: bodyStack, in: card)
    }

    open override func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        let style = attributes.style
        let imageURL = PushwooshInboxKitAttributes.resolvedImageURL(from: message)

        applyGlassBackdrop(in: card, imageURL: imageURL, style: style, cornerRadius: 18)
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        imageHost.backgroundColor = .secondarySystemFill

        currentPassURL = PushwooshInboxWalletPass.decode(from: message)?.passURL

        let hasImage = imageURL != nil
        imageHost.isHidden = !hasImage
        imageHostHeight?.constant = hasImage ? 178 : 0
        if hasImage, let urlString = imageURL {
            MessageImageLoader.shared.load(urlString, into: messageImageView, placeholder: style.imagePlaceholder)
        } else {
            messageImageView.image = nil
        }

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
        // so a recycled cell doesn't lose the glass plate behind its text block.
        textGlassPlate?.isHidden = !style.isLiquidGlass

        let isPinned = attributes.pinningEnabled && PushwooshInboxKitAttributes.isPinned(message)
        pinChip.isHidden = !isPinned || !attributes.pinIndicatorVisible || !hasImage
        if isPinned && attributes.pinIndicatorVisible && hasImage {
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else {                let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        // Hide the add button when there is no pass or the device can't add passes
        // (e.g. passes restricted) — the card then reads as a normal captioned card.
        let canAdd = currentPassURL != nil && PKAddPassesViewController.canAddPasses()
        addButton.isHidden = !canAdd
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: messageImageView)
        messageImageView.image = nil
        pinChip.isHidden = true
        currentPassURL = nil
        card.layer.removeAllAnimations()
        card.transform = .identity
        unreadIndicatorView.isHidden = true
        addButton.isHidden = true
        textGlassPlate?.isHidden = true
    }

    /// Subtle press feedback for taps that land on the card chrome (outside the Add button).
    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: highlighted ? 0.12 : 0.28, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.card.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
    }

    @objc private func handleAddTap() {
        guard let url = currentPassURL else { return }
        onAddToWallet?(url)
    }
}
#endif
