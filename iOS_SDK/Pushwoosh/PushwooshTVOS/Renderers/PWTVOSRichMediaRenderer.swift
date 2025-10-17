//
//  PWTVOSRichMediaRenderer.swift
//  PushwooshTVOS
//
//  Created by André Kis on 13.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import PushwooshCore

@available(tvOS 11.0, *)
class PWTVOSRichMediaRenderer {

    weak var actionHandler: PWTVOSButtonActionHandler?
    private var focusableViews: [UIView] = []

    init(actionHandler: PWTVOSButtonActionHandler?) {
        self.actionHandler = actionHandler
    }


    func renderElements(_ elements: [PWTVOSHTMLParser.RichMediaElement], containerWidth: CGFloat) -> UIView {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        var previousView: UIView?

        for element in elements {
            let view = createView(for: element, containerWidth: containerWidth)
            contentView.addSubview(view)

            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])

            if let previous = previousView {
                view.topAnchor.constraint(equalTo: previous.bottomAnchor).isActive = true
            } else {
                view.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            }

            previousView = view
        }

        if let lastView = previousView {
            lastView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        }

        return contentView
    }


    private func createView(for element: PWTVOSHTMLParser.RichMediaElement, containerWidth: CGFloat) -> UIView {
        switch element {
        case .image(let url):
            return createImageView(url: url, containerWidth: containerWidth)

        case .heading(let text, let fontSize, let color, let textAlignment):
            return createHeadingView(text: text, fontSize: fontSize, color: color, textAlignment: textAlignment)

        case .text(let text, let fontSize, let color, let textAlignment):
            return createTextView(text: text, fontSize: fontSize, color: color, textAlignment: textAlignment)

        case .textField(let placeholder, let fieldName, let fontSize, let textColor, let bgColor, let borderColor, let textAlignment):
            return createTextFieldView(placeholder: placeholder, fieldName: fieldName, fontSize: fontSize, textColor: textColor, bgColor: bgColor, borderColor: borderColor, textAlignment: textAlignment)

        case .button(let text, let bgColor, let textColor, let borderColor, let isClose, let isOpenSettings, let isSendTags, let isGetTags, let eventName, let eventAttributes, let tags):
            return createButtonView(
                text: text,
                bgColor: bgColor,
                textColor: textColor,
                borderColor: borderColor,
                isClose: isClose,
                isOpenSettings: isOpenSettings,
                isSendTags: isSendTags,
                isGetTags: isGetTags,
                eventName: eventName,
                eventAttributes: eventAttributes,
                tags: tags
            )

        case .container(let children, let layout):
            return createContainer(children: children, layout: layout, containerWidth: containerWidth)
        }
    }

    private func createContainer(children: [PWTVOSHTMLParser.RichMediaElement], layout: PWTVOSHTMLParser.ContainerLayout, containerWidth: CGFloat) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        if let bgColor = layout.backgroundColor {
            containerView.backgroundColor = bgColor
        }

        if layout.cornerRadius > 0 {
            containerView.layer.cornerRadius = layout.cornerRadius
            containerView.layer.masksToBounds = true
        }

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = layout.direction == .horizontal ? .horizontal : .vertical
        stackView.spacing = layout.spacing

        switch layout.distribution {
        case .fillEqually:
            stackView.distribution = .fillEqually
        case .fillProportionally:
            stackView.distribution = .fillProportionally
        case .fill:
            stackView.distribution = .fill
        }

        containerView.addSubview(stackView)

        let childWidth = layout.direction == .horizontal ? containerWidth / CGFloat(children.count) : containerWidth

        for child in children {
            let childView = createView(for: child, containerWidth: childWidth)
            stackView.addArrangedSubview(childView)
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: layout.padding.top),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: layout.padding.left),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -layout.padding.right),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -layout.padding.bottom)
        ])

        return containerView
    }


    private func createImageView(url: String, containerWidth: CGFloat) -> UIView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear

        downloadImage(from: url) { [weak imageView] image in
            guard let imageView = imageView, let image = image else { return }

            DispatchQueue.main.async {
                imageView.image = image
            }
        }

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        containerView.setContentHuggingPriority(.defaultLow, for: .vertical)
        containerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return containerView
    }


    private func createHeadingView(text: String, fontSize: CGFloat, color: UIColor?, textAlignment: NSTextAlignment) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: fontSize, weight: .bold)
        label.textColor = color ?? .black
        label.textAlignment = textAlignment
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        containerView.setContentHuggingPriority(.required, for: .vertical)
        containerView.setContentCompressionResistancePriority(.required, for: .vertical)

        return containerView
    }


    private func createTextView(text: String, fontSize: CGFloat, color: UIColor?, textAlignment: NSTextAlignment) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: fontSize)
        label.textColor = color ?? .black
        label.textAlignment = textAlignment
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        containerView.setContentHuggingPriority(.required, for: .vertical)
        containerView.setContentCompressionResistancePriority(.required, for: .vertical)

        return containerView
    }


    private func createTextFieldView(placeholder: String, fieldName: String, fontSize: CGFloat, textColor: UIColor?, bgColor: UIColor?, borderColor: UIColor?, textAlignment: NSTextAlignment) -> UIView {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: fontSize)
        textField.textColor = textColor ?? .white
        textField.textAlignment = textAlignment
        textField.backgroundColor = bgColor ?? UIColor(white: 0.1, alpha: 1.0)
        textField.layer.cornerRadius = 12
        textField.layer.masksToBounds = true
        textField.accessibilityIdentifier = fieldName

        if let borderColor = borderColor {
            textField.layer.borderColor = borderColor.cgColor
            textField.layer.borderWidth = 2
        }

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            textField.heightAnchor.constraint(equalToConstant: 56),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])

        containerView.setContentHuggingPriority(.required, for: .vertical)
        containerView.setContentCompressionResistancePriority(.required, for: .vertical)

        focusableViews.append(textField)

        return containerView
    }


    private func createButtonView(
        text: String,
        bgColor: UIColor,
        textColor: UIColor,
        borderColor: UIColor?,
        isClose: Bool,
        isOpenSettings: Bool,
        isSendTags: Bool,
        isGetTags: Bool,
        eventName: String?,
        eventAttributes: [String: Any]?,
        tags: [String: Any]?
    ) -> UIView {
        let button = PWTVOSFocusButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(textColor, for: .normal)
        button.backgroundColor = bgColor
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.adjustsImageWhenHighlighted = false

        button.normalBackgroundColor = bgColor
        button.focusedBackgroundColor = bgColor.withAlphaComponent(0.95)

        if let borderColor = borderColor {
            button.layer.borderColor = borderColor.cgColor
            button.layer.borderWidth = 2
        }
        if isClose {
            button.addTarget(self, action: #selector(closeButtonTapped), for: .primaryActionTriggered)
        } else if isOpenSettings {
            button.addTarget(self, action: #selector(openSettingsButtonTapped), for: .primaryActionTriggered)
        } else if isSendTags, let tags = tags {
            objc_setAssociatedObject(button, &AssociatedKeys.eventAttributes, tags, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            button.addTarget(self, action: #selector(sendTagsButtonTapped(_:)), for: .primaryActionTriggered)
        } else if isGetTags {
            button.addTarget(self, action: #selector(getTagsButtonTapped(_:)), for: .primaryActionTriggered)
        } else if let eventName = eventName {
            objc_setAssociatedObject(button, &AssociatedKeys.eventName, eventName, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(button, &AssociatedKeys.eventAttributes, eventAttributes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            button.addTarget(self, action: #selector(postEventButtonTapped(_:)), for: .primaryActionTriggered)
        }

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            button.heightAnchor.constraint(equalToConstant: 52),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        containerView.setContentHuggingPriority(.required, for: .vertical)
        containerView.setContentCompressionResistancePriority(.required, for: .vertical)

        focusableViews.append(button)

        return containerView
    }


    @objc private func closeButtonTapped() {
        actionHandler?.handleCloseButton()
    }

    @objc private func openSettingsButtonTapped() {
        actionHandler?.handleOpenSettingsButton()
    }

    @objc private func postEventButtonTapped(_ sender: UIButton) {
        guard let eventName = objc_getAssociatedObject(sender, &AssociatedKeys.eventName) as? String else {
            return
        }

        let eventAttributes = objc_getAssociatedObject(sender, &AssociatedKeys.eventAttributes) as? [String: Any]
        actionHandler?.handlePostEventButton(eventName: eventName, eventAttributes: eventAttributes)
    }

    @objc private func sendTagsButtonTapped(_ sender: UIButton) {
        guard let tags = objc_getAssociatedObject(sender, &AssociatedKeys.eventAttributes) as? [String: Any] else {
            return
        }

        actionHandler?.handleSendTagsButton(tags: tags)
    }

    @objc private func getTagsButtonTapped(_ sender: UIButton) {
        actionHandler?.handleGetTagsButton { _ in
        }
    }


    private func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            let image = UIImage(data: data)
            completion(image)
        }.resume()
    }


    func getFocusableViews() -> [UIView] {
        return focusableViews
    }

    func getTextFieldValue(fieldName: String) -> String? {
        for view in focusableViews {
            if let textField = view as? UITextField,
               textField.accessibilityIdentifier == fieldName {
                return textField.text
            }
        }
        return nil
    }

    func getAllTextFieldValues() -> [String: String] {
        var values: [String: String] = [:]
        for view in focusableViews {
            if let textField = view as? UITextField,
               let fieldName = textField.accessibilityIdentifier,
               let text = textField.text, !text.isEmpty {
                values[fieldName] = text
            }
        }
        return values
    }
}


private struct AssociatedKeys {
    static var eventName = "eventName"
    static var eventAttributes = "eventAttributes"
}


@available(tvOS 11.0, *)
class PWTVOSFocusButton: UIButton {
    var normalBackgroundColor: UIColor = .clear
    var focusedBackgroundColor: UIColor = .white
    private var allowFocus: Bool = false

    override var canBecomeFocused: Bool {
        return allowFocus
    }

    func enableFocus() {
        allowFocus = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 8
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                self.layer.cornerRadius = 8
            } else {
                self.transform = .identity
                self.layer.cornerRadius = 8
            }
        }, completion: nil)
    }
}
