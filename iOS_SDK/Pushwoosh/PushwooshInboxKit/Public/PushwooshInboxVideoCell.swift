//
//  PushwooshInboxVideoCell.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 16.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Video card: a poster preview with a play badge over the message title / body. There is no
//  in-cell playback — tapping the preview opens a full-screen player (handled by the controller).
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

@objc(PushwooshInboxVideoCell)
open class PushwooshInboxVideoCell: PushwooshInboxCell {

    /// Invoked when the video preview is tapped. The controller opens a full-screen player.
    public var onVideoTap: ((URL) -> Void)?

    private static let posterHeight: CGFloat = 190

    private let card = UIView()
    private let posterView = UIImageView()
    private let playBadge = UIImageView()
    private let bodyStack = UIStackView()
    private let titleRow = UIView()
    private let pinChip = UIView()

    private var currentVideoURL: URL?
    private var bodyTopConstraint: NSLayoutConstraint?
    private var bodyBottomConstraint: NSLayoutConstraint?

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        installVideoLayout()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installVideoLayout()
    }

    private func installVideoLayout() {
        resetInheritedLayout()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.masksToBounds = true
        contentView.addSubview(card)

        posterView.translatesAutoresizingMaskIntoConstraints = false
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 16
        posterView.layer.cornerCurve = .continuous
        posterView.backgroundColor = .secondarySystemFill
        posterView.isUserInteractionEnabled = true
        card.addSubview(posterView)

        // Centered play affordance — signals the poster is a video and is the tap target.
        playBadge.translatesAutoresizingMaskIntoConstraints = false
        playBadge.contentMode = .scaleAspectFit
        playBadge.tintColor = .white
        playBadge.layer.shadowColor = UIColor.black.cgColor
        playBadge.layer.shadowOpacity = 0.35
        playBadge.layer.shadowRadius = 6
        playBadge.layer.shadowOffset = CGSize(width: 0, height: 2)
        let cfg = UIImage.SymbolConfiguration(pointSize: 54, weight: .regular)
        playBadge.image = UIImage(systemName: "play.circle.fill", withConfiguration: cfg)
        posterView.addSubview(playBadge)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleVideoTap))
        posterView.addGestureRecognizer(tap)

        // The poster is the tap target; expose it to VoiceOver/automation as a play button.
        posterView.isAccessibilityElement = true
        posterView.accessibilityTraits = [.button, .startsMediaSession]
        posterView.accessibilityLabel = "Play video"
        posterView.accessibilityIdentifier = "inboxkit.video.play"

        pinChip.translatesAutoresizingMaskIntoConstraints = false
        pinChip.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        pinChip.layer.cornerRadius = 15
        pinChip.layer.cornerCurve = .continuous
        pinChip.isHidden = true
        posterView.addSubview(pinChip)

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
        titleLabel.numberOfLines = 1
        titleRow.addSubview(titleLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.textAlignment = .right
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addSubview(dateLabel)

        unreadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        unreadIndicatorView.layer.cornerRadius = 4
        card.addSubview(unreadIndicatorView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 2
        bodyStack.addArrangedSubview(bodyLabel)

        let bodyTop = bodyStack.topAnchor.constraint(equalTo: posterView.bottomAnchor, constant: 12)
        let bodyBottom = bodyStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        bodyTopConstraint = bodyTop
        bodyBottomConstraint = bodyBottom

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            posterView.topAnchor.constraint(equalTo: card.topAnchor, constant: 5.5),
            posterView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 5.5),
            posterView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -5.5),
            {
                let c = posterView.heightAnchor.constraint(equalToConstant: Self.posterHeight)
                c.priority = .required - 1   // yield to UIView-Encapsulated-Layout-Height (self-sizing)
                return c
            }(),

            playBadge.centerXAnchor.constraint(equalTo: posterView.centerXAnchor),
            playBadge.centerYAnchor.constraint(equalTo: posterView.centerYAnchor),
            playBadge.widthAnchor.constraint(equalToConstant: 56),
            playBadge.heightAnchor.constraint(equalToConstant: 56),

            pinChip.topAnchor.constraint(equalTo: posterView.topAnchor, constant: 14),
            pinChip.trailingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: -14),
            pinChip.widthAnchor.constraint(equalToConstant: 30),
            pinChip.heightAnchor.constraint(equalToConstant: 30),

            pinIndicatorView.centerXAnchor.constraint(equalTo: pinChip.centerXAnchor),
            pinIndicatorView.centerYAnchor.constraint(equalTo: pinChip.centerYAnchor),
            pinIndicatorView.widthAnchor.constraint(equalToConstant: 14),
            pinIndicatorView.heightAnchor.constraint(equalToConstant: 14),

            bodyTop,
            bodyStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 32),
            bodyStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            bodyBottom,

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

        let content = PushwooshInboxVideoContent.decode(from: message)
        currentVideoURL = content?.videoURL
        playBadge.isHidden = (content == nil)

        // Video cards carry the image in the poster, not message.imageUrl — use it for the backdrop.
        applyGlassBackdrop(in: card, imageURL: content?.posterURL ?? message.imageUrl, style: style, cornerRadius: 20)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous

        if let poster = content?.posterURL {
            MessageImageLoader.shared.load(poster, into: posterView, placeholder: style.imagePlaceholder)
        } else {
            posterView.image = style.imagePlaceholder
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

        let isPinned = attributes.pinningEnabled && PushwooshInboxKitAttributes.isPinned(message)
        pinChip.isHidden = !isPinned || !attributes.pinIndicatorVisible
        if isPinned && attributes.pinIndicatorVisible {
            if let custom = style.pinIndicatorImage {
                pinIndicatorView.image = custom
            } else {                let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
                pinIndicatorView.image = UIImage(systemName: "pin.fill", withConfiguration: cfg)
            }
        }

        let hasTitle = !(message.title?.isEmpty ?? true)
        let hasBody = !(message.message?.isEmpty ?? true)
        let hasText = hasTitle || hasBody
        titleRow.isHidden = !hasTitle
        bodyLabel.isHidden = !hasBody
        bodyStack.isHidden = !hasText
        // Gate on isLiquidGlass: the plate is an opt-in iOS 26 glass surface, and re-asserting it
        // here (not just in installTextGlassPlate) restores visibility after a prepareForReuse hide.
        textGlassPlate?.isHidden = !(style.isLiquidGlass && hasText)
        bodyTopConstraint?.constant = hasText ? 12 : 0
        bodyBottomConstraint?.constant = hasText ? -14 : 0
        unreadIndicatorView.isHidden = message.isRead || !hasText
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        MessageImageLoader.shared.cancelLoad(for: posterView)
        posterView.image = nil
        pinChip.isHidden = true
        currentVideoURL = nil
        card.layer.removeAllAnimations()
        card.transform = .identity
        unreadIndicatorView.isHidden = true
        textGlassPlate?.isHidden = true
    }

    /// Subtle press feedback for taps that land on the card chrome (text block, margins).
    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: highlighted ? 0.12 : 0.28, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.card.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
    }

    @objc private func handleVideoTap() {
        guard let url = currentVideoURL else { return }
        onVideoTap?(url)
    }
}
#endif
