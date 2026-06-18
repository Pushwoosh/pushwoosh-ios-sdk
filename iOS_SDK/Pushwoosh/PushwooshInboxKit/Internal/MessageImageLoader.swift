//
//  MessageImageLoader.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import CoreImage
import ImageIO

/// Image fetcher with a decoded-image memory cache (`NSCache`) on top of a `URLSession` that keeps
/// its own on-disk HTTP cache. Images are downsampled at decode time (ImageIO) so large remote
/// images don't blow up memory while scrolling, and `prefetch(_:)` warms the cache ahead of display.
final class MessageImageLoader {

    static let shared = MessageImageLoader()

    /// Largest pixel dimension a card image is decoded to. Inbox cards are at most ~full screen
    /// width on a 3x device, so 1200px keeps quality while capping memory.
    private static let maxPixelSize: CGFloat = 1200

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private static var taskKey: UInt8 = 0

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024,
                                       diskCapacity: 128 * 1024 * 1024,
                                       diskPath: "pw.inboxkit.images")
            config.requestCachePolicy = .returnCacheDataElseLoad
            self.session = URLSession(configuration: config)
        }
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func load(_ urlString: String, into imageView: UIImageView, placeholder: UIImage?) {
        cancelLoad(for: imageView)
        imageView.image = placeholder

        if let cached = cache.object(forKey: urlString as NSString) {
            imageView.image = cached
            return
        }
        guard let url = URL(string: urlString) else { return }

        var taskRef: URLSessionDataTask?
        let task = session.dataTask(with: url) { [weak self, weak imageView] data, _, error in
            guard error == nil, let data = data,
                  let image = self?.decode(data, maxPixel: MessageImageLoader.maxPixelSize) else { return }
            self?.store(image, for: urlString)
            DispatchQueue.main.async {
                guard let imageView = imageView else { return }
                // Apply only if this imageView is still bound to the same task —
                // otherwise it has been reused by another row whose own load is
                // either pending or already completed.
                let stored = objc_getAssociatedObject(imageView, &MessageImageLoader.taskKey) as? URLSessionDataTask
                if stored === taskRef {
                    imageView.image = image
                }
            }
        }
        taskRef = task
        objc_setAssociatedObject(imageView, &MessageImageLoader.taskKey, task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        task.resume()
    }

    /// Warms the cache for an image without binding it to a view — used by table prefetching.
    func prefetch(_ urlString: String) {
        guard cache.object(forKey: urlString as NSString) == nil,
              let url = URL(string: urlString) else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let image = self?.decode(data, maxPixel: MessageImageLoader.maxPixelSize) else { return }
            self?.store(image, for: urlString)
        }.resume()
    }

    /// Fetches the image (cache-first) and calls `completion` on the main thread with it (or nil).
    /// Decoded small — used only to derive an accent colour, where full resolution is wasted.
    func loadImage(_ urlString: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: urlString as NSString) {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        session.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap { self?.decode($0, maxPixel: 400) }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    func cancelLoad(for imageView: UIImageView) {
        if let task = objc_getAssociatedObject(imageView, &MessageImageLoader.taskKey) as? URLSessionDataTask {
            task.cancel()
        }
        objc_setAssociatedObject(imageView, &MessageImageLoader.taskKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func store(_ image: UIImage, for urlString: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: urlString as NSString, cost: cost)
    }

    /// Downsamples `data` to at most `maxPixel` on the longest side via ImageIO — decodes straight to
    /// the target size instead of loading the full-resolution bitmap into memory.
    private func decode(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        // Drop the image rather than fall back to UIImage(data:), which would decode at native
        // resolution and bypass the maxPixel cap — a crafted image could then balloon memory.
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

extension UIImage {
    // Reused — initialising a CIContext per call is expensive. Callers must serialize access
    // (the carousel routes pw_averageColor through a dedicated serial queue).
    private static let pw_averageColorContext = CIContext(options: [.workingColorSpace: NSNull()])

    /// Average colour of the image (via Core Image `CIAreaAverage`), used to tint UI to its imagery.
    var pw_averageColor: UIColor? {
        guard let cgImage = cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let extent = CIVector(x: input.extent.origin.x, y: input.extent.origin.y,
                              z: input.extent.size.width, w: input.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input, kCIInputExtentKey: extent]),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        UIImage.pw_averageColorContext.render(output, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255, alpha: 1)
    }
}
#endif
