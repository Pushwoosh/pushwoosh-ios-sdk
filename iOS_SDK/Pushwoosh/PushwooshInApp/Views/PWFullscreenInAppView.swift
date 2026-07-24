//
//  PWFullscreenInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Edge-to-edge takeover: full-bleed image, gradient scrim, overlaid title,
//  message and buttons. Mirrors CleverTap's cover / interstitial.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWFullscreenInAppView: UIView, PWInAppRenderable {

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppFullscreenContent
    private let imageView = UIImageView()
    private let scrim = PWGradientScrimView()
    private var actionsByTag: [Int: PWInAppAction] = [:]

    init(content: PWInAppFullscreenContent) {
        self.content = content
        super.init(frame: .zero)
        backgroundColor = content.backgroundColor
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        // Full-screen fills the screen with the image (cover), like Braze/CleverTap/Airship:
        // a matching ratio shows whole, a wider source is cropped left/right, a taller one is
        // cropped top/bottom — centered. Keep key content centered (see marketer guidance).
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        PWInAppImageLoader.shared.load(content.imageURL, into: imageView)
        addSubview(imageView)

        scrim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrim)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if let title = content.title {
            stack.addArrangedSubview(makeLabel(title, font: PWInAppStyle.rounded(30, .bold), fallback: .white))
        }
        if let message = content.message {
            stack.addArrangedSubview(makeLabel(message, font: PWInAppStyle.rounded(16, .regular),
                                               fallback: UIColor.white.withAlphaComponent(0.85)))
        }

        if !content.buttons.isEmpty {
            let buttons = UIStackView()
            buttons.axis = .vertical
            buttons.spacing = 10
            for (index, model) in content.buttons.enumerated() {
                buttons.addArrangedSubview(makeButton(model, tag: index))
            }
            if let last = stack.arrangedSubviews.last {
                stack.setCustomSpacing(20, after: last)
            }
            stack.addArrangedSubview(buttons)
        }

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrim.topAnchor.constraint(equalTo: stack.topAnchor, constant: -48),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -28),
        ])

        // A full-screen takeover blocks the app; buttons dismiss it (any action
        // closes it), so with none the close chip must show even if the campaign
        // hid it — otherwise there is no way out.
        let hasGuaranteedDismissPath = !content.buttons.isEmpty
        if content.showCloseButton || !hasGuaranteedDismissPath {
            let close = PWInAppStyle.makeCloseButton()
            addSubview(close)
            close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            NSLayoutConstraint.activate([
                close.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
                close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            ])
        }
    }

    private func makeLabel(_ text: PWInAppText, font: UIFont, fallback: UIColor) -> UILabel {
        PWInAppStyle.makeLabel(text, font: font, fallback: fallback)
    }

    private func makeButton(_ model: PWInAppButton, tag: Int) -> UIButton {
        let button = PWInAppStyle.makeContractButton(model)
        button.tag = tag
        actionsByTag[tag] = model.action
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        if let action = actionsByTag[sender.tag] {
            onAction?(action)
        }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    func present(in container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.22, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}
#endif
