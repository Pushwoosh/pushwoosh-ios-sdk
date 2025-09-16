//
//  PushwooshForegroundPushImplementation.swift
//  PushwooshForegroundPush
//
//  Created by André Kis on 20.08.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import PushwooshCore
import PushwooshBridge

@objc
public class ForegroundPushConfiguration: NSObject {
    let style: PWForegroundPushStyle
    let duration: Int
    let vibration: PWForegroundPushHapticFeedback
    let disappearedAnimation: PWForegroundPushDisappearedAnimation
    var gradientColors: [UIColor]?
    var backgroundColor: UIColor?
    var usePushAnimation: Bool
    var titlePushColor: UIColor?
    var messagePushColor: UIColor?
    var titlePushFont: UIFont?
    var messagePushFont: UIFont?
    var useLiquidView: Bool
    
    @objc
    public init(
        style: PWForegroundPushStyle,
        duration: Int,
        vibration: PWForegroundPushHapticFeedback,
        disappearedAnimation: PWForegroundPushDisappearedAnimation,
        gradientColors: [UIColor]? = nil,
        backgroundColor: UIColor? = nil,
        usePushAnimation: Bool = true,
        titlePushColor: UIColor? = nil,
        messagePushColor: UIColor? = nil,
        titlePushFont: UIFont? = nil,
        messagePushFont: UIFont? = nil,
        useLiquidView: Bool = false
    ) {
        self.style = style
        self.duration = duration
        self.vibration = vibration
        self.disappearedAnimation = disappearedAnimation
        self.gradientColors = gradientColors
        self.backgroundColor = backgroundColor
        self.usePushAnimation = usePushAnimation
        self.titlePushColor = titlePushColor
        self.messagePushColor = messagePushColor
        self.titlePushFont = titlePushFont
        self.messagePushFont = messagePushFont
        self.useLiquidView = useLiquidView
    }
}

@available(iOS 13.0, *)
@objc(PushwooshForegroundPushImplementation)
public class PushwooshForegroundPushImplementation: NSObject {
    @objc(shared)
    public static let shared = PushwooshForegroundPushImplementation()
    
    private override init() {}
    
    private static var configuration: ForegroundPushConfiguration!
    private static var disappearedPushAnimation: PWForegroundPushDisappearedAnimation!
    
    @objc
    static func showForegroundPush(userInfo: [AnyHashable: Any]) {
        guard let config = PushwooshForegroundPushImplementation.configuration else {
            print("Push configuration is not set")
            return
        }
        
        self.disappearedPushAnimation = config.disappearedAnimation
        
        drawPush(style: config.style,
                 duration: config.duration,
                 vibration: config.vibration,
                 disappearedAnimation: config.disappearedAnimation,
                 gradientColors: config.gradientColors,
                 backgroundColor: config.backgroundColor,
                 usePushAnimation: config.usePushAnimation,
                 titlePushFont: config.titlePushFont,
                 messagePushFont: config.messagePushFont,
                 userInfo: userInfo)
    }
    
    @objc
    public static weak var delegate: AnyObject? {
        get { shared._delegate }
        set { shared._delegate = newValue as? (NSObjectProtocol & PWForegroundPushDelegate) }
    }
    
    private weak var _delegate: PWForegroundPushDelegate?
    
    @available(iOS 13.0, *)
    private static func drawPush(style: PWForegroundPushStyle,
                                 duration: Int,
                                 vibration: PWForegroundPushHapticFeedback,
                                 disappearedAnimation: PWForegroundPushDisappearedAnimation,
                                 gradientColors: [UIColor]?,
                                 backgroundColor: UIColor?,
                                 usePushAnimation: Bool,
                                 titlePushFont: UIFont?,
                                 messagePushFont: UIFont?,
                                 userInfo: [AnyHashable: Any]) {
        
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        let titleText = alert?["title"] as? String ?? ""
        let bodyText = alert?["body"] as? String ?? ""
        let attachmentURL = userInfo["attachment"] as? String
        
        func showNotification(with image: UIImage?, animation: PWForegroundPushDisappearedAnimation) {
            let notificationView = UIView()
            notificationView.backgroundColor = .clear
            notificationView.alpha = 0
            notificationView.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(notificationView)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            notificationView.addGestureRecognizer(tapGesture)
            notificationView.isUserInteractionEnabled = true
            notificationView.accessibilityElements = [userInfo]
            
            // --- Icon ---
            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFill
            iconView.layer.cornerRadius = 8
            iconView.clipsToBounds = true
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 48),
                iconView.heightAnchor.constraint(equalToConstant: 48)
            ])
            if let appIcon = appIconImage() {
                iconView.image = appIcon
            } else {
                let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                              Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "?"
                let firstLetter = String(appName.prefix(1)).uppercased()

                let size = CGSize(width: 48, height: 48)
                let renderer = UIGraphicsImageRenderer(size: size)

                let image = renderer.image { context in
                    let rect = CGRect(origin: .zero, size: size)

                    UIColor.systemGray5.setFill()
                    context.fill(rect)

                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center

                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                        .foregroundColor: UIColor.gray,
                        .paragraphStyle: paragraphStyle
                    ]

                    let text = NSAttributedString(string: firstLetter, attributes: attrs)
                    let textSize = text.size()
                    let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                          y: (size.height - textSize.height) / 2,
                                          width: textSize.width,
                                          height: textSize.height)
                    text.draw(in: textRect)
                }

                iconView.image = image
            }
            
            // --- Text ---
            let titleLabel = UILabel()
            titleLabel.text = titleText
            titleLabel.font = self.titlePushFont ?? .boldSystemFont(ofSize: 18)
            titleLabel.textColor = titlePushColor ?? .white
            titleLabel.numberOfLines = 0
            
            let bodyLabel = UILabel()
            bodyLabel.text = bodyText
            bodyLabel.font = self.messagePushFont ?? .systemFont(ofSize: 16)
            bodyLabel.textColor = messagePushColor ?? .white
            bodyLabel.numberOfLines = 0
            
            let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
            textStack.axis = .vertical
            textStack.alignment = .leading
            textStack.spacing = 4
            textStack.translatesAutoresizingMaskIntoConstraints = false
            
            let hStack = UIStackView(arrangedSubviews: [iconView, textStack])
            hStack.axis = .horizontal
            hStack.alignment = .center
            hStack.spacing = 12
            hStack.translatesAutoresizingMaskIntoConstraints = false
            
            // --- Image view ---
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            if let img = image {
                imageView.image = img
            }
            
            let vStack = UIStackView(arrangedSubviews: image != nil ? [hStack, imageView] : [hStack])
            vStack.axis = .vertical
            vStack.spacing = 8
            vStack.translatesAutoresizingMaskIntoConstraints = false
            notificationView.addSubview(vStack)
            
            NSLayoutConstraint.activate([
                notificationView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                notificationView.topAnchor.constraint(equalTo: window.topAnchor, constant: 65),
                notificationView.widthAnchor.constraint(equalTo: window.widthAnchor, multiplier: 0.9),
                
                vStack.leadingAnchor.constraint(equalTo: notificationView.leadingAnchor, constant: 16),
                vStack.trailingAnchor.constraint(equalTo: notificationView.trailingAnchor, constant: -16),
                vStack.topAnchor.constraint(equalTo: notificationView.topAnchor, constant: 16),
                vStack.bottomAnchor.constraint(equalTo: notificationView.bottomAnchor, constant: -16)
            ])
            
            if let img = image {
                let aspect = img.size.height / img.size.width
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: aspect).isActive = true
            }
            
            notificationView.layoutIfNeeded()
            ForegroundPushShape.applyStyle(style, to: notificationView,
                                           gradientColors: gradientColors,
                                           backgroundColor: backgroundColor,
                                           usePushAnimation: usePushAnimation,
                                           useLiquidView: false)
            
            // --- Show animation ---
            notificationView.transform = CGAffineTransform(translationX: 0, y: -100).rotated(by: -0.05)
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.2,
                           options: .curveEaseOut) {
                notificationView.alpha = 1
                notificationView.transform = .identity
            }
            
            disappearedAnimation(animation: animation, view: notificationView)
        }
#if compiler(>=5.13)
        @available(iOS 26.0, *)
        func showGlassNotification(with image: UIImage?,
                                   animation: PWForegroundPushDisappearedAnimation) {
            let glassEffect = UIGlassEffect()
            glassEffect.isInteractive = true
            
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.layer.cornerRadius = 20
            containerView.clipsToBounds = true
            containerView.alpha = 0
            window.addSubview(containerView)
            
            let effectView = UIVisualEffectView(effect: glassEffect)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(effectView)
            
            NSLayoutConstraint.activate([
                effectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                effectView.topAnchor.constraint(equalTo: containerView.topAnchor),
                effectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            containerView.addGestureRecognizer(tapGesture)
            containerView.isUserInteractionEnabled = true
            containerView.accessibilityElements = [userInfo]
            
            // --- Icon ---
            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFill
            iconView.layer.cornerRadius = 8
            iconView.clipsToBounds = true
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 48),
                iconView.heightAnchor.constraint(equalToConstant: 48)
            ])
            if let appIcon = appIconImage() {
                iconView.image = appIcon
            } else {
                let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                              Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "?"
                let firstLetter = String(appName.prefix(1)).uppercased()

                let size = CGSize(width: 48, height: 48)
                let renderer = UIGraphicsImageRenderer(size: size)

                let image = renderer.image { context in
                    let rect = CGRect(origin: .zero, size: size)

                    UIColor.systemGray5.setFill()
                    context.fill(rect)

                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center

                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                        .foregroundColor: UIColor.gray,
                        .paragraphStyle: paragraphStyle
                    ]

                    let text = NSAttributedString(string: firstLetter, attributes: attrs)
                    let textSize = text.size()
                    let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                          y: (size.height - textSize.height) / 2,
                                          width: textSize.width,
                                          height: textSize.height)
                    text.draw(in: textRect)
                }

                iconView.image = image
            }
            
            // --- Text ---
            let titleLabel = UILabel()
            titleLabel.text = titleText
            titleLabel.font = self.titlePushFont ?? .boldSystemFont(ofSize: 18)
            titleLabel.textColor = self.titlePushColor ?? .black
            titleLabel.numberOfLines = 0
            
            let bodyLabel = UILabel()
            bodyLabel.text = bodyText
            bodyLabel.font = self.messagePushFont ?? .systemFont(ofSize: 16)
            bodyLabel.textColor = self.messagePushColor ?? .black
            bodyLabel.numberOfLines = 0
            
            let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
            textStack.axis = .vertical
            textStack.alignment = .leading
            textStack.spacing = 4
            textStack.translatesAutoresizingMaskIntoConstraints = false
            
            let hStack = UIStackView(arrangedSubviews: [iconView, textStack])
            hStack.axis = .horizontal
            hStack.alignment = .center
            hStack.spacing = 12
            hStack.translatesAutoresizingMaskIntoConstraints = false
            
            // --- Image view ---
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            if let img = image {
                imageView.image = img
            }
            
            let vStack = UIStackView(arrangedSubviews: image != nil ? [hStack, imageView] : [hStack])
            vStack.axis = .vertical
            vStack.spacing = 8
            vStack.translatesAutoresizingMaskIntoConstraints = false
            effectView.contentView.addSubview(vStack)
            
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                containerView.topAnchor.constraint(equalTo: window.topAnchor, constant: 65),
                containerView.widthAnchor.constraint(equalTo: window.widthAnchor, multiplier: 0.9),
                
                vStack.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 16),
                vStack.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -16),
                vStack.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 16),
                vStack.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -16)
            ])
            
            if let img = image {
                let aspect = img.size.height / img.size.width
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: aspect).isActive = true
            }
            
            containerView.layoutIfNeeded()
            ForegroundPushShape.applyStyle(style, to: containerView,
                                           gradientColors: gradientColors,
                                           backgroundColor: backgroundColor,
                                           usePushAnimation: usePushAnimation,
                                           useLiquidView: true)
            
            // --- Show animation ---
            containerView.transform = CGAffineTransform(translationX: 0, y: -100).rotated(by: -0.05)
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.2,
                           options: .curveEaseOut) {
                containerView.alpha = 1
                containerView.transform = .identity
            }
            
            disappearedAnimation(animation: animation, view: containerView)
        }
#else
        func showGlassNotification(with image: UIImage?,
                                   animation: PWForegroundPushDisappearedAnimation) {
            let blurEffect = UIBlurEffect(style: .systemMaterial)
            
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.layer.cornerRadius = 20
            containerView.clipsToBounds = true
            containerView.alpha = 0
            window.addSubview(containerView)
            
            let effectView = UIVisualEffectView(effect: blurEffect)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(effectView)
            
            NSLayoutConstraint.activate([
                effectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                effectView.topAnchor.constraint(equalTo: containerView.topAnchor),
                effectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            containerView.addGestureRecognizer(tapGesture)
            containerView.isUserInteractionEnabled = true
            containerView.accessibilityElements = [userInfo]
            
            // --- Icon ---
            let iconView = UIImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFill
            iconView.layer.cornerRadius = 8
            iconView.clipsToBounds = true
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 48),
                iconView.heightAnchor.constraint(equalToConstant: 48)
            ])
            if let appIcon = appIconImage() {
                iconView.image = appIcon
            } else {
                let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                              Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "?"
                let firstLetter = String(appName.prefix(1)).uppercased()

                let size = CGSize(width: 48, height: 48)
                let renderer = UIGraphicsImageRenderer(size: size)

                let image = renderer.image { context in
                    let rect = CGRect(origin: .zero, size: size)

                    UIColor.systemGray5.setFill()
                    context.fill(rect)

                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center

                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                        .foregroundColor: UIColor.gray,
                        .paragraphStyle: paragraphStyle
                    ]

                    let text = NSAttributedString(string: firstLetter, attributes: attrs)
                    let textSize = text.size()
                    let textRect = CGRect(x: (size.width - textSize.width) / 2,
                                          y: (size.height - textSize.height) / 2,
                                          width: textSize.width,
                                          height: textSize.height)
                    text.draw(in: textRect)
                }

                iconView.image = image
            }
            
            // --- Text ---
            let titleLabel = UILabel()
            titleLabel.text = titleText
            titleLabel.font = self.titlePushFont ?? .boldSystemFont(ofSize: 18)
            titleLabel.textColor = self.titlePushColor ?? .black
            titleLabel.numberOfLines = 0
            
            let bodyLabel = UILabel()
            bodyLabel.text = bodyText
            bodyLabel.font = self.messagePushFont ?? .systemFont(ofSize: 16)
            bodyLabel.textColor = self.messagePushColor ?? .black
            bodyLabel.numberOfLines = 0
            
            let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
            textStack.axis = .vertical
            textStack.alignment = .leading
            textStack.spacing = 4
            textStack.translatesAutoresizingMaskIntoConstraints = false
            
            let hStack = UIStackView(arrangedSubviews: [iconView, textStack])
            hStack.axis = .horizontal
            hStack.alignment = .center
            hStack.spacing = 12
            hStack.translatesAutoresizingMaskIntoConstraints = false
            
            // --- Image view ---
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            if let img = image {
                imageView.image = img
            }
            
            let vStack = UIStackView(arrangedSubviews: image != nil ? [hStack, imageView] : [hStack])
            vStack.axis = .vertical
            vStack.spacing = 8
            vStack.translatesAutoresizingMaskIntoConstraints = false
            effectView.contentView.addSubview(vStack)
            
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                containerView.topAnchor.constraint(equalTo: window.topAnchor, constant: 65),
                containerView.widthAnchor.constraint(equalTo: window.widthAnchor, multiplier: 0.9),
                
                vStack.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 16),
                vStack.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -16),
                vStack.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 16),
                vStack.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -16)
            ])
            
            if let img = image {
                let aspect = img.size.height / img.size.width
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: aspect).isActive = true
            }
            
            containerView.layoutIfNeeded()
            ForegroundPushShape.applyStyle(style, to: containerView,
                                           gradientColors: gradientColors,
                                           backgroundColor: backgroundColor,
                                           usePushAnimation: usePushAnimation,
                                           useLiquidView: false) // No glass effect
            
            // --- Show animation ---
            containerView.transform = CGAffineTransform(translationX: 0, y: -100).rotated(by: -0.05)
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.2,
                           options: .curveEaseOut) {
                containerView.alpha = 1
                containerView.transform = .identity
            }
            
            disappearedAnimation(animation: animation, view: containerView)
        }
#endif
        
        
        func disappearedAnimation(animation: PWForegroundPushDisappearedAnimation, view: UIView) {
            switch animation {
            case .balls:
                scheduleDisappearBalls(for: view, animation: animation)
            case .regularPush:
                scheduleDisappearPush(for: view)
            @unknown default:
                scheduleDisappearPush(for: view)
            }
        }
        
        func scheduleDisappearPush(for view: UIView, duration: TimeInterval = 3.0) {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(withDuration: 0.4,
                               delay: 0,
                               options: .curveEaseIn,
                               animations: {
                    view.transform = CGAffineTransform(translationX: 0, y: -300)
                    view.alpha = 1
                }) { _ in
                    view.removeFromSuperview()
                }
            }
        }
        
        func scheduleDisappearBalls(for view: UIView, animation: PWForegroundPushDisappearedAnimation) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) {
                guard let superview = view.superview else { return }
                
                UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
                view.layer.render(in: UIGraphicsGetCurrentContext()!)
                guard let snapshotImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
                UIGraphicsEndImageContext()
                
                let ballDiameter: CGFloat = 12
                let cols = Int(ceil(snapshotImage.size.width / ballDiameter))
                let rows = Int(ceil(snapshotImage.size.height / ballDiameter))
                
                var balls: [UIView] = []
                
                for row in 0..<rows {
                    for col in 0..<cols {
                        let x = CGFloat(col) * ballDiameter
                        let y = CGFloat(row) * ballDiameter
                        let rect = CGRect(x: x, y: y, width: ballDiameter, height: ballDiameter)
                        
                        guard let cgImage = snapshotImage.cgImage?.cropping(to: rect) else { continue }
                        
                        let ball = UIImageView(image: UIImage(cgImage: cgImage))
                        ball.frame = view.convert(rect, to: superview)
                        ball.layer.cornerRadius = ballDiameter / 2
                        ball.clipsToBounds = true
                        superview.addSubview(ball)
                        balls.append(ball)
                    }
                }
                
                view.removeFromSuperview()
                
                for ball in balls {
                    let dx = CGFloat.random(in: -150...150)
                    let dy = CGFloat.random(in: -200...50)
                    let rotation = CGFloat.random(in: -CGFloat.pi...CGFloat.pi)
                    let duration = Double.random(in: 0.5...1.2)
                    
                    UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                        ball.center = CGPoint(x: ball.center.x + dx, y: ball.center.y + dy)
                        ball.transform = CGAffineTransform(rotationAngle: rotation).scaledBy(x: 0.1, y: 0.1)
                        ball.alpha = 0
                    }) { _ in
                        ball.removeFromSuperview()
                    }
                }
            }
        }
        
        // MARK: - Load attachment (image or GIF)
        if let urlString = attachmentURL, let url = URL(string: urlString) {
            DispatchQueue.global().async {
                var loadedImage: UIImage? = nil
                if url.pathExtension.lowercased() == "gif",
                   let data = try? Data(contentsOf: url),
                   let source = CGImageSourceCreateWithData(data as CFData, nil) {
                    
                    let count = CGImageSourceGetCount(source)
                    var images: [UIImage] = []
                    var duration: Double = 0
                    
                    for i in 0..<count {
                        if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                            images.append(UIImage(cgImage: cgImage))
                            let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any]
                            let gifInfo = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
                            let delay = gifInfo?[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
                            duration += delay
                        }
                    }
                    
                    loadedImage = UIImage.animatedImage(with: images, duration: duration)
                } else if let data = try? Data(contentsOf: url) {
                    loadedImage = UIImage(data: data)
                }
                
                DispatchQueue.main.async {
                    if useLiquidView, #available(iOS 26.0, *) {
                        showGlassNotification(with: loadedImage, animation: self.disappearedPushAnimation)
                    } else {
                        showNotification(with: loadedImage, animation: self.disappearedPushAnimation)
                    }
                    vibration.trigger()
                }
            }
        } else {
            if useLiquidView, #available(iOS 26.0, *) {
                showGlassNotification(with: nil, animation: self.disappearedPushAnimation)
            } else {
                showNotification(with: nil, animation: self.disappearedPushAnimation)
            }
        }
    }
    
    
    private static func appIconImage() -> UIImage? {
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
    
    @objc private static func handleTap(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view,
              let elements = view.accessibilityElements,
              let userInfo = elements.first as? [AnyHashable: Any] else { return }
        
        if let delegate = PushwooshForegroundPushImplementation.delegate {
            if delegate.responds(to: #selector(PWForegroundPushDelegate.didTapForegroundPush(_:))) {
                delegate.didTapForegroundPush(userInfo)
                view.removeFromSuperview()
            }
        }
    }
    
    @objc
    public static func foregroundPush() -> AnyClass {
        return PushwooshForegroundPushImplementation.self
    }
    
    @objc
    static func foregroundNotificationWith(style: PWForegroundPushStyle,
                                           duration: Int = 3,
                                           vibration: PWForegroundPushHapticFeedback,
                                           disappearedPushAnimation: PWForegroundPushDisappearedAnimation) {
        configuration = ForegroundPushConfiguration(style: style,
                                                    duration: duration,
                                                    vibration: vibration,
                                                    disappearedAnimation: disappearedPushAnimation)
    }
    
    @objc
    public static var gradientColors: [UIColor]? {
        get { configuration?.gradientColors }
        set { configuration?.gradientColors = newValue }
    }
    
    @objc
    public static var backgroundColor: UIColor? {
        get { configuration?.backgroundColor }
        set { configuration?.backgroundColor = newValue }
    }
    
    @objc
    public static var usePushAnimation: Bool {
        get { configuration.usePushAnimation }
        set { configuration.usePushAnimation = newValue }
    }
    
    @objc
    public static var titlePushColor: UIColor? {
        get { configuration?.titlePushColor }
        set { configuration?.titlePushColor = newValue }
    }
    
    @objc
    public static var messagePushColor: UIColor? {
        get { configuration?.messagePushColor }
        set { configuration?.messagePushColor = newValue }
    }
    
    @objc
    public static var titlePushFont: UIFont? {
        get { configuration?.titlePushFont }
        set { configuration?.titlePushFont = newValue }
    }
    
    @objc
    public static var messagePushFont: UIFont? {
        get { configuration?.messagePushFont }
        set { configuration?.messagePushFont = newValue }
    }
    
    @objc
    public static var useLiquidView: Bool {
        get { configuration.useLiquidView }
        set { configuration.useLiquidView = newValue }
    }
}

extension PWForegroundPushHapticFeedback {
    func trigger() {
        switch self {
        case .none:
            return
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        case .notification:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        @unknown default:
            break
        }
    }
}
