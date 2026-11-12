//
//  PWInlineRenderer.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit

/// Builds a self-sizing UIKit view tree for an inline block: width comes from the slot, height
/// from the content.
struct PWInlineRenderer {

    /// Content changed its own height after layout (an image without `aspect` finished loading).
    let onSizeChange: () -> Void
    /// `nodeId` = the tapped node, `nil` = the banner itself.
    let onAction: (PWInlineAction, _ nodeId: String?) -> Void
    /// Asked before `pushwoosh.postEvent()` of an HTML banner is sent; `false` drops the event.
    let canPostEvent: () -> Bool
    /// A tap on an HTML element with its own action (link, control, `data-pw-id`); the page runs the action.
    /// `elementId` = the element's `data-pw-id`, `nil` for an unmarked element.
    var onElementTap: (_ elementId: String?) -> Void = { _ in }

    func makeView(_ banner: PWInlineBanner) -> UIView {
        let content = makeContent(banner)
        guard let close = banner.close else {
            return content
        }
        return PWInlineClosableView(content: content, close: close) { [onAction] in
            onAction(.close, nil)
        }
    }

    private func makeContent(_ banner: PWInlineBanner) -> UIView {
        let tap = banner.action.map { action in { [onAction] in onAction(action, nil) } }
        switch banner.content {
        case .native(let root):
            let view = makeView(root)
            guard let tap = tap else {
                return view
            }
            let box = PWInlineBoxView(content: view, style: PWInlineStyle(), darkStyle: nil, padding: .zero)
            box.onTap = tap
            return box
        case .html(let html):
            let view = PWInlineHTMLBannerView(html: html, onClose: { [onAction] in onAction(.close, nil) },
                                              onSizeChange: onSizeChange, canPostEvent: canPostEvent)
            view.onTap = tap
            view.onElementTap = onElementTap
            return view
        case .control:
            return UIView()
        }
    }

    func makeView(_ node: PWInlineNode) -> UIView {
        makeView(node, parentAxis: .vertical)
    }

    private func makeView(_ node: PWInlineNode, parentAxis: NSLayoutConstraint.Axis) -> UIView {
        let content: UIView
        var padding = node.style.padding
        switch node.kind {
        case .text(let text):
            content = label(text)
        case .image(let image):
            content = imageView(image)
        case .button(let button):
            content = self.button(button, insets: padding, action: node.action.map { action in { [onAction] in onAction(action, node.id) } })
            padding = .zero
        case .video(let video):
            content = PWInlineVideoView(video)
        case .stack(let stack):
            content = stack.layout == .overlay ? overlay(stack) : self.stack(stack)
        case .pager(let pager):
            content = PWInlinePagerView(pages: pager.pages.map { makeView($0) }, pager: pager)
        case .spacer(let size):
            content = spacer(size, parentAxis)
        case .divider(let divider):
            content = self.divider(divider, parentAxis)
        }
        var tap: (() -> Void)?
        if let action = node.action, !(content is UIButton) {
            tap = { [onAction] in onAction(action, node.id) }
        }
        guard !node.style.isPlain || node.darkStyle != nil || tap != nil || content is UIButton else {
            return content
        }
        let box = PWInlineBoxView(content: content, style: node.style, darkStyle: node.darkStyle, padding: padding)
        box.onTap = tap
        if let button = content as? UIButton {
            box.pressFeedback(from: button)
        }
        return box
    }

    private func label(_ text: PWInlineText) -> UILabel {
        let label = UILabel()
        let font = scaledFont(size: text.size, weight: text.weight)
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = text.color ?? .label
        label.textAlignment = text.alignment
        label.numberOfLines = text.lines
        if text.lines != 1 {
            label.setContentCompressionResistancePriority(UILayoutPriority(749), for: .horizontal)
        }
        if text.strikethrough {
            label.attributedText = NSAttributedString(string: text.text, attributes: [
                .font: font,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ])
        } else {
            label.text = text.text
        }
        return label
    }

    private func imageView(_ image: PWInlineImage) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            view.setContentCompressionResistancePriority(.defaultLow, for: axis)
            view.setContentHuggingPriority(.defaultLow, for: axis)
        }
        var ratio = PWInlineRenderer.aspectConstraint(view, image.aspect ?? 2)
        ratio.isActive = true
        PWInAppImageLoader.shared.load(image.url, into: view) { [onSizeChange] loaded in
            guard image.aspect == nil, loaded.size.width > 0, loaded.size.height > 0 else {
                return
            }
            ratio.isActive = false
            ratio = PWInlineRenderer.aspectConstraint(view, loaded.size.width / loaded.size.height)
            ratio.isActive = true
            onSizeChange()
        }
        return view
    }

    /// Width-to-height ratios a banner may ask for; the parser drops a banner outside it.
    static let aspectRange: ClosedRange<CGFloat> = 0.1...20

    static func aspectConstraint(_ view: UIView, _ aspect: CGFloat) -> NSLayoutConstraint {
        let ratio = aspect.isFinite ? min(max(aspect, aspectRange.lowerBound), aspectRange.upperBound) : 2
        let constraint = view.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1 / ratio)
        constraint.priority = UILayoutPriority(999)
        return constraint
    }

    /// Follows Dynamic Type up to 1.6 times the banner's size.
    private func scaledFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: weight),
                                                      maximumPointSize: size * 1.6)
    }

    private func button(_ button: PWInlineButton, insets: UIEdgeInsets, action: (() -> Void)?) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = button.title
        configuration.baseForegroundColor = button.color ?? .label
        configuration.contentInsets = NSDirectionalEdgeInsets(top: insets.top, leading: insets.left,
                                                              bottom: insets.bottom, trailing: insets.right)
        let font = scaledFont(size: button.size, weight: button.weight)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            return attributes
        }
        let view = UIButton(configuration: configuration, primaryAction: UIAction { _ in action?() })
        view.setContentHuggingPriority(UILayoutPriority(999), for: .horizontal)
        view.setContentCompressionResistancePriority(UILayoutPriority(760), for: .horizontal)
        return view
    }

    private func stack(_ stack: PWInlineStack) -> UIStackView {
        let axis: NSLayoutConstraint.Axis = stack.layout == .row ? .horizontal : .vertical
        let view = UIStackView(arrangedSubviews: stack.children.map { makeView($0, parentAxis: axis) })
        view.axis = axis
        view.spacing = stack.spacing
        view.alignment = stack.alignment
        view.distribution = stack.distribution
        return view
    }

    /// Children drawn on top of each other. The first one sizes the overlay; the others take the
    /// whole area (`fill`) or sit at their `position`, `spacing` points in from the edges.
    private func overlay(_ stack: PWInlineStack) -> UIView {
        let container = UIView()
        let inset = stack.spacing
        for (index, child) in stack.children.enumerated() {
            let view = makeView(child, parentAxis: .vertical)
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            let position = index == 0 ? .fill : child.position
            let edge = position == .fill ? 0 : inset
            let constraints: [NSLayoutConstraint]
            let left = view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: edge)
            let right = container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: edge)
            let top = view.topAnchor.constraint(equalTo: container.topAnchor, constant: edge)
            let bottom = container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: edge)
            let centerX = view.centerXAnchor.constraint(equalTo: container.centerXAnchor)
            let centerY = view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            let fitsWidth = view.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: inset)
            let fitsTrailing = container.trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor, constant: inset)
            let fitsTop = view.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: inset)
            let fitsBottom = container.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor, constant: inset)
            switch position {
            case .fill:
                constraints = [left, right, top, bottom]
            case .top:
                constraints = [left, right, top, fitsBottom]
            case .bottom:
                constraints = [left, right, bottom, fitsTop]
            case .center:
                constraints = [centerX, centerY, fitsWidth, fitsTrailing, fitsTop, fitsBottom]
            case .topLeft:
                constraints = [left, top, fitsTrailing, fitsBottom]
            case .topRight:
                constraints = [right, top, fitsWidth, fitsBottom]
            case .bottomLeft:
                constraints = [left, bottom, fitsTrailing, fitsTop]
            case .bottomRight:
                constraints = [right, bottom, fitsWidth, fitsTop]
            }
            constraints.filter { $0.relation != .equal }.forEach { $0.priority = UILayoutPriority(999) }
            NSLayoutConstraint.activate(constraints)
        }
        return container
    }

    private func spacer(_ size: CGFloat?, _ axis: NSLayoutConstraint.Axis) -> UIView {
        let view = UIView()
        if let size = size {
            let length = axis == .vertical ? view.heightAnchor : view.widthAnchor
            length.constraint(equalToConstant: size).isActive = true
        } else {
            view.setContentHuggingPriority(UILayoutPriority(1), for: axis)
            view.setContentCompressionResistancePriority(UILayoutPriority(1), for: axis)
        }
        return view
    }

    private func divider(_ divider: PWInlineDivider, _ axis: NSLayoutConstraint.Axis) -> UIView {
        let view = UIView()
        view.backgroundColor = divider.color ?? .separator
        let thickness = axis == .vertical ? view.heightAnchor : view.widthAnchor
        thickness.constraint(equalToConstant: divider.thickness).isActive = true
        return view
    }
}
#endif
