//
//  PWBannerInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Compact, non-blocking toast pinned to the top or bottom edge — mirrors
//  CleverTap's header/footer templates. Slides in, optionally auto-dismisses,
//  swipe toward its edge to dismiss, tap to fire the action. Touches outside the
//  bar fall through to the app (the hosting window only captures the bar).
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWBannerInAppView: UIView, PWInAppRenderable, UIGestureRecognizerDelegate {

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppBannerContent
    private var card: UIView!
    private var autoDismissTimer: Timer?

    init(content: PWInAppBannerContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        autoDismissTimer?.invalidate()
    }

    private func buildUI() {
        // Glass bar floats over the live app (the banner window is pass-through),
        // so the material refracts real content; solid dark bar before iOS 26.
        let (surface, contentHost, isGlass) = PWInAppStyle.makeSurface(
            glassTint: content.backgroundColor.withAlphaComponent(0.5),
            solidColor: content.backgroundColor,
            cornerRadius: 18)
        card = surface
        if !isGlass {
            PWInAppStyle.applyCardShadow(card)
        }
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(row)

        if let imageURL = content.imageURL {
            let thumb = UIImageView()
            thumb.contentMode = .scaleAspectFill
            thumb.clipsToBounds = true
            thumb.layer.cornerRadius = 12
            thumb.layer.cornerCurve = .continuous
            thumb.translatesAutoresizingMaskIntoConstraints = false
            thumb.widthAnchor.constraint(equalToConstant: 52).isActive = true
            thumb.heightAnchor.constraint(equalToConstant: 52).isActive = true
            PWInAppImageLoader.shared.load(imageURL, into: thumb)
            row.addArrangedSubview(thumb)
        }

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        if let title = content.title {
            textStack.addArrangedSubview(makeLabel(title, font: PWInAppStyle.rounded(16, .semibold), fallback: .white))
        }
        if let message = content.message {
            let label = makeLabel(message, font: PWInAppStyle.rounded(13, .regular),
                                  fallback: UIColor.white.withAlphaComponent(0.7))
            label.numberOfLines = 2
            textStack.addArrangedSubview(label)
        }
        row.addArrangedSubview(textStack)

        if content.showCloseButton {
            let close = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            close.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
            close.accessibilityLabel = "Close"
            close.tintColor = UIColor.white.withAlphaComponent(0.6)
            close.translatesAutoresizingMaskIntoConstraints = false
            close.widthAnchor.constraint(equalToConstant: 24).isActive = true
            close.heightAnchor.constraint(equalToConstant: 24).isActive = true
            close.setContentHuggingPriority(.required, for: .horizontal)
            close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            row.addArrangedSubview(close)
        }

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
    }

    private func makeLabel(_ text: PWInAppText, font: UIFont, fallback: UIColor) -> UILabel {
        PWInAppStyle.makeLabel(text, font: font, fallback: fallback, lines: 1)
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        tap.delegate = self
        card.addGestureRecognizer(tap)

        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(closeTapped))
        swipe.direction = (content.position == .top) ? .up : .down
        card.addGestureRecognizer(swipe)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view is UIControl)
    }

    @objc private func bannerTapped() {
        onAction?(content.action)
    }

    @objc private func closeTapped() {
        onClose?()
    }

    func present(in container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)

        let edge: NSLayoutConstraint
        switch content.position {
        case .top:
            edge = topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 10)
        case .bottom:
            edge = bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        }
        NSLayoutConstraint.activate([
            edge,
            leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
        ])
        container.layoutIfNeeded()

        let hidden = bounds.height + 40
        transform = CGAffineTransform(translationX: 0, y: content.position == .top ? -hidden : hidden)
        alpha = 0
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.84,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            self.transform = .identity
            self.alpha = 1
        } completion: { _ in
            self.scheduleAutoDismiss()
        }
    }

    private func scheduleAutoDismiss() {
        guard content.autoDismiss > 0 else {
            return
        }
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: content.autoDismiss, repeats: false) { [weak self] _ in
            self?.onClose?()
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        autoDismissTimer?.invalidate()
        let hidden = bounds.height + 40
        UIView.animate(withDuration: 0.25, animations: {
            self.transform = CGAffineTransform(translationX: 0, y: self.content.position == .top ? -hidden : hidden)
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}
#endif
