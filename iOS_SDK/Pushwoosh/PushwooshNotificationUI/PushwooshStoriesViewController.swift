//
//  PushwooshStoriesViewController.swift
//  PushwooshNotificationUI
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

/// A drop-in `UNNotificationContentExtension` view controller that renders a full-screen,
/// Instagram-style "stories" experience for an expanded push notification: full-bleed images,
/// top progress bars, an auto-advance timer, tap-zone navigation, and an optional deep-link button.
///
/// Subclass it one line inside your Notification Content Extension:
///
/// ```swift
/// import PushwooshNotificationUI
///
/// class NotificationViewController: PushwooshStoriesViewController {}
/// ```
///
/// The stories are described by a `pw_stories` block in the notification payload. A missing,
/// empty, or malformed payload falls back to the default content (the alert body) without crashing.
/// Override ``showDefaultContent(for:)`` to customise that fallback.
///
/// The module links only UIKit, UserNotifications, and UserNotificationsUI — it adds no Pushwoosh
/// Core/Framework weight to the memory-constrained extension process.
open class PushwooshStoriesViewController: UIViewController, UNNotificationContentExtension {

    private let imageView = UIImageView()
    private let progressBar = StoryProgressBarView()
    private let actionButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let scrimView = GradientScrimView()
    private lazy var imageLoader = StoryImageLoader(appGroupIdentifier: appGroupIdentifier)

    private var player: StoriesPlayer?
    private var pages: [StoryPage] = []
    private var displayLink: CADisplayLink?
    private var segmentStart: CFTimeInterval = 0
    private var currentDuration: TimeInterval = StoryPage.defaultDuration
    private var currentActiveIndex: Int = 0
    private weak var defaultContentLabel: UILabel?
    private lazy var hapticGenerator = UIImpactFeedbackGenerator(style: .soft)
    private var isPaused = false
    private var pausedElapsed: CFTimeInterval = 0

    /// Optional observer for story lifecycle / analytics events. Every method is optional —
    /// implement only the callbacks you need (impressions, clicks, completion, fallback).
    public weak var storiesDelegate: PushwooshStoriesDelegate?

    /// App Group identifier shared with your Notification Service Extension. When set (and the
    /// capability is enabled on both targets), the first frame is read from the shared container
    /// that the Service Extension pre-warmed — instant and offline. Defaults to `nil` (uses `tmp`).
    open var appGroupIdentifier: String? { nil }

    /// Aspect ratio (height ÷ width) of the stories area. Keep this in sync with the extension's
    /// `UNNotificationExtensionInitialContentSizeRatio` so the notification doesn't resize after the
    /// image loads. Override in a subclass to change the story proportions.
    open var storyAspectRatio: CGFloat { 1.5 }

    /// Whether a light tactile tap accompanies tap-zone navigation between pages. Override to `true`
    /// to enable. Defaults to `false`.
    open var hapticsEnabled: Bool { false }

    /// Whether press-and-hold pauses the current page (timer + progress freeze) and lifting resumes —
    /// the signature "stories" gesture. Override to `true` to enable. Defaults to `false`.
    open var longPressToPauseEnabled: Bool { false }

    /// Whether pages cross-dissolve into each other instead of cutting hard. Automatically falls back
    /// to an instant change when Reduce Motion is on. Override to `true` to enable. Defaults to `false`.
    open var crossfadesBetweenPages: Bool { false }

    /// Whether playback restarts from the first page after the last one finishes, instead of stopping.
    /// Override to `true` for an endlessly looping reel. Defaults to `false`.
    open var loopsAfterLastPage: Bool { false }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupViews()
        setupGestures()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.stop()
        stopDisplayLink()
    }

    // MARK: UNNotificationContentExtension

    open func didReceive(_ notification: UNNotification) {
        player?.stop()
        stopDisplayLink()

        pages = StoryPayloadParser.parse(userInfo: notification.request.content.userInfo)

        guard !pages.isEmpty else {
            showDefaultContent(for: notification)
            storiesDelegate?.storiesViewControllerDidShowFallback(self)
            return
        }

        progressBar.isHidden = false
        progressBar.configure(segmentCount: pages.count)

        let player = StoriesPlayer(pages: pages)
        player.onIndexChange = { [weak self] index in self?.showPage(at: index) }
        player.onComplete = { [weak self] in
            guard let self else { return }
            self.progressBar.update(activeIndex: self.currentActiveIndex, progress: 1)
            self.stopDisplayLink()
            self.storiesDelegate?.storiesViewControllerDidFinish(self)
            if self.loopsAfterLastPage {
                self.restartLoop()
            }
        }
        self.player = player
        if hapticsEnabled { hapticGenerator.prepare() }
        storiesDelegate?.storiesViewController(self, didStartWithPageCount: pages.count)
        player.start()

        imageLoader.prefetch(pages.dropFirst().map { $0.imageURL })
    }

    // MARK: Default fallback

    /// Subclasses may override to customise the no-stories fallback. Default: show the alert body.
    open func showDefaultContent(for notification: UNNotification) {
        progressBar.isHidden = true
        actionButton.isHidden = true
        titleLabel.isHidden = true
        subtitleLabel.isHidden = true
        loadingIndicator.stopAnimating()
        imageView.image = nil
        defaultContentLabel?.removeFromSuperview()

        let label = UILabel()
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = notification.request.content.body
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        defaultContentLabel = label
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    // MARK: Rendering

    private func showPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let page = pages[index]

        storiesDelegate?.storiesViewController(self, didShow: page, at: index)

        titleLabel.text = page.title
        titleLabel.isHidden = (page.title?.isEmpty ?? true)
        subtitleLabel.text = page.subtitle
        subtitleLabel.isHidden = (page.subtitle?.isEmpty ?? true)

        if let cached = imageLoader.cachedImage(for: page.imageURL) {
            loadingIndicator.stopAnimating()
            setImage(cached, animated: crossfadesBetweenPages)
        } else {
            if !crossfadesBetweenPages {
                imageView.image = nil
            }
            loadingIndicator.startAnimating()
            imageLoader.loadImage(at: page.imageURL) { [weak self] image in
                guard let self, self.player?.currentIndex == index else { return }
                self.loadingIndicator.stopAnimating()
                self.setImage(image, animated: self.crossfadesBetweenPages)
            }
        }

        updateActionButton(title: page.link != nil ? page.buttonTitle : nil)

        startDisplayLink(for: page.duration, activeIndex: index)
    }

    private func setImage(_ image: UIImage?, animated: Bool) {
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            imageView.image = image
            return
        }
        UIView.transition(with: imageView,
                          duration: 0.3,
                          options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.imageView.image = image
        }
    }

    private func updateActionButton(title: String?) {
        guard let title, !title.isEmpty else {
            actionButton.isHidden = true
            return
        }
        actionButton.isHidden = false
        UIView.transition(with: actionButton,
                          duration: 0.4,
                          options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.actionButton.setTitle(title, for: .normal)
            self.view.layoutIfNeeded()
        }
    }

    // MARK: Progress animation

    private func startDisplayLink(for duration: TimeInterval, activeIndex: Int) {
        isPaused = false
        segmentStart = CACurrentMediaTime()
        currentDuration = duration
        currentActiveIndex = activeIndex
        startDisplayLinkTicking()
    }

    private func startDisplayLinkTicking() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(tickProgress))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tickProgress() {
        let elapsed = CACurrentMediaTime() - segmentStart
        let fraction = CGFloat(min(elapsed / max(currentDuration, 0.01), 1))
        progressBar.update(activeIndex: currentActiveIndex, progress: fraction)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: Gestures (no horizontal swipe — conflicts with system dismiss)

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.25
        view.addGestureRecognizer(longPress)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let player else { return }
        let x = recognizer.location(in: view).x
        if x < view.bounds.width / 3 {
            playHaptic()
            player.goPrevious()
        } else if player.currentIndex + 1 < pages.count {
            playHaptic()
            player.goNext()
        } else if loopsAfterLastPage {
            playHaptic()
            restartLoop()
        }
    }

    private func restartLoop() {
        progressBar.reset()
        player?.start()
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard longPressToPauseEnabled else { return }
        switch recognizer.state {
        case .began:
            pausePlayback()
        case .ended, .cancelled, .failed:
            resumePlayback()
        default:
            break
        }
    }

    private func pausePlayback() {
        guard !isPaused, displayLink != nil else { return }
        isPaused = true
        pausedElapsed = CACurrentMediaTime() - segmentStart
        stopDisplayLink()
        player?.pause()
    }

    private func resumePlayback() {
        guard isPaused else { return }
        isPaused = false
        let remaining = max(currentDuration - pausedElapsed, 0)
        segmentStart = CACurrentMediaTime() - pausedElapsed
        startDisplayLinkTicking()
        player?.resume(after: remaining)
    }

    private func playHaptic() {
        guard hapticsEnabled else { return }
        hapticGenerator.impactOccurred()
        hapticGenerator.prepare()
    }

    @objc private func handleButton() {
        guard let player,
              pages.indices.contains(player.currentIndex),
              let link = pages[player.currentIndex].link else {
            return
        }
        let index = player.currentIndex
        storiesDelegate?.storiesViewController(self, didTapActionFor: pages[index], at: index)
        player.stop()
        stopDisplayLink()
        extensionContext?.open(link) { [weak self] success in
            guard !success else { return }
            DispatchQueue.main.async {
                self?.extensionContext?.dismissNotificationContentExtension()
            }
        }
    }

    private static func buttonFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: 17, weight: .semibold)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: 17)
    }

    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.12, delay: 0,
                       options: [.allowUserInteraction, .curveEaseOut]) {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.actionButton.alpha = 0.9
        }
    }

    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction]) {
            self.actionButton.transform = .identity
            self.actionButton.alpha = 1
        }
    }

    // MARK: Layout

    private func setupViews() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.addSubview(imageView)

        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)

        scrimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrimView)

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)

        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.isHidden = true

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.isHidden = true

        actionButton.setTitleColor(UIColor(white: 0.06, alpha: 1), for: .normal)
        actionButton.backgroundColor = .white
        actionButton.titleLabel?.font = Self.buttonFont()
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
        actionButton.layer.cornerRadius = 26
        actionButton.layer.cornerCurve = .continuous
        actionButton.layer.shadowColor = UIColor.black.cgColor
        actionButton.layer.shadowOpacity = 0.28
        actionButton.layer.shadowRadius = 14
        actionButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        actionButton.addTarget(self, action: #selector(handleButton), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        actionButton.addTarget(self, action: #selector(buttonTouchUp),
                               for: [.touchUpInside, .touchUpOutside, .touchCancel])
        actionButton.isHidden = true

        let bottomStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, actionButton])
        bottomStack.axis = .vertical
        bottomStack.alignment = .fill
        bottomStack.spacing = 6
        bottomStack.setCustomSpacing(16, after: subtitleLabel)
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: storyAspectRatio),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            scrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrimView.topAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -44),

            progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 23),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            actionButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }
}

// MARK: - Delegate

/// Optional analytics / lifecycle hooks for ``PushwooshStoriesViewController``.
///
/// Every method has a default empty implementation, so a conformer overrides only the callbacks
/// it cares about. Set ``PushwooshStoriesViewController/storiesDelegate`` from your subclass.
public protocol PushwooshStoriesDelegate: AnyObject {
    /// Called once a valid stories payload was parsed and playback is about to begin.
    func storiesViewController(_ controller: PushwooshStoriesViewController, didStartWithPageCount pageCount: Int)
    /// Called every time a page becomes visible — use it for per-page impressions.
    func storiesViewController(_ controller: PushwooshStoriesViewController, didShow page: StoryPage, at index: Int)
    /// Called when the user taps the call-to-action button — forward it to your analytics / backend.
    func storiesViewController(_ controller: PushwooshStoriesViewController, didTapActionFor page: StoryPage, at index: Int)
    /// Called when the last page finished playing.
    func storiesViewControllerDidFinish(_ controller: PushwooshStoriesViewController)
    /// Called when the payload was missing/malformed and the default fallback content was shown.
    func storiesViewControllerDidShowFallback(_ controller: PushwooshStoriesViewController)
}

public extension PushwooshStoriesDelegate {
    func storiesViewController(_ controller: PushwooshStoriesViewController, didStartWithPageCount pageCount: Int) {}
    func storiesViewController(_ controller: PushwooshStoriesViewController, didShow page: StoryPage, at index: Int) {}
    func storiesViewController(_ controller: PushwooshStoriesViewController, didTapActionFor page: StoryPage, at index: Int) {}
    func storiesViewControllerDidFinish(_ controller: PushwooshStoriesViewController) {}
    func storiesViewControllerDidShowFallback(_ controller: PushwooshStoriesViewController) {}
}

private final class GradientScrimView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor]
        gradient.locations = [0, 1]
        layer.addSublayer(gradient)
        isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}
