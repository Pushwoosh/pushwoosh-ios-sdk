//
//  PWSheetInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 02.07.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Bottom sheet: slides up from the bottom edge with a grabber, inset media,
//  left-aligned copy and stacked action buttons. Drag down to dismiss — the
//  sheet follows the finger and springs back if released early. Surface is
//  Liquid Glass on iOS 26+ (shared PWInAppStyle.makeSurface), solid before.
//
//  `dimsBackground == true` dims the screen behind the card (60% black, the same
//  as Android's `#99000000`), blocks the host and dismisses on an outside tap.
//  `false` drops the backdrop and passes touches outside the sheet through to the
//  app — a floating, non-blocking sheet.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWSheetInAppView: UIView, PWInAppRenderable {

    private enum Metrics {
        static let maxSheetWidth: CGFloat = 480
        static let cornerRadius: CGFloat = 28
        static let mediaInset: CGFloat = 14
        static let mediaCornerRadius: CGFloat = 18
        static let mediaAspect: CGFloat = 0.52
        static let mediaMaxHeightFraction: CGFloat = 0.4
        static let textInset: CGFloat = 24
        static let buttonInset: CGFloat = 20
        static let buttonHeight: CGFloat = 52
        static let dismissThreshold: CGFloat = 90
    }

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppSheetContent
    private var backdrop: UIView?
    private var sheet: UIView!
    private var closeButton: UIButton?
    private var actionsByTag: [Int: PWInAppAction] = [:]

    init(content: PWInAppSheetContent) {
        self.content = content
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Two modes, decided by whether the dim scrim (dimsBackground) is installed —
    // the same rule the modal follows:
    //  - floating (no scrim): an empty-area touch resolves to self, so return nil
    //    and the hosting window passes it through to the app.
    //  - blocking (scrim installed): the interactive scrim claims empty-area
    //    touches, so `hit` is the scrim, never self, and the host stays blocked.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit === self {
            return nil
        }
        return hit
    }

    // A tall sheet — landscape, or simply a lot of copy — grows upward until its
    // top slides under the status bar, and the ✕ rides along: invisible against
    // the bar, and the bar eats the tap. Push it down by the overlap so it always
    // lands on visible surface. Taken from the laid-out geometry rather than
    // `sheet.frame`, so the entrance slide and a drag in progress — both plain
    // transforms — don't read as the sheet having moved clear. Same rule as
    // Android's `closeButton.translationY`.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let close = closeButton else {
            return
        }
        let sheetTop = bounds.height - sheet.bounds.height
        close.transform = CGAffineTransform(translationX: 0, y: max(0, safeAreaInsets.top - sheetTop))
    }

    private func buildUI() {
        if content.dimsBackground {
            // 0.6 and interactive. A plain `makeBackdrop()` is the pass-through
            // default — transparent and untouchable — so `dimBackground: true` used
            // to darken nothing and block nothing, while Android dimmed to
            // `#99000000`, closed on an outside tap, and routed the sheet through a
            // blocking activity. The campaign editor previews the dim too, so both
            // the marketer and the Android build disagreed with what iOS showed.
            let backdrop = PWInAppStyle.makeBackdrop(dimmed: true, opacity: 0.6)
            backdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeTapped)))
            backdrop.translatesAutoresizingMaskIntoConstraints = false
            addSubview(backdrop)
            NSLayoutConstraint.activate([
                backdrop.topAnchor.constraint(equalTo: topAnchor),
                backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
                backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            self.backdrop = backdrop
        }

        let background = content.backgroundColor
        let (surface, contentHost, isGlass) = PWInAppStyle.makeSurface(
            glassTint: background.withAlphaComponent(0.72),
            solidColor: background,
            cornerRadius: Metrics.cornerRadius)
        sheet = surface
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        if !isGlass {
            PWInAppStyle.applyCardShadow(sheet)
        }
        sheet.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheet)
        if content.dimsBackground {
            sheet.accessibilityViewIsModal = true
        }

        let grabber = UIView()
        // Contrast against the card, not the device theme: `tertiaryLabel` follows
        // the theme, so a white campaign card in dark mode got a near-white grabber
        // and the sheet read as having no handle at all. Same luminance rule and the
        // same 0.3 alpha as Android's grabberColor (#4D000000 / #4DFFFFFF).
        grabber.backgroundColor = PWInAppStyle.contrastColor(on: background).withAlphaComponent(0.3)
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(grabber)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentHost.addSubview(stack)

        if let imageURL = content.imageURL {
            addInsetMedia(imageURL, to: stack)
        }

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.isLayoutMarginsRelativeArrangement = true
        textStack.layoutMargins = UIEdgeInsets(top: content.imageURL == nil ? 8 : 2,
                                               left: Metrics.textInset,
                                               bottom: 0,
                                               right: Metrics.textInset)
        if let title = content.title {
            let label = PWInAppStyle.makeLabel(title, font: PWInAppStyle.rounded(22, .heavy), fallback: .label)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            textStack.addArrangedSubview(label)
        }
        if let message = content.message {
            let label = PWInAppStyle.makeLabel(message, font: PWInAppStyle.rounded(15, .regular),
                                               fallback: .secondaryLabel)
            textStack.addArrangedSubview(label)
        }
        if !textStack.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(textStack)
        }

        let buttonsStack = UIStackView()
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 10
        buttonsStack.isLayoutMarginsRelativeArrangement = true
        buttonsStack.layoutMargins = UIEdgeInsets(top: 10,
                                                  left: Metrics.buttonInset,
                                                  bottom: 0,
                                                  right: Metrics.buttonInset)
        for (index, model) in content.buttons.enumerated() {
            buttonsStack.addArrangedSubview(makeButton(model, tag: index))
        }
        if !content.buttons.isEmpty {
            stack.addArrangedSubview(buttonsStack)
        }

        // Must outrank the labels' horizontal compression resistance (750),
        // or a long single-line text inflates the sheet past the screen up to
        // the iPad width cap. 999, not required — the cap must stay satisfiable.
        let fillWidth = sheet.widthAnchor.constraint(equalTo: widthAnchor)
        fillWidth.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            sheet.centerXAnchor.constraint(equalTo: centerXAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.maxSheetWidth),
            fillWidth,

            grabber.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: 8),
            grabber.centerXAnchor.constraint(equalTo: contentHost.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),

            stack.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentHost.safeAreaLayoutGuide.bottomAnchor,
                                          constant: -16),
        ])

        if content.showCloseButton {
            let close = PWInAppStyle.makeCloseButton()
            contentHost.addSubview(close)
            close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            NSLayoutConstraint.activate([
                close.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: 16),
                // The sheet is edge-to-edge, so its trailing edge is the screen's:
                // in landscape a cutout or the nav bar sits right on the button and
                // eats the tap. The safe area guide keeps it clear, like Android
                // adding insets.right to the button's end margin.
                close.trailingAnchor.constraint(equalTo: contentHost.safeAreaLayoutGuide.trailingAnchor,
                                                constant: -16),
            ])
            closeButton = close
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sheet.addGestureRecognizer(pan)
    }

    private func addInsetMedia(_ imageURL: URL, to stack: UIStackView) {
        let container = UIView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Metrics.mediaCornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = .quaternarySystemFill
        // The loaded image brings its own intrinsic size, and an image view defends
        // it with compression resistance 750 — the same priority as the ratio below.
        // Two demands of equal weight pulling opposite ways leave the height to the
        // solver, so a square or portrait cover came out taller than width × 0.52
        // and cropped differently than on Android, where onMeasure sets the height
        // outright. Dropping the intrinsic priorities makes the ratio the one that
        // decides. Same four lines the modal already carries.
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        // Joins the hierarchy before the caps below are activated: they reference
        // this view's safeAreaLayoutGuide, and Auto Layout throws on a constraint
        // whose anchors have no common ancestor — every sheet with a cover crashed.
        stack.addArrangedSubview(container)

        // In landscape the sheet has ~400pt of height to live in, and the cover at
        // width × 0.52 alone takes more than that: the copy and the buttons get laid
        // out past the sheet's top edge, off screen, with no scrolling to reach them.
        // So the ratio is only a preference, capped at a share of the available
        // height — Android clamps the same way in CoverImage.onMeasure. The lower
        // priority equal-to-cap constraint is what sizes the cover once the ratio
        // gives way, instead of leaving its height to the solver's discretion.
        let ratio = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor,
                                                      multiplier: Metrics.mediaAspect)
        ratio.priority = .defaultHigh
        let atCap = imageView.heightAnchor.constraint(equalTo: safeAreaLayoutGuide.heightAnchor,
                                                      multiplier: Metrics.mediaMaxHeightFraction)
        atCap.priority = UILayoutPriority(749)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.mediaInset),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Metrics.mediaInset),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ratio,
            atCap,
            imageView.heightAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.heightAnchor,
                                              multiplier: Metrics.mediaMaxHeightFraction),
        ])
        PWInAppImageLoader.shared.load(imageURL, into: imageView)
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

    // MARK: - Drag to dismiss

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: self).y
        switch pan.state {
        case .changed:
            sheet.transform = CGAffineTransform(translationX: 0, y: max(0, translation))
        case .ended, .cancelled:
            let velocity = pan.velocity(in: self).y
            if translation > Metrics.dismissThreshold || velocity > 900 {
                onClose?()
            } else {
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8,
                               initialSpringVelocity: 0.3, options: [.allowUserInteraction]) {
                    self.sheet.transform = .identity
                }
            }
        default:
            break
        }
    }

    // MARK: - PWInAppRenderable

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
        if UIAccessibility.isReduceMotionEnabled {
            sheet.alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.backdrop?.alpha = 1
                self.sheet.alpha = 1
            }
            return
        }
        sheet.transform = CGAffineTransform(translationX: 0, y: sheet.bounds.height + 40)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            self.backdrop?.alpha = 1
            self.sheet.transform = .identity
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        let reduce = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduce ? 0.15 : 0.25, delay: 0, options: [.curveEaseIn], animations: {
            self.backdrop?.alpha = 0
            if reduce {
                self.sheet.alpha = 0
            } else {
                self.sheet.transform = CGAffineTransform(translationX: 0, y: self.sheet.bounds.height + 40)
            }
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}
#endif
