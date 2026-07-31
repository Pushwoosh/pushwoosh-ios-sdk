//
//  PWInAppImageLoader.swift
//  PushwooshInApp
//
//  Created by André Kis on 23.06.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//
//  Async image loader for in-app assets. Three tiers: in-memory NSCache → disk
//  (Caches, survives relaunch, not backed up) → network. In-flight requests for
//  the same URL are de-duplicated and fanned out to every waiter, and callers
//  can prefetch ahead of display. A failed download/decode resolves to a neutral
//  grey placeholder so a broken image never leaves a black or collapsed gap
//  (Android parity). Posters/thumbnails only — video streams via AVPlayer.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import CryptoKit

final class PWInAppImageLoader {

    static let shared = PWInAppImageLoader()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let diskDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.pushwoosh.inapp.imageloader", attributes: .concurrent)
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        // Bounds an in-flight entry's lifetime: a dead request fails (and clears
        // `inFlight`) within the timeout instead of pinning its waiters forever.
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()

    private let lock = NSLock()
    private var inFlight: [URL: [(UIImage?) -> Void]] = [:]

    private static let maxRetryAttempts = 2
    private static let spinnerTag = 0x50575350

    private static var requestedURLKey: UInt8 = 0

    /// Shown in place of an image that failed to download or decode.
    static let placeholderImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor(white: 0.88, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    private init() {
        memoryCache.countLimit = 80
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        diskDirectory = (caches ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("PushwooshInApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public

    /// Loads `url` into `imageView`, tolerating cell reuse: a late network result
    /// is dropped if the view has since been asked to show a different URL.
    /// `onImage` fires with the decoded image once it is actually shown (cache or network),
    /// so callers can size their frame to the real aspect ratio. Not called on failure.
    func load(_ url: URL?, into imageView: UIImageView, onImage: ((UIImage) -> Void)? = nil) {
        Self.removeSpinner(from: imageView)
        guard let url = url else {
            // No image for this item (e.g. a carousel slide without one): clear the reuse guard
            // and any stale image so a late result for a PREVIOUS url can't land on this reused view.
            objc_setAssociatedObject(imageView, &Self.requestedURLKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            imageView.image = nil
            return
        }
        objc_setAssociatedObject(imageView, &Self.requestedURLKey, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if let cached = memoryCache.object(forKey: url as NSURL) {
            imageView.image = cached
            onImage?(cached)
            return
        }

        // Just a spinner while the image downloads (and transient failures retry) — no grey
        // box up front. A successful result shows the image; only a final failure falls back
        // to the grey placeholder (so a broken image never leaves a collapsed gap). Clear any
        // reused image first so the spinner sits on a clean frame.
        imageView.image = nil
        let spinner = Self.addSpinner(to: imageView)
        image(for: url) { [weak imageView] image in
            guard let imageView = imageView else { return }
            spinner.stopAnimating()
            spinner.removeFromSuperview()
            guard (objc_getAssociatedObject(imageView, &Self.requestedURLKey) as? URL) == url else { return }
            if let image = image {
                imageView.image = image
                onImage?(image)
            } else {
                imageView.image = Self.placeholderImage
            }
        }
    }

    /// Adds a centered, animating spinner over `imageView` (replacing any earlier one).
    private static func addSpinner(to imageView: UIImageView) -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.tag = spinnerTag
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        imageView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
        ])
        return spinner
    }

    /// Removes a spinner left over from an earlier load on a reused image view.
    private static func removeSpinner(from imageView: UIImageView) {
        for case let spinner as UIActivityIndicatorView in imageView.subviews where spinner.tag == spinnerTag {
            spinner.stopAnimating()
            spinner.removeFromSuperview()
        }
    }

    /// Warms the caches for a set of URLs ahead of display (deduped, no target).
    func prefetch(_ urls: [URL?]) {
        for case let url? in urls where memoryCache.object(forKey: url as NSURL) == nil {
            image(for: url) { _ in }
        }
    }

    #if DEBUG
    /// Seeds the memory cache so view tests can lay out against a known image without a network
    /// round trip. Debug-only: never compiled into a shipped SDK.
    func seedMemoryCache(_ image: UIImage, for url: URL) {
        memoryCache.setObject(image, forKey: url as NSURL)
    }
    #endif

    /// Memory → disk → network (de-duplicated). Completion is always on the main thread.
    func image(for url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        ioQueue.async { [weak self] in
            guard let self = self else { return }

            if let diskImage = self.diskImage(for: url) {
                self.memoryCache.setObject(diskImage, forKey: url as NSURL)
                DispatchQueue.main.async { completion(diskImage) }
                return
            }

            self.lock.lock()
            if self.inFlight[url] != nil {
                self.inFlight[url]?.append(completion)
                self.lock.unlock()
                return
            }
            self.inFlight[url] = [completion]
            self.lock.unlock()

            self.download(url, attempt: 0)
        }
    }

    /// Fetches `url`, retrying only transient network failures with a short backoff
    /// (no connection / dropped connection / timeout mid-download). A server response
    /// or a decode failure (`error == nil`) resolves to the placeholder at once —
    /// retrying those is pointless.
    private func download(_ url: URL, attempt: Int) {
        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            if let data = data, let decoded = UIImage(data: data) {
                self.memoryCache.setObject(decoded, forKey: url as NSURL)
                self.writeToDisk(data, for: url)
                self.deliver(decoded, for: url)
                return
            }
            if error != nil, attempt < Self.maxRetryAttempts {
                let delay: TimeInterval = attempt == 0 ? 1.5 : 3
                self.ioQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.download(url, attempt: attempt + 1)
                }
                return
            }
            self.deliver(nil, for: url)
        }.resume()
    }

    /// Resolves every waiter for `url` on the main thread and clears the in-flight entry.
    private func deliver(_ image: UIImage?, for url: URL) {
        lock.lock()
        let waiters = inFlight[url] ?? []
        inFlight[url] = nil
        lock.unlock()
        DispatchQueue.main.async {
            waiters.forEach { $0(image) }
        }
    }

    // MARK: - Disk

    private func diskURL(for url: URL) -> URL {
        diskDirectory.appendingPathComponent(diskKey(for: url))
    }

    private func diskImage(for url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: diskURL(for: url)) else { return nil }
        return UIImage(data: data)
    }

    private func writeToDisk(_ data: Data, for url: URL) {
        ioQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            // .atomic (temp file + rename) is load-bearing: concurrent reads on
            // ioQueue always see a complete file, never a partial write.
            try? data.write(to: self.diskURL(for: url), options: .atomic)
        }
    }

    /// Stable per-URL filename (SHA-256 hex) so the disk cache survives relaunch —
    /// `Hasher`/`hashValue` is randomized per process and would not.
    private func diskKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
