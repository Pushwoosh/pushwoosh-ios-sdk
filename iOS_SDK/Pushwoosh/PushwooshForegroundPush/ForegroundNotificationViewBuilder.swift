//
//  ForegroundNotificationViewBuilder.swift
//  PushwooshForegroundPush
//
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
class ForegroundNotificationViewBuilder {
    
    // MARK: - UI Element Creation
    
    static func createIconView() -> UIImageView {
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48)
        ])
        return iconView
    }
    
    static func createTitleLabel(text: String?, font: UIFont?, color: UIColor?) -> UILabel {
        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = font ?? .boldSystemFont(ofSize: 18)
        titleLabel.textColor = color ?? .white
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }
    
    static func createBodyLabel(text: String?, font: UIFont?, color: UIColor?) -> UILabel {
        let bodyLabel = UILabel()
        bodyLabel.text = text
        bodyLabel.font = font ?? .systemFont(ofSize: 16)
        bodyLabel.textColor = color ?? .white
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        return bodyLabel
    }
    
    static func createImageView(with image: UIImage?) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        if let img = image {
            imageView.image = img
        }
        return imageView
    }
    
    static func createTextStackView(titleLabel: UILabel, bodyLabel: UILabel) -> UIStackView {
        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        return textStack
    }
    
    static func createHorizontalStackView(iconView: UIImageView, textStack: UIStackView) -> UIStackView {
        let hStack = UIStackView(arrangedSubviews: [iconView, textStack])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false
        return hStack
    }
    
    static func createVerticalStackView(hStack: UIStackView, imageView: UIImageView? = nil) -> UIStackView {
        let arrangedViews = imageView != nil ? [hStack, imageView!] : [hStack]
        let vStack = UIStackView(arrangedSubviews: arrangedViews)
        vStack.axis = .vertical
        vStack.spacing = 8
        vStack.translatesAutoresizingMaskIntoConstraints = false
        return vStack
    }
    
    // MARK: - App Icon Generation
    
    static func configureIconView(_ iconView: UIImageView) {
        if let appIcon = AppIconProvider.appIconImage() {
            iconView.image = appIcon
        } else {
            iconView.image = AppIconProvider.createPlaceholderIcon()
        }
    }
}

// MARK: - App Icon Provider

@available(iOS 13.0, *)
class AppIconProvider {
    
    static func appIconImage() -> UIImage? {
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
              let lastIcon = iconFiles.last else {
            return nil
        }
        return UIImage(named: lastIcon)
    }
    
    static func createPlaceholderIcon() -> UIImage {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                      Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "?"
        let firstLetter = String(appName.prefix(1)).uppercased()

        let size = CGSize(width: 48, height: 48)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background
            UIColor.systemGray5.setFill()
            context.fill(rect)

            // Text
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
    }
}
