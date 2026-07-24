//
//  PWInAppVideoPlayerView.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Reusable AVPlayer engine shared by the `video` (full-screen) and `pip`
//  (floating) in-apps. Poster shown until the item is ready, looping, image
//  fallback on failure, pause/resume across background, and a strict teardown
//  (KVO + notification observers removed, layer detached, audio session
//  restored). Mirrors the mechanics of CleverTap's CTPiPMediaView.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import AVFoundation

final class PWInAppVideoPlayerView: UIView {

    /// Fires once the video is confirmed playable (or a fallback image is shown).
    var onReady: (() -> Void)?
    /// Fires when the video failed and there is no fallback — caller should dismiss.
    var onFailed: (() -> Void)?

    private let player = AVPlayer()
    private var playerLayer: AVPlayerLayer?
    private let posterImageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)

    private var statusObservation: NSKeyValueObservation?
    private var loopObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    private var loops = true
    private var fallbackImageURL: URL?
    private var wasPlayingBeforeBackground = false

    /// Whether THIS instance has activated the shared audio session (so teardown
    /// decrements the shared user count exactly once).
    private var didActivateSession = false

    /// Reference count + saved category across all live video players. The host's
    /// category is captured on the first activation and restored only when the
    /// last player tears down — so a coexisting PiP isn't silenced when a video
    /// modal closes.
    private static var sessionUsers = 0
    private static var savedCategory: AVAudioSession.Category?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        teardown()
    }

    private func setup() {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        self.layer.addSublayer(layer)
        playerLayer = layer

        posterImageView.contentMode = .scaleAspectFit
        posterImageView.clipsToBounds = true
        posterImageView.backgroundColor = .black
        posterImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(posterImageView)

        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        NSLayoutConstraint.activate([
            posterImageView.topAnchor.constraint(equalTo: topAnchor),
            posterImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            posterImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            posterImageView.trailingAnchor.constraint(equalTo: trailingAnchor),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func configure(videoURL: URL, posterURL: URL?, fallbackImageURL: URL?, loop: Bool, muted: Bool) {
        // Safe to call more than once: drop any prior observers first.
        removeObservers()

        loops = loop
        self.fallbackImageURL = fallbackImageURL

        if let posterURL = posterURL {
            PWInAppImageLoader.shared.load(posterURL, into: posterImageView)
        }

        configureAudioSession(muted: muted)
        player.isMuted = muted

        let item = AVPlayerItem(url: videoURL)
        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] observed, _ in
            DispatchQueue.main.async {
                self?.handleStatus(of: observed)
            }
        }
        addItemObservers(for: item)
        addLifecycleObservers()

        spinner.startAnimating()
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func handleStatus(of item: AVPlayerItem) {
        // Ignore a stale item — the player was torn down or replaced between the
        // KVO fire and this main-queue hop.
        guard item === player.currentItem else {
            return
        }
        switch item.status {
        case .readyToPlay:
            spinner.stopAnimating()
            posterImageView.isHidden = true
            player.play()
            onReady?()
        case .failed:
            spinner.stopAnimating()
            if let fallbackImageURL = fallbackImageURL {
                posterImageView.isHidden = false
                posterImageView.contentMode = .scaleAspectFill
                PWInAppImageLoader.shared.load(fallbackImageURL, into: posterImageView)
                onReady?()
            } else {
                onFailed?()
            }
        default:
            break
        }
    }

    private func addItemObservers(for item: AVPlayerItem) {
        if loops {
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.spinner.startAnimating()
        }
    }

    private func addLifecycleObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.wasPlayingBeforeBackground = (self.player.timeControlStatus != .paused)
            self.player.pause()
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.wasPlayingBeforeBackground else { return }
            self.player.play()
        }
    }

    private func configureAudioSession(muted: Bool) {
        let session = AVAudioSession.sharedInstance()
        if !didActivateSession {
            if Self.sessionUsers == 0 {
                Self.savedCategory = session.category
            }
            Self.sessionUsers += 1
            didActivateSession = true
        }
        try? session.setCategory(muted ? .ambient : .playback)
        try? session.setActive(true)
    }

    // MARK: - Controls

    var isMuted: Bool {
        player.isMuted
    }

    func setMuted(_ muted: Bool) {
        player.isMuted = muted
        if !muted {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback)
            try? session.setActive(true)
        }
    }

    var isPlaying: Bool {
        player.timeControlStatus != .paused
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    private func removeObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        [loopObserver, failObserver, backgroundObserver, foregroundObserver].forEach { observer in
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        loopObserver = nil
        failObserver = nil
        backgroundObserver = nil
        foregroundObserver = nil
    }

    func teardown() {
        removeObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil

        if didActivateSession {
            didActivateSession = false
            Self.sessionUsers = max(0, Self.sessionUsers - 1)
            if Self.sessionUsers == 0 {
                let session = AVAudioSession.sharedInstance()
                if let saved = Self.savedCategory {
                    try? session.setCategory(saved)
                    Self.savedCategory = nil
                }
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
}
#endif
