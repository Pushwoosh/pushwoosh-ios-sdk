//
//  PWStoriesInAppView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Full-screen, Instagram-style stories in-app: full-bleed images, segmented
//  top progress bars, auto-advance, tap-zone navigation (left third = back,
//  rest = forward), press-and-hold to pause, swipe-down to dismiss, and an
//  optional CTA. Visual + interaction mirror PushwooshStoriesViewController.
//

#if canImport(UIKit) && os(iOS)
import UIKit

final class PWStoriesInAppView: UIView, PWInAppRenderable, UIGestureRecognizerDelegate {

    var onClose: (() -> Void)?
    var onAction: ((PWInAppAction) -> Void)?

    private let content: PWInAppStoriesContent
    private var items: [PWInAppStoryItem] { content.items }

    private let imageView = UIImageView()
    private let scrim = PWGradientScrimView()
    private let progressBar = PWStoriesProgressBar()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let buttonsStack = UIStackView()
    private let closeButton = PWInAppStyle.makeCloseButton()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private var index = 0
    private var displayLink: CADisplayLink?
    private var autoTimer: Timer?
    private var segmentStart: CFTimeInterval = 0
    private var currentDuration: TimeInterval = 5
    private var isPaused = false
    private var pausedElapsed: CFTimeInterval = 0

    init(content: PWInAppStoriesContent) {
        self.content = content
        super.init(frame: .zero)
        backgroundColor = .black
        buildUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
        autoTimer?.invalidate()
    }

    // MARK: - Layout

    private func buildUI() {
        // Stories fills the screen with each frame (cover), matching the web editor's preview
        // (background-size: cover): a matching ratio shows whole, a wider source is cropped
        // left/right, a taller one top/bottom — centered on the black backdrop.
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingIndicator)

        scrim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrim)

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressBar)

        titleLabel.font = PWInAppStyle.rounded(23, .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.isHidden = true

        subtitleLabel.font = PWInAppStyle.rounded(14, .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.isHidden = true

        buttonsStack.axis = .vertical
        buttonsStack.alignment = .fill
        buttonsStack.spacing = 10
        buttonsStack.isHidden = true

        let bottomStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, buttonsStack])
        bottomStack.axis = .vertical
        bottomStack.alignment = .fill
        bottomStack.spacing = 6
        bottomStack.setCustomSpacing(16, after: subtitleLabel)
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomStack)

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrim.topAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -44),

            progressBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            closeButton.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            bottomStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            bottomStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            bottomStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        closeButton.isHidden = !content.showCloseButton
        progressBar.configure(segmentCount: items.count)
    }

    // MARK: - Gestures

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.25
        longPress.delegate = self
        addGestureRecognizer(longPress)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(closeTapped))
        swipeDown.direction = .down
        swipeDown.delegate = self
        addGestureRecognizer(swipeDown)
    }

    // Don't let tap-zone / long-press navigation fire when the touch lands on a control (CTA / close).
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view is UIControl)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let x = recognizer.location(in: self).x
        if x < bounds.width / 3 {
            goPrevious()
        } else {
            goNext()
        }
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pausePlayback()
        case .ended, .cancelled, .failed:
            resumePlayback()
        default:
            break
        }
    }

    private func makeStoryButton(_ model: PWInAppButton, tag: Int) -> UIButton {
        let button = PWInAppStyle.makeContractButton(model)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.28
        button.layer.shadowRadius = 14
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.tag = tag
        button.addTarget(self, action: #selector(ctaTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(ctaDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(ctaUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }

    @objc private func ctaTapped(_ sender: UIButton) {
        guard items.indices.contains(index),
              items[index].buttons.indices.contains(sender.tag) else {
            return
        }
        stopPlayback()
        onAction?(items[index].buttons[sender.tag].action)
    }

    @objc private func ctaDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            sender.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            sender.alpha = 0.9
        }
    }

    @objc private func ctaUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            sender.transform = .identity
            sender.alpha = 1
        }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: - Playback

    private func start() {
        index = 0
        showPage(at: 0)
    }

    private func goNext() {
        if index + 1 < items.count {
            index += 1
            showPage(at: index)
        } else if content.loops {
            progressBar.reset()
            index = 0
            showPage(at: 0)
        } else {
            onClose?()
        }
    }

    private func goPrevious() {
        guard index > 0 else {
            showPage(at: 0)
            return
        }
        index -= 1
        showPage(at: index)
    }

    private func showPage(at i: Int) {
        guard items.indices.contains(i) else { return }
        let item = items[i]

        titleLabel.text = item.title?.text
        titleLabel.textColor = item.title?.color ?? .white
        titleLabel.isHidden = (item.title?.text.isEmpty ?? true)
        subtitleLabel.text = item.subtitle?.text
        subtitleLabel.textColor = item.subtitle?.color ?? UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.isHidden = (item.subtitle?.text.isEmpty ?? true)

        buttonsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (tag, model) in item.buttons.enumerated() {
            buttonsStack.addArrangedSubview(makeStoryButton(model, tag: tag))
        }
        buttonsStack.isHidden = item.buttons.isEmpty

        imageView.image = nil
        if let url = item.imageURL {
            loadingIndicator.startAnimating()
            PWInAppImageLoader.shared.image(for: url) { [weak self] image in
                guard let self = self, self.index == i else { return }
                self.loadingIndicator.stopAnimating()
                self.imageView.image = image ?? PWInAppImageLoader.placeholderImage
            }
        } else {
            loadingIndicator.stopAnimating()
        }

        currentDuration = item.duration
        segmentStart = CACurrentMediaTime()
        startDisplayLink()
        scheduleAutoAdvance(after: item.duration)
    }

    private func scheduleAutoAdvance(after duration: TimeInterval) {
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.goNext()
        }
    }

    private func startDisplayLink() {
        displayLink?.invalidate()
        // Weak proxy so the run loop's retain of the display link never keeps the
        // view alive (CADisplayLink retains its target strongly).
        let link = CADisplayLink(target: PWStoriesDisplayLinkProxy(self), selector: #selector(PWStoriesDisplayLinkProxy.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc fileprivate func tickProgress() {
        let elapsed = CACurrentMediaTime() - segmentStart
        let fraction = CGFloat(min(elapsed / max(currentDuration, 0.01), 1))
        progressBar.update(activeIndex: index, progress: fraction)
    }

    private func pausePlayback() {
        guard !isPaused, displayLink != nil else { return }
        isPaused = true
        pausedElapsed = CACurrentMediaTime() - segmentStart
        displayLink?.invalidate()
        displayLink = nil
        autoTimer?.invalidate()
    }

    private func resumePlayback() {
        guard isPaused else { return }
        isPaused = false
        let remaining = max(currentDuration - pausedElapsed, 0)
        segmentStart = CACurrentMediaTime() - pausedElapsed
        startDisplayLink()
        scheduleAutoAdvance(after: remaining)
    }

    private func stopPlayback() {
        displayLink?.invalidate()
        displayLink = nil
        autoTimer?.invalidate()
        autoTimer = nil
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

        alpha = 0
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 1
        }, completion: { [weak self] _ in
            // Don't start timers/playback if we were dismissed during the entry animation.
            guard let self = self, self.superview != nil else { return }
            self.start()
        })
    }

    func dismiss(completion: @escaping () -> Void) {
        stopPlayback()
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            if !UIAccessibility.isReduceMotionEnabled {
                self.transform = CGAffineTransform(translationX: 0, y: 40)
            }
        }, completion: { _ in
            self.removeFromSuperview()
            completion()
        })
    }
}

/// Weak target for the stories `CADisplayLink` — the run loop retains the proxy,
/// not the view, so the view can deallocate normally.
final class PWStoriesDisplayLinkProxy: NSObject {
    private weak var owner: PWStoriesInAppView?

    init(_ owner: PWStoriesInAppView) {
        self.owner = owner
    }

    @objc func tick() {
        owner?.tickProgress()
    }
}

/// Bottom-up dark gradient so white captions stay legible over bright images.
final class PWGradientScrimView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor]
        gradient.locations = [0, 1]
        layer.addSublayer(gradient)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
#endif
