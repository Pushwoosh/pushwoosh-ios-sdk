//
//  PWTVOSUniversalRenderer.swift
//  PushwooshTVOS
//
//  Created by André Kis on 14.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@available(tvOS 11.0, *)
class PWTVOSUniversalRenderer {

    weak var actionHandler: PWTVOSButtonActionHandler?
    private var focusableViews: [UIView] = []
    private var showCloseButton: Bool = true

    init(actionHandler: PWTVOSButtonActionHandler?) {
        self.actionHandler = actionHandler
    }

    func setShowCloseButton(_ show: Bool) {
        self.showCloseButton = show
    }

    func renderElements(_ elements: [PWTVOSUniversalHTMLParser.RichMediaElement], containerWidth: CGFloat) -> UIView {
        if elements.count == 1 {
            return createView(for: elements[0], containerWidth: containerWidth)
        }

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
                view.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 20).isActive = true
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

    private func createView(for element: PWTVOSUniversalHTMLParser.RichMediaElement, containerWidth: CGFloat) -> UIView {
        switch element {
        case .image(let url, let styles):
            return createImageView(url: url, styles: styles)

        case .heading(let text, _, let styles):
            return createTextLabel(text: text, styles: styles, isBold: true)

        case .text(let text, let styles):
            return createTextLabel(text: text, styles: styles, isBold: false)

        case .textField(let placeholder, let fieldName, let styles):
            return createTextField(placeholder: placeholder, fieldName: fieldName, styles: styles)

        case .button(let text, let action, let styles):
            return createButton(text: text, action: action, styles: styles)

        case .container(let children, let styles):
            return createContainer(children: children, styles: styles, containerWidth: containerWidth)
        }
    }

    private func createImageView(url: String, styles: PWTVOSUniversalHTMLParser.ElementStyles) -> UIView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = styles.borderRadius

        if let bgColor = styles.backgroundColor {
            imageView.backgroundColor = bgColor
        }

        downloadImage(from: url) { [weak imageView] image in
            guard let imageView = imageView, let image = image else { return }
            DispatchQueue.main.async {
                imageView.image = image
            }
        }

        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return applyMargin(to: imageView, margin: styles.margin)
    }

    private func createTextLabel(text: String, styles: PWTVOSUniversalHTMLParser.ElementStyles, isBold: Bool) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = isBold ? .systemFont(ofSize: styles.fontSize, weight: .bold) : .systemFont(ofSize: styles.fontSize)
        label.textColor = styles.color ?? .black
        label.textAlignment = styles.textAlign
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        if let bgColor = styles.backgroundColor {
            label.backgroundColor = bgColor
        }

        if styles.borderRadius > 0 {
            label.layer.cornerRadius = styles.borderRadius
            label.layer.masksToBounds = true
        }

        if let borderColor = styles.borderColor {
            label.layer.borderColor = borderColor.cgColor
            label.layer.borderWidth = styles.borderWidth
        }

        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        return applyMargin(to: label, margin: styles.margin)
    }

    private func createTextField(placeholder: String, fieldName: String, styles: PWTVOSUniversalHTMLParser.ElementStyles) -> UIView {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: styles.fontSize)
        textField.textColor = styles.color ?? .white
        textField.textAlignment = styles.textAlign
        textField.backgroundColor = styles.backgroundColor ?? UIColor(white: 0.1, alpha: 1.0)
        textField.layer.cornerRadius = styles.borderRadius
        textField.layer.masksToBounds = true
        textField.accessibilityIdentifier = fieldName

        if let borderColor = styles.borderColor {
            textField.layer.borderColor = borderColor.cgColor
            textField.layer.borderWidth = styles.borderWidth
        }

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 1))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always

        let height: CGFloat = 56
        textField.heightAnchor.constraint(equalToConstant: height).isActive = true

        textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textField.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        focusableViews.append(textField)

        return applyMargin(to: textField, margin: styles.margin)
    }

    private func createButton(text: String, action: PWTVOSUniversalHTMLParser.ButtonAction, styles: PWTVOSUniversalHTMLParser.ElementStyles) -> UIView {
        let button = PWTVOSFocusButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: max(14, styles.fontSize), weight: .medium)
        button.setTitleColor(styles.color ?? .white, for: .normal)

        let bgColor = styles.backgroundColor ?? UIColor(red: 0.50, green: 0.29, blue: 1.0, alpha: 1.0)
        button.backgroundColor = bgColor
        button.layer.cornerRadius = styles.borderRadius
        button.layer.masksToBounds = true
        button.adjustsImageWhenHighlighted = false

        button.normalBackgroundColor = bgColor
        button.focusedBackgroundColor = bgColor.withAlphaComponent(0.95)

        if let borderColor = styles.borderColor {
            button.layer.borderColor = borderColor.cgColor
            button.layer.borderWidth = max(styles.borderWidth, 2)
        }

        configureButtonAction(button: button, action: action)

        let height: CGFloat = 56
        button.heightAnchor.constraint(equalToConstant: height).isActive = true

        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        focusableViews.append(button)

        return applyMargin(to: button, margin: styles.margin)
    }

    private func configureButtonAction(button: UIButton, action: PWTVOSUniversalHTMLParser.ButtonAction) {
        switch action {
        case .close:
            button.addTarget(self, action: #selector(closeButtonTapped), for: .primaryActionTriggered)

        case .openSettings:
            button.addTarget(self, action: #selector(openSettingsButtonTapped), for: .primaryActionTriggered)

        case .postEvent(let name, let attributes):
            objc_setAssociatedObject(button, &AssociatedKeys.eventName, name, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(button, &AssociatedKeys.eventAttributes, attributes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            button.addTarget(self, action: #selector(postEventButtonTapped(_:)), for: .primaryActionTriggered)

        case .sendTags(let tags):
            objc_setAssociatedObject(button, &AssociatedKeys.eventAttributes, tags, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            button.addTarget(self, action: #selector(sendTagsButtonTapped(_:)), for: .primaryActionTriggered)

        case .getTags:
            button.addTarget(self, action: #selector(getTagsButtonTapped(_:)), for: .primaryActionTriggered)

        case .setEmail(let email):
            objc_setAssociatedObject(button, &AssociatedKeys.eventAttributes, email, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            button.addTarget(self, action: #selector(setEmailButtonTapped(_:)), for: .primaryActionTriggered)

        case .getHwid:
            button.addTarget(self, action: #selector(getHwidButtonTapped), for: .primaryActionTriggered)

        case .getVersion:
            button.addTarget(self, action: #selector(getVersionButtonTapped), for: .primaryActionTriggered)

        case .getApplication:
            button.addTarget(self, action: #selector(getApplicationButtonTapped), for: .primaryActionTriggered)

        case .getUserId:
            button.addTarget(self, action: #selector(getUserIdButtonTapped), for: .primaryActionTriggered)

        case .getRichmediaCode:
            button.addTarget(self, action: #selector(getRichmediaCodeButtonTapped), for: .primaryActionTriggered)

        case .getDeviceType:
            button.addTarget(self, action: #selector(getDeviceTypeButtonTapped), for: .primaryActionTriggered)

        case .getMessageHash:
            button.addTarget(self, action: #selector(getMessageHashButtonTapped), for: .primaryActionTriggered)

        case .getInAppCode:
            button.addTarget(self, action: #selector(getInAppCodeButtonTapped), for: .primaryActionTriggered)

        case .none:
            break
        }
    }

    private func createContainer(children: [PWTVOSUniversalHTMLParser.RichMediaElement], styles: PWTVOSUniversalHTMLParser.ElementStyles, containerWidth: CGFloat) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        if let gradient = styles.backgroundGradient {
            applyGradient(to: containerView, gradient: gradient)
        } else if let bgColor = styles.backgroundColor {
            containerView.backgroundColor = bgColor
        }

        if styles.borderRadius > 0 {
            containerView.layer.cornerRadius = styles.borderRadius
            containerView.layer.masksToBounds = true
        }

        if let borderColor = styles.borderColor {
            containerView.layer.borderColor = borderColor.cgColor
            containerView.layer.borderWidth = styles.borderWidth
        }

        if let width = styles.width {
            containerView.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        if let height = styles.height {
            containerView.heightAnchor.constraint(equalToConstant: height).isActive = true
        }

        if styles.display == .flex && styles.flexDirection == .row {
            layoutChildrenHorizontally(children: children, in: containerView, styles: styles, containerWidth: containerWidth)
        } else {
            layoutChildrenVertically(children: children, in: containerView, styles: styles, containerWidth: containerWidth)
        }

        return applyMargin(to: containerView, margin: styles.margin)
    }

    private func layoutChildrenHorizontally(children: [PWTVOSUniversalHTMLParser.RichMediaElement], in containerView: UIView, styles: PWTVOSUniversalHTMLParser.ElementStyles, containerWidth: CGFloat) {
        var previousView: UIView?
        var firstFlexView: UIView?

        for child in children {
            let childView = createView(for: child, containerWidth: containerWidth)
            containerView.addSubview(childView)

            NSLayoutConstraint.activate([
                childView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: styles.padding.top),
                childView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -styles.padding.bottom)
            ])

            if let previous = previousView {
                childView.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: styles.gap).isActive = true
            } else {
                childView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: styles.padding.left).isActive = true
                firstFlexView = childView
            }

            if case .container(_, let childStyles) = child, childStyles.flex != nil {
                if let firstView = firstFlexView, firstView != childView {
                    childView.widthAnchor.constraint(equalTo: firstView.widthAnchor).isActive = true
                }
            }

            previousView = childView
        }

        if let lastView = previousView {
            lastView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -styles.padding.right).isActive = true
        }
    }

    private func layoutChildrenVertically(children: [PWTVOSUniversalHTMLParser.RichMediaElement], in containerView: UIView, styles: PWTVOSUniversalHTMLParser.ElementStyles, containerWidth: CGFloat) {
        if children.isEmpty {
            let totalHeight = styles.padding.top + styles.padding.bottom
            if totalHeight > 0 {
                containerView.heightAnchor.constraint(equalToConstant: totalHeight).isActive = true
            }
            return
        }

        var previousView: UIView?

        for child in children {
            let childView = createView(for: child, containerWidth: containerWidth)
            containerView.addSubview(childView)

            NSLayoutConstraint.activate([
                childView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: styles.padding.left),
                childView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -styles.padding.right)
            ])

            if let previous = previousView {
                childView.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: styles.gap).isActive = true
            } else {
                childView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: styles.padding.top).isActive = true
            }

            previousView = childView
        }

        if let lastView = previousView {
            lastView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -styles.padding.bottom).isActive = true
        }
    }

    private func applyGradient(to view: UIView, gradient: PWTVOSUniversalHTMLParser.GradientInfo) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = gradient.colors.map { $0.cgColor }

        let angleInRadians = (gradient.angle - 90) * .pi / 180
        let startPoint = CGPoint(
            x: 0.5 + cos(angleInRadians) * 0.5,
            y: 0.5 + sin(angleInRadians) * 0.5
        )
        let endPoint = CGPoint(
            x: 0.5 - cos(angleInRadians) * 0.5,
            y: 0.5 - sin(angleInRadians) * 0.5
        )

        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.frame = view.bounds

        view.layer.insertSublayer(gradientLayer, at: 0)

        view.layoutIfNeeded()
        DispatchQueue.main.async {
            gradientLayer.frame = view.bounds
        }
    }

    private func applyMargin(to view: UIView, margin: UIEdgeInsets) -> UIView {
        if margin == .zero {
            return view
        }

        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)

        let topConstraint = view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: margin.top)
        let leadingConstraint = view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: margin.left)
        let trailingConstraint = view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -margin.right)
        let bottomConstraint = view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -margin.bottom)

        trailingConstraint.priority = .defaultHigh
        bottomConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            topConstraint,
            leadingConstraint,
            trailingConstraint,
            bottomConstraint
        ])

        return wrapper
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

    @objc private func setEmailButtonTapped(_ sender: UIButton) {
        guard let email = objc_getAssociatedObject(sender, &AssociatedKeys.eventAttributes) as? String else {
            return
        }

        actionHandler?.handleSetEmailButton(email: email)
    }

    @objc private func getHwidButtonTapped() {
        actionHandler?.handleGetHwidButton { _ in
        }
    }

    @objc private func getVersionButtonTapped() {
        actionHandler?.handleGetVersionButton { _ in
        }
    }

    @objc private func getApplicationButtonTapped() {
        actionHandler?.handleGetApplicationButton { _ in
        }
    }

    @objc private func getUserIdButtonTapped() {
        actionHandler?.handleGetUserIdButton { _ in
        }
    }

    @objc private func getRichmediaCodeButtonTapped() {
        actionHandler?.handleGetRichmediaCodeButton { _ in
        }
    }

    @objc private func getDeviceTypeButtonTapped() {
        actionHandler?.handleGetDeviceTypeButton { _ in
        }
    }

    @objc private func getMessageHashButtonTapped() {
        actionHandler?.handleGetMessageHashButton { _ in
        }
    }

    @objc private func getInAppCodeButtonTapped() {
        actionHandler?.handleGetInAppCodeButton { _ in
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
