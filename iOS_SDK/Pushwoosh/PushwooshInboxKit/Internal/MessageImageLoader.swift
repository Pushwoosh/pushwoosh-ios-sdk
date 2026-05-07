//
//  MessageImageLoader.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Lightweight in-memory image fetcher backed by `URLSession` + `NSCache`.
final class MessageImageLoader {

    static let shared = MessageImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private static var taskKey: UInt8 = 0

    init(session: URLSession = .shared) {
        self.session = session
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
            guard error == nil, let data = data, let image = UIImage(data: data) else { return }
            self?.cache.setObject(image, forKey: urlString as NSString)
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

    func cancelLoad(for imageView: UIImageView) {
        if let task = objc_getAssociatedObject(imageView, &MessageImageLoader.taskKey) as? URLSessionDataTask {
            task.cancel()
        }
        objc_setAssociatedObject(imageView, &MessageImageLoader.taskKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
#endif
