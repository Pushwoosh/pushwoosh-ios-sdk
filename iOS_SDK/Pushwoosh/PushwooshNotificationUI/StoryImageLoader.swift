//
//  StoryImageLoader.swift
//  PushwooshNotificationUI
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

import UIKit
import ImageIO
import CryptoKit

final class StoryImageLoader {

    private let session: URLSession
    private let cacheDirectory: URL
    private var inFlight: Set<URL> = []
    private let memoryCache = NSCache<NSURL, UIImage>()

    init(session: URLSession = .shared, appGroupIdentifier: String? = nil) {
        self.session = session
        self.cacheDirectory = StoryImageLoader.cacheDirectory(appGroupIdentifier: appGroupIdentifier)
        try? FileManager.default.createDirectory(at: cacheDirectory,
                                                 withIntermediateDirectories: true)
        memoryCache.countLimit = 12
        memoryCache.totalCostLimit = 32 * 1024 * 1024
    }

    /// Largest pixel dimension we ever keep in memory. Story media is shown full-bleed, so a
    /// downsampled frame at this size stays crisp on any phone while capping a single decoded
    /// image at a few MB — critical in the memory-constrained extension, where decoding a
    /// multi-thousand-pixel original at full size can blow the process budget (jetsam).
    private static let maxPixelSize: CGFloat = 1500

    /// Shared App Group container when an identifier is given (so a Service Extension can pre-warm
    /// the cache for the Content Extension); otherwise the process-local `tmp` directory.
    private static func cacheDirectory(appGroupIdentifier: String?) -> URL {
        let base: URL
        if let id = appGroupIdentifier,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            base = container
        } else {
            base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        return base.appendingPathComponent("pw_stories_cache", isDirectory: true)
    }

    /// Warms upcoming pages so the first transition to them is instant: decodes each image into the
    /// in-memory cache, downloading + writing the file cache first only when it isn't on disk yet
    /// (e.g. when a Service Extension already pre-warmed the shared container). Skips URLs already in
    /// memory or in flight. No UI work — safe to call off the render path.
    func prefetch(_ urls: [URL]) {
        for url in urls {
            guard memoryCache.object(forKey: url as NSURL) == nil,
                  !inFlight.contains(url) else {
                continue
            }
            let fileURL = cacheFileURL(for: url)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    guard let self,
                          let data = try? Data(contentsOf: fileURL),
                          let image = StoryImageLoader.decode(data) else { return }
                    self.store(image, for: url)
                }
                continue
            }
            inFlight.insert(url)
            let task = session.dataTask(with: url) { [weak self] data, _, _ in
                guard let self else { return }
                if let data, let image = StoryImageLoader.decode(data) {
                    try? data.write(to: self.cacheFileURL(for: url), options: .atomic)
                    self.store(image, for: url)
                }
                DispatchQueue.main.async { self.inFlight.remove(url) }
            }
            task.resume()
        }
    }

    /// Synchronously returns an already-decoded image from the in-memory cache, or `nil`. Lets a
    /// caller re-show a previously displayed page instantly — no loading indicator, no disk re-decode.
    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// Loads the image off the main thread (cache read + network) and always delivers `completion`
    /// on the main thread, so callers never block the UI — important in the memory-constrained
    /// extension where the first frame is read from the pre-warmed cache. Decoded images are kept
    /// in a small in-memory cache so re-showing a page is instant.
    func loadImage(at url: URL, completion: @escaping (UIImage?) -> Void) {
        let cached = cacheFileURL(for: url)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let data = try? Data(contentsOf: cached), let image = StoryImageLoader.decode(data) {
                self?.store(image, for: url)
                DispatchQueue.main.async { completion(image) }
                return
            }
            guard let self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let task = self.session.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data, let image = StoryImageLoader.decode(data) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                try? data.write(to: self.cacheFileURL(for: url), options: .atomic)
                self.store(image, for: url)
                DispatchQueue.main.async { completion(image) }
            }
            task.resume()
        }
    }

    /// Downloads every URL into the (possibly shared) cache and calls `completion` once all
    /// finish. Intended for a Notification Service Extension to pre-warm media before display.
    func prefetchAll(_ urls: [URL], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        for url in urls {
            guard !FileManager.default.fileExists(atPath: cacheFileURL(for: url).path) else { continue }
            group.enter()
            let task = session.dataTask(with: url) { [weak self] data, _, _ in
                defer { group.leave() }
                guard let self, let data, StoryImageLoader.isValidImage(data) else { return }
                try? data.write(to: self.cacheFileURL(for: url), options: .atomic)
            }
            task.resume()
        }
        group.notify(queue: .main, execute: completion)
    }

    /// Decodes `data` into a downsampled image (longest side ≤ `maxPixelSize`) via ImageIO, so a
    /// huge original never lands in memory at full resolution. The file cache always keeps the
    /// original bytes; only the in-memory copy is downsampled.
    private static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData,
                                                       [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Cheap format check that does not decode pixels — used by the Service Extension prefetch, which
    /// only needs to confirm the bytes are a real image before writing them to the shared cache.
    private static func isValidImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetType(source) != nil
    }

    /// Stores a decoded image with an approximate byte cost so `totalCostLimit` can evict correctly.
    private func store(_ image: UIImage, for url: URL) {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        memoryCache.setObject(image, forKey: url as NSURL, cost: Int(pixels) * 4)
    }

    /// Stable, cross-process cache key (SHA-256 of the URL). `String.hashValue` is seeded per
    /// process, so it cannot be shared between the Service and Content extensions.
    private func cacheFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(name)
    }
}

/// Entry point for a Notification **Service** Extension: pre-downloads the story media referenced
/// by a `pw_stories` payload into the shared App Group container, so the Content Extension can
/// render the first frame instantly and offline. Call from `didReceive(_:withContentHandler:)`.
public enum PushwooshStoriesMediaPrefetcher {
    public static func prefetch(userInfo: [AnyHashable: Any],
                                appGroupIdentifier: String,
                                completion: @escaping () -> Void) {
        let pages = StoryPayloadParser.parse(userInfo: userInfo)
        guard !pages.isEmpty else {
            completion()
            return
        }
        let loader = StoryImageLoader(appGroupIdentifier: appGroupIdentifier)
        loader.prefetchAll(pages.map { $0.imageURL }) { [loader] in
            _ = loader // keep the loader alive until all downloads finish
            completion()
        }
    }
}
