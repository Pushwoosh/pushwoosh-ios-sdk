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

    private var managesAudioSession = true
    private let audioSession: PWInAppAudioSession

    override convenience init(frame: CGRect) {
        self.init(frame: frame, audioSession: .shared)
    }

    init(frame: CGRect = .zero, audioSession: PWInAppAudioSession) {
        self.audioSession = audioSession
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

    /// `managesAudioSession: false` is for a video that never plays sound: it keeps the app's audio session,
    /// only moving an app on the default `.soloAmbient` to `.ambient` so other apps' audio keeps playing.
    func configure(videoURL: URL, posterURL: URL?, fallbackImageURL: URL?, loop: Bool, muted: Bool, fill: Bool = false,
                   managesAudioSession: Bool = true) {
        // Safe to call more than once: drop any prior observers first.
        removeObservers()

        playerLayer?.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        posterImageView.contentMode = fill ? .scaleAspectFill : .scaleAspectFit

        loops = loop
        self.fallbackImageURL = fallbackImageURL

        if let posterURL = posterURL {
            PWInAppImageLoader.shared.load(posterURL, into: posterImageView)
        }

        self.managesAudioSession = managesAudioSession
        if managesAudioSession {
            audioSession.take(muted ? .ambient : .playback, activate: true, for: self)
        } else {
            audioSession.mixWithOthers(for: self)
        }
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

    // MARK: - Controls

    var isMuted: Bool {
        player.isMuted
    }

    func setMuted(_ muted: Bool) {
        player.isMuted = muted
        if !muted, managesAudioSession {
            audioSession.take(.playback, activate: true, for: self)
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

        audioSession.leave(self)
    }
}

protocol PWAudioSessionControl: AnyObject {
    var category: AVAudioSession.Category { get }
    var mode: AVAudioSession.Mode { get }
    var categoryOptions: AVAudioSession.CategoryOptions { get }
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: PWAudioSessionControl {}

/// The app's audio session shared by every live video player. A player takes the category it needs, sound
/// winning over silence; the app's own category, mode and options come back once the last player that
/// changed the category is gone, unless the app changed it meanwhile. The session is deactivated, letting
/// other apps' audio resume, once the last player that activated it is gone, whatever players stay; a
/// session no player activated is left to the app.
final class PWInAppAudioSession {

    static let shared = PWInAppAudioSession(session: AVAudioSession.sharedInstance())

    private let session: PWAudioSessionControl
    private var requests: [ObjectIdentifier: AVAudioSession.Category] = [:]
    private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                        options: AVAudioSession.CategoryOptions)?
    private var applied: AVAudioSession.Category?
    private var activators = Set<ObjectIdentifier>()

    init(session: PWAudioSessionControl) {
        self.session = session
    }

    /// `.playback` for a video with sound, `.ambient` for a muted one; `activate` activates the session now.
    func take(_ category: AVAudioSession.Category, activate: Bool, for player: AnyObject) {
        let id = ObjectIdentifier(player)
        if saved == nil {
            saved = (session.category, session.mode, session.categoryOptions)
        }
        requests[id] = category
        apply()
        if activate {
            try? session.setActive(true, options: [])
            activators.insert(id)
        }
    }

    /// A video that never plays sound: the default `.soloAmbient` would stop other apps' audio, so an app on it
    /// moves to `.ambient` while the video lives; any other category of the app stays.
    func mixWithOthers(for player: AnyObject) {
        if (saved?.category ?? session.category) == .soloAmbient {
            take(.ambient, activate: false, for: player)
        }
    }

    func leave(_ player: AnyObject) {
        let id = ObjectIdentifier(player)
        let changedCategory = requests.removeValue(forKey: id) != nil
        if activators.remove(id) != nil, activators.isEmpty {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        if changedCategory, session.category == applied {
            if requests.isEmpty, let saved = saved {
                try? session.setCategory(saved.category, mode: saved.mode, options: saved.options)
            } else {
                apply()
            }
        }
        if requests.isEmpty {
            saved = nil
            applied = nil
        }
    }

    private func apply() {
        let category: AVAudioSession.Category = requests.values.contains(.playback) ? .playback : .ambient
        guard category != applied || session.category != category else {
            return
        }
        try? session.setCategory(category, mode: .default, options: [])
        applied = category
    }
}
#endif
