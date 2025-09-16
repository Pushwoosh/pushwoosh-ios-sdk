//
//  ImageLoader.swift
//  PushwooshForegroundPush
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
class ImageLoader {
    
    typealias ImageLoadCompletion = (UIImage?) -> Void
    
    static func loadImage(from urlString: String?, completion: @escaping ImageLoadCompletion) {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = loadImageSynchronously(from: url)
            DispatchQueue.main.async {
                completion(loadedImage)
            }
        }
    }
    
    private static func loadImageSynchronously(from url: URL) -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            
            if url.pathExtension.lowercased() == "gif" {
                return loadGifImage(from: data)
            } else {
                return UIImage(data: data)
            }
        } catch {
            print("Failed to load image from URL: \(url.absoluteString), error: \(error)")
            return nil
        }
    }
    
    private static func loadGifImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        
        var images: [UIImage] = []
        var totalDuration: Double = 0
        
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            images.append(UIImage(cgImage: cgImage))
            
            let frameDuration = getFrameDuration(from: source, at: i)
            totalDuration += frameDuration
        }
        
        guard !images.isEmpty else { return nil }
        
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
    
    private static func getFrameDuration(from source: CGImageSource, at index: Int) -> Double {
        let defaultDelay: Double = 0.1
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifInfo = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return defaultDelay
        }
        
        let delayTime = gifInfo[kCGImagePropertyGIFDelayTime as String] as? Double ?? defaultDelay
        
        // Ensure minimum delay to prevent overly fast animations
        return max(delayTime, 0.02)
    }
}
