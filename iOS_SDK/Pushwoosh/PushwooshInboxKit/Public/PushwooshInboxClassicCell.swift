//
//  PushwooshInboxClassicCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 30.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Apple-stock baseline: compact text-first card with a 44pt single-letter
//  avatar, accent unread dot at the leading edge, optional inline CTAs
//  underneath. Mirrors Braze's "Classic" card type.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

@objc(PushwooshInboxClassicCell)
open class PushwooshInboxClassicCell: PushwooshInboxCell {

    private let card = UIView()
    private let avatar = UIView()
    private let avatarImageView = UIImageView()
    private let initialLabel = UILabel()
    private let bodyStack = UIStackView()
    private let titleRow = UIView()

    /// First letter of the host app's display name, uppercased. Cached.
    public static let appInitial: String = {
        let info = Bundle.main.infoDictionary
        let name = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? ""
        return String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }()

    /// Host app's launch icon, loaded from `CFBundleIcons`. Cached. Returns
    /// `nil` if the app doesn't ship a primary icon (rare).
    public static let appIconImage: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let lastName = files.last,
              let image = UIImage(named: lastName)
        else { return nil }
        return image
    }()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installClassicLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installClassicLayout()
    }

    private func installClassicLayout() {
        resetInheritedLayout()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.masksToBounds = true
        contentView.addSubview(card)

        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 4
        card.addSubview(unreadIndicatorView)

        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.layer.cornerRadius = 22
        avatar.layer.masksToBounds = true
        if #available(iOS 13.0, *) { avatar.layer.cornerCurve = .continuous }
        card.addSubview(avatar)

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.isHidden = true
        avatar.addSubview(avatarImageView)

        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        initialLabel.font = .systemFont(ofSize: 18, weight: .medium)
        initialLabel.textColor = .white
        initialLabel.textAlignment = .center
        avatar.addSubview(initialLabel)

        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.axis = .vertical
        bodyStack.alignment = .fill
        bodyStack.distribution = .fill
        bodyStack.spacing = 1
        card.addSubview(bodyStack)

        titleRow.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.addArrangedSubview(titleRow)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleRow.addSubview(titleLabel)

        pinIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        pinIndicatorView.contentMode = .scaleAspectFit
        pinIndicatorView.isHidden = true
        titleRow.addSubview(pinIndicatorView)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textAlignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addSubview(dateLabel)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 2
        bodyStack.addArrangedSubview(bodyLabel)

        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.isHidden = true
        bodyStack.addArrangedSubview(buttonsStack)
        bodyStack.setCustomSpacing(10, after: bodyLabel)

        // Avatar centerY is best-effort — top/bottom inequalities at .required
        // win on very short cards (single-line body, no buttons) so we never
        // log Auto Layout warnings when math forces avatar above 14pt padding.
        let avatarCenterY = avatar.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        avatarCenterY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            unreadIndicatorView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            unreadIndicatorView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            unreadIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicatorView.heightAnchor.constraint(equalToConstant: 8),

            // Avatar sits 12pt to the right of the unread dot (dot ends at
            // card.leading + 14: 6pt inset + 8pt diameter). Same 12pt gap
            // separates avatar trailing from the body stack — three equal
            // visual gaps: card-edge → dot → avatar → text.
            avatar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 26),
            avatarCenterY,
            avatar.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 14),
            avatar.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),

            avatarImageView.topAnchor.constraint(equalTo: avatar.topAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: avatar.leadingAnchor),
            avatarImageView.trailingAnchor.constraint(equalTo: avatar.trailingAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: avatar.bottomAnchor),

            initialLabel.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),

            bodyStack.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            bodyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            bodyStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),

            card.bottomAnchor.constraint(greaterThanOrEqualTo: bodyStack.bottomAnchor, constant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinIndicatorView.leadingAnchor, constant: -6),

            pinIndicatorView.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            pinIndicatorView.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -6),
            pinIndicatorView.widthAnchor.constraint(equalToConstant: 11),
            pinIndicatorView.heightAnchor.constraint(equalToConstant: 11),

            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor)
        ])
    }

    open override func apply(message: PWInboxMessageProtocol, attributes: PushwooshInboxKitAttributes) {
        let style = attributes.style

        card.backgroundColor = style.backgroundColor
        card.layer.cornerRadius = 18
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }

        // Avatar — three-tier fallback:
        //   1. message.imageUrl (server-supplied) — load via shared loader.
        //   2. App bundle icon — host app's launch icon.
        //   3. First letter of the host app's display name on a tinted circle.
        let hasMessageImage = !(message.imageUrl?.isEmpty ?? true)
        if hasMessageImage, let urlString = message.imageUrl {
            MessageImageLoader.shared.load(urlString,
                                           into: avatarImageView,
                                           placeholder: PushwooshInboxClassicCell.appIconImage)
            avatarImageView.isHidden = false
            initialLabel.isHidden = true
            avatar.backgroundColor = .clear
        } else if let icon = PushwooshInboxClassicCell.appIconImage {
            avatarImageView.image = icon
            avatarImageView.isHidden = false
            initialLabel.isHidden = true
            avatar.backgroundColor = .clear
        } else {
            avatarImageView.image = nil
            avatarImageView.isHidden = true
            initialLabel.isHidden = false
            let letter = PushwooshInboxClassicCell.appInitial
            initialLabel.text = letter.isEmpty ? "·" : letter
            avatar.backgroundColor = message.isRead ? .systemGray : style.unreadBadgeColor
        }

        let title = (message.title?.isEmpty == false) ? (message.title ?? "") : (message.message ?? "")

        titleLabel.text = title
        titleLabel.font = message.isRead
            ? .systemFont(ofSize: 15.5, weight: .regular)
            : .systemFont(ofSize: 15.5, weight: .semibold)
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
        pinIndicatorView.isHidden = !isPinned
        if isPinned {
            pinIndicatorView.tintColor = style.pinIndicatorColor
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else if #available(iOS 13.0, *) {
                let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        let buttons = attributes.inlineButtonsEnabled ? PushwooshInboxButton.decode(from: message) : []
        applyButtons(buttons, style: style)
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: avatarImageView)
        avatar.backgroundColor = .systemGray
        avatarImageView.image = nil
        avatarImageView.isHidden = true
        initialLabel.text = nil
        initialLabel.isHidden = false
        pinIndicatorView.isHidden = true
        buttonsStack.isHidden = true
    }
}
#endif
