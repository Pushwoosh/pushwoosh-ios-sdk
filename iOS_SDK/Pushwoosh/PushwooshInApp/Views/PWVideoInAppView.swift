//
//  PWVideoInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Full-screen autoplaying video in-app: AVPlayer engine behind a gradient
//  scrim with title / message / CTA, a mute toggle and a close button.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWVideoInAppView: UIView, PWInAppRenderable {

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppVideoContent
    private let playerView = PWInAppVideoPlayerView()
    private let scrim = PWGradientScrimView()
    private let muteButton = PWInAppChipButton(size: PWInAppStyle.closeSize)
    private var actionsByTag: [Int: PWInAppAction] = [:]

    init(content: PWInAppVideoContent) {
        self.content = content
        super.init(frame: .zero)
        backgroundColor = .black
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)

        scrim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrim)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if let title = content.title {
            stack.addArrangedSubview(makeLabel(title, font: PWInAppStyle.rounded(28, .bold), fallback: .white))
        }
        if let message = content.message {
            stack.addArrangedSubview(makeLabel(message, font: PWInAppStyle.rounded(16, .regular),
                                               fallback: UIColor.white.withAlphaComponent(0.85)))
        }
        if !content.buttons.isEmpty, let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(20, after: last)
        }
        for (index, model) in content.buttons.enumerated() {
            stack.addArrangedSubview(makeCTA(model, tag: index))
        }

        muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        addSubview(muteButton)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrim.topAnchor.constraint(equalTo: stack.topAnchor, constant: -48),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -28),

            muteButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            muteButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
        ])

        // A full-screen video blocks the app; CTA buttons dismiss it (any action
        // closes it), so with none the close chip must show even if the campaign
        // hid it — the mute toggle doesn't dismiss.
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

        playerView.onFailed = { [weak self] in
            self?.onClose?()
        }
        playerView.configure(videoURL: content.videoURL,
                             posterURL: content.posterURL,
                             fallbackImageURL: content.fallbackImageURL,
                             loop: content.loop,
                             muted: content.muted)
        // After configure applies `content.muted` to the player, so the icon reflects the real state.
        updateMuteIcon()
    }

    private func makeLabel(_ text: PWInAppText, font: UIFont, fallback: UIColor) -> UILabel {
        PWInAppStyle.makeLabel(text, font: font, fallback: fallback)
    }

    private func updateMuteIcon() {
        let name = playerView.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.setSymbol(name, pointSize: 13)
        muteButton.accessibilityLabel = playerView.isMuted ? "Unmute" : "Mute"
    }

    @objc private func muteTapped() {
        playerView.setMuted(!playerView.isMuted)
        updateMuteIcon()
    }

    private func makeCTA(_ model: PWInAppButton, tag: Int) -> UIButton {
        let cta = PWInAppStyle.makeContractButton(model)
        cta.tag = tag
        actionsByTag[tag] = model.action
        cta.addTarget(self, action: #selector(ctaTapped(_:)), for: .touchUpInside)
        return cta
    }

    @objc private func ctaTapped(_ sender: UIButton) {
        guard let action = actionsByTag[sender.tag] else { return }
        onAction?(action)
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
        playerView.teardown()
        UIView.animate(withDuration: 0.22, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}
#endif
