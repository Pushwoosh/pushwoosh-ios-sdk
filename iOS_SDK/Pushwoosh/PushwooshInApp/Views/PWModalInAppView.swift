//
//  PWModalInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Centered card modal with inset media: the image floats inside the card with
//  its own continuous-corner radius, so it composes with any campaign
//  background color. A glass close chip rides the top-right corner, copy is set
//  in the module's rounded face with real line spacing, and the primary action
//  glows with its own color. The card is width-capped so it stays a card on
//  iPad and enters with a lift-up spring.
//
//  The image is never cropped: the media well takes the picture's real aspect
//  ratio at full width, and when the picture is too tall for the safe-area cap
//  the well stops at the cap and `scaleAspectFit` shows the whole picture inside
//  it, letterboxed on the sides against the card. Text and buttons always stay
//  on screen, and there is no scrolling.
//
//  On iOS 26+ the card surface is Liquid Glass (`UIGlassEffect`) tinted with
//  the campaign background color; older systems (and the pre-26 CI toolchain,
//  hence the `#if compiler(>=6.2)` gates) fall back to the solid card.
//
//  `dimsBackground == true` renders a dark scrim behind the card that blocks the
//  host app and dismisses on a tap outside the card (parity with Android's modal).
//  `dimsBackground == false` drops the backdrop entirely and makes the empty area
//  pass touches through to the app — a floating, non-blocking card.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWModalInAppView: UIView, PWInAppRenderable {

    private enum Metrics {
        static let maxCardWidth: CGFloat = 400
        static let sideInset: CGFloat = 28
        static let mediaInset: CGFloat = 14
        static let mediaCornerRadius: CGFloat = 18
        static let mediaMinHeight: CGFloat = 180
        static let mediaAspectPriority = UILayoutPriority(740)
        static let cardVerticalInset: CGFloat = 24
        static let textInset: CGFloat = 24
        static let buttonInset: CGFloat = 20
        static let buttonHeight: CGFloat = 52
        static let closeInset: CGFloat = 20
    }

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppModalContent
    var backdrop: UIView?
    private var card: UIView!
    private var actionsByTag: [Int: PWInAppAction] = [:]

    init(content: PWInAppModalContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Two modes, decided by whether the dim scrim (dimsBackground) is installed:
    //  - floating (no scrim): an empty-area touch resolves to self, so return nil
    //    and the hosting window passes it through to the app.
    //  - blocking (scrim installed): the interactive scrim claims empty-area
    //    touches, so `hit` is the scrim (never self) and the host stays blocked.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit === self {
            return nil
        }
        return hit
    }

    private func buildUI() {
        if content.dimsBackground {
            let dim = UIView()
            dim.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            dim.translatesAutoresizingMaskIntoConstraints = false
            addSubview(dim)
            NSLayoutConstraint.activate([
                dim.topAnchor.constraint(equalTo: topAnchor),
                dim.bottomAnchor.constraint(equalTo: bottomAnchor),
                dim.leadingAnchor.constraint(equalTo: leadingAnchor),
                dim.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backdropTapped)))
            backdrop = dim
        }

        let contentHost = makeCardSurface()
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        if content.dimsBackground {
            card.accessibilityViewIsModal = true
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(stack)

        let hasImage = content.imageURL != nil
        if let imageURL = content.imageURL {
            stack.addArrangedSubview(makeInsetMedia(imageURL))
        }

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.isLayoutMarginsRelativeArrangement = true
        textStack.layoutMargins = UIEdgeInsets(top: hasImage ? 4 : 30,
                                               left: Metrics.textInset,
                                               bottom: 0,
                                               right: Metrics.textInset)

        if let title = content.title {
            let label = PWInAppStyle.makeLabel(title, font: PWInAppStyle.rounded(24, .heavy),
                                               fallback: .label, alignment: .center)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            textStack.addArrangedSubview(label)
        }
        if let message = content.message {
            textStack.addArrangedSubview(makeMessageLabel(message))
        }
        if !textStack.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(textStack)
        }

        let buttonsStack = UIStackView()
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 10
        buttonsStack.isLayoutMarginsRelativeArrangement = true
        buttonsStack.layoutMargins = UIEdgeInsets(top: 8,
                                                  left: Metrics.buttonInset,
                                                  bottom: Metrics.buttonInset,
                                                  right: Metrics.buttonInset)
        for (index, model) in content.buttons.enumerated() {
            buttonsStack.addArrangedSubview(makeButton(model, tag: index))
        }
        if content.buttons.isEmpty {
            buttonsStack.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: Metrics.buttonInset, right: 0)
        }
        stack.addArrangedSubview(buttonsStack)

        // 999 outranks the labels' horizontal compression resistance (750) so a
        // long single-line text can't inflate the card to the iPad width cap.
        let fillWidth = card.widthAnchor.constraint(equalTo: widthAnchor,
                                                    constant: -Metrics.sideInset * 2)
        fillWidth.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Metrics.sideInset),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metrics.sideInset),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.maxCardWidth),
            card.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: Metrics.cardVerticalInset),
            card.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -Metrics.cardVerticalInset),
            fillWidth,

            stack.topAnchor.constraint(equalTo: contentHost.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
        ])

        // Buttons dismiss the modal (any action closes it); with none, the close
        // chip is the only way out and must show even when the campaign hid it.
        let hasGuaranteedDismissPath = !content.buttons.isEmpty
        if content.showCloseButton || !hasGuaranteedDismissPath {
            let close = PWInAppStyle.makeCloseButton()
            contentHost.addSubview(close)
            close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            NSLayoutConstraint.activate([
                close.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: Metrics.closeInset),
                close.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor, constant: -Metrics.closeInset),
            ])
        }
    }

    /// Builds the card surface and returns the view content should be added to.
    /// iOS 26+: Liquid Glass tinted with the campaign background; otherwise a
    /// solid card with the module shadow. Sets `card` as a side effect.
    private func makeCardSurface() -> UIView {
        let background = content.backgroundColor
        let (surface, contentHost, isGlass) = PWInAppStyle.makeSurface(
            glassTint: background.withAlphaComponent(0.55),
            solidColor: background,
            cornerRadius: PWInAppStyle.cardCornerRadius)
        if !isGlass {
            PWInAppStyle.applyCardShadow(surface)
        }
        card = surface
        return contentHost
    }

    /// Image floating inside the card with its own continuous corners — no
    /// corner-mask coupling to the card, composes with any campaign background.
    private func makeInsetMedia(_ imageURL: URL) -> UIView {
        let container = UIView()
        let imageView = UIImageView()
        // Fit, not fill: while the well matches the picture's ratio the two are identical, but
        // once a tall picture pushes the well into the safe-area cap, fit keeps the whole
        // picture visible (narrower, centered) where fill would have cropped its top and bottom.
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Metrics.mediaCornerRadius
        imageView.layer.cornerCurve = .continuous
        // Transparent backdrop: whenever the image doesn't cover the whole well (mid-load, or a
        // tall picture fitted inside the capped well) the card shows through on the sides
        // instead of a grey box.
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // The aspect constraint (below), not the image's intrinsic size, must drive the well's
        // height — so lower the image view's content priorities on both axes. Otherwise the
        // picture's intrinsic content size outranks the aspect ratio and the well ends up taller
        // than the picture, letterboxing it with grey bands.
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        container.addSubview(imageView)
        // No image ratio yet — a minimum height (Android `minimumHeight` parity) holds the well
        // open under the spinner while loading, so the card neither collapses nor jumps.
        let minHeight = imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: Metrics.mediaMinHeight)
        var aspect: NSLayoutConstraint?
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: Metrics.mediaInset),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.mediaInset),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Metrics.mediaInset),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            minHeight,
        ])
        // Once loaded, the well takes the image's exact aspect ratio at full width — the web
        // editor's `width:100%; height:auto`. The ratio yields to the card's safe-area cap
        // (lower priority), so a picture too tall to fit whole shrinks the well to the cap and
        // `scaleAspectFit` scales the whole picture down inside it instead of cropping.
        PWInAppImageLoader.shared.load(imageURL, into: imageView, onImage: { [weak self, weak imageView] image in
            guard let self = self, let imageView = imageView, image.size.width > 0 else { return }
            let ratio = image.size.height / image.size.width
            // The min-height floor only held the well open while loading; the real ratio now
            // drives height. Drop it so a wide image (ratio·width < floor) gets its true, shorter
            // height instead of being forced to 180pt and cropped by aspectFill.
            minHeight.isActive = false
            aspect?.isActive = false
            aspect = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: ratio)
            aspect?.priority = Metrics.mediaAspectPriority
            aspect?.isActive = true
            UIView.animate(withDuration: 0.25) { self.layoutIfNeeded() }
        })
        return container
    }

    private func makeMessageLabel(_ message: PWInAppText) -> UILabel {
        let label = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.5
        paragraph.alignment = .center
        label.attributedText = NSAttributedString(string: message.text, attributes: [
            .font: PWInAppStyle.rounded(15, .regular),
            .foregroundColor: message.color ?? UIColor.secondaryLabel,
            .paragraphStyle: paragraph,
        ])
        label.numberOfLines = 0
        return label
    }

    private func makeButton(_ model: PWInAppButton, tag: Int) -> UIButton {
        let button = PWInAppStyle.makeContractButton(model)
        button.tag = tag
        actionsByTag[tag] = model.action
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        if let action = actionsByTag[sender.tag] {
            onAction?(action)
        }
    }

    @objc private func buttonDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            sender.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            sender.alpha = 0.9
        }
    }

    @objc private func buttonUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            sender.transform = .identity
            sender.alpha = 1
        }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func backdropTapped() {
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
        container.layoutIfNeeded()

        backdrop?.alpha = 0
        card.alpha = 0
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.2) {
                self.backdrop?.alpha = 1
                self.card.alpha = 1
            }
            return
        }
        card.transform = CGAffineTransform(translationX: 0, y: 22).scaledBy(x: 0.94, y: 0.94)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            self.backdrop?.alpha = 1
            self.card.alpha = 1
            self.card.transform = .identity
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        let reduce = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduce ? 0.15 : 0.22, delay: 0, options: [.curveEaseIn], animations: {
            self.backdrop?.alpha = 0
            self.card.alpha = 0
            if !reduce {
                self.card.transform = CGAffineTransform(translationX: 0, y: 12).scaledBy(x: 0.95, y: 0.95)
            }
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}
#endif
