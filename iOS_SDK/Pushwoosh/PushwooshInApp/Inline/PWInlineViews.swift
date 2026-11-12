//
//  PWInlineViews.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import WebKit
import PushwooshCore

/// Draws a node's style around its content: background color, gradient, background image, glass,
/// border, rounded corners and shadow, switching to the dark style with the theme. Carries the tap
/// action of a non-button node: the innermost node with an action takes the tap, shrinks while
/// pressed (dims instead under Reduce Motion) and is a button for VoiceOver.
final class PWInlineBoxView: UIView, UIGestureRecognizerDelegate {

    var onTap: (() -> Void)? {
        didSet {
            guard onTap != nil, oldValue == nil else {
                return
            }
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
            recognizer.delegate = self
            addGestureRecognizer(recognizer)
            accessibilityTraits = .button
            let texts = Self.texts(in: self)
            accessibilityLabel = texts.isEmpty ? nil : texts.joined(separator: ", ")
            isAccessibilityElement = !Self.hasNestedActions(in: self)
        }
    }

    private let lightStyle: PWInlineStyle
    private let darkStyle: PWInlineStyle?
    private let surface = UIView()
    private let gradientView = PWInlineGradientView()
    private let imageView = UIImageView()
    private let effectView = UIVisualEffectView(effect: nil)
    private var imageURL: URL?

    private var style: PWInlineStyle {
        traitCollection.userInterfaceStyle == .dark ? darkStyle ?? lightStyle : lightStyle
    }

    init(content: UIView, style: PWInlineStyle, darkStyle: PWInlineStyle?, padding: UIEdgeInsets) {
        lightStyle = style
        self.darkStyle = darkStyle
        super.init(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            imageView.setContentCompressionResistancePriority(UILayoutPriority(1), for: axis)
            imageView.setContentHuggingPriority(UILayoutPriority(1), for: axis)
        }
        for view in [surface, gradientView, imageView, effectView, content] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        addSubview(surface)
        pin(surface, to: self, insets: .zero)
        for layer in [gradientView, imageView, effectView] {
            surface.addSubview(layer)
            pin(layer, to: surface, insets: .zero)
        }
        surface.addSubview(content)
        pin(content, to: surface, insets: padding)
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if style.shadow != nil {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: style.cornerRadius).cgPath
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyStyle()
        }
    }

    /// Mirrors a button's press on the whole box (the button draws only its title).
    func pressFeedback(from button: UIButton) {
        button.addAction(UIAction { [weak self] _ in self?.setPressed(true) }, for: [.touchDown, .touchDragEnter])
        button.addAction(UIAction { [weak self] _ in self?.setPressed(false) },
                         for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard onTap != nil, let touch = touches.first, ownsTouch(touch) else {
            return super.touchesBegan(touches, with: event)
        }
        setPressed(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard onTap != nil, let touch = touches.first, ownsTouch(touch) else {
            return super.touchesEnded(touches, with: event)
        }
        setPressed(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard onTap != nil, let touch = touches.first, ownsTouch(touch) else {
            return super.touchesCancelled(touches, with: event)
        }
        setPressed(false)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        ownsTouch(touch)
    }

    override func accessibilityActivate() -> Bool {
        onTap?()
        return onTap != nil
    }

    @objc private func tapped() {
        onTap?()
    }

    /// False when the touch lands on a control or a nested node with its own action.
    private func ownsTouch(_ touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view, current !== self {
            if current is UIControl || (current as? PWInlineBoxView)?.onTap != nil {
                return false
            }
            view = current.superview
        }
        return true
    }

    private static func hasNestedActions(in view: UIView) -> Bool {
        view.subviews.contains { $0 is UIControl || ($0 as? PWInlineBoxView)?.onTap != nil || hasNestedActions(in: $0) }
    }

    private static func texts(in view: UIView) -> [String] {
        if let label = view as? UILabel {
            return label.text.map { [$0] } ?? []
        }
        return view.subviews.flatMap { texts(in: $0) }
    }

    private func setPressed(_ pressed: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            alpha = pressed ? 0.7 : 1
            return
        }
        UIView.animate(withDuration: pressed ? 0.12 : 0.35, delay: 0, usingSpringWithDamping: pressed ? 1 : 0.6,
                       initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
    }

    private func applyStyle() {
        let style = self.style
        surface.backgroundColor = style.background
        surface.layer.cornerRadius = style.cornerRadius
        surface.layer.cornerCurve = .continuous
        surface.clipsToBounds = style.cornerRadius > 0
        surface.layer.borderWidth = style.border?.width ?? 0
        surface.layer.borderColor = style.border?.color.resolvedColor(with: traitCollection).cgColor

        gradientView.isHidden = style.gradient == nil
        if let gradient = style.gradient {
            gradientView.apply(gradient, traitCollection: traitCollection)
        }

        imageView.isHidden = style.backgroundImage == nil
        if style.backgroundImage != imageURL {
            imageURL = style.backgroundImage
            PWInAppImageLoader.shared.load(style.backgroundImage, into: imageView)
        }

        effectView.isHidden = style.glass == nil
        effectView.effect = style.glass.map { PWInAppStyle.glassEffect(tint: $0.tint, fallback: .systemUltraThinMaterial) }
        effectView.contentView.backgroundColor = nil
        if let glass = style.glass, !PWInAppStyle.hasLiquidGlass {
            effectView.contentView.backgroundColor = glass.tint?.withAlphaComponent(0.25)
        }

        if let shadow = style.shadow {
            layer.shadowColor = shadow.color.resolvedColor(with: traitCollection).cgColor
            layer.shadowOpacity = 1
            layer.shadowRadius = shadow.radius
            layer.shadowOffset = shadow.offset
        } else {
            layer.shadowOpacity = 0
            layer.shadowPath = nil
        }
        setNeedsLayout()
    }
}

private final class PWInlineGradientView: UIView {

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    func apply(_ gradient: PWInlineGradient, traitCollection: UITraitCollection) {
        guard let layer = layer as? CAGradientLayer else {
            return
        }
        let radians = gradient.angle * .pi / 180
        let dx = cos(radians) / 2
        let dy = sin(radians) / 2
        layer.colors = gradient.colors.map { $0.resolvedColor(with: traitCollection).cgColor }
        layer.startPoint = CGPoint(x: 0.5 - dx, y: 0.5 - dy)
        layer.endPoint = CGPoint(x: 0.5 + dx, y: 0.5 + dy)
    }
}

/// An html banner: the document drawn by the Rich Media web view, loaded once the slot gives it a width.
/// The document is laid out in a viewport as tall as the screen's long side, so `%` and `vh` heights
/// resolve to a fixed size, and the banner shows its top part as tall as the document, up to that viewport.
/// Until the document reports its height the banner is a 1 pt placeholder and not ready to count as shown.
/// A tap outside links, controls and `data-pw-id` elements runs `onTap`.
/// A tap on an unmarked control is a click without element id, reported 1 s after the control's click
/// unless the page closes the banner meanwhile: then the control is the close button and the close is
/// only the dismiss. A control running `registerForPushNotifications()` or `openAppSettings()`, which
/// close the banner on their own, is a click and then the dismiss.
final class PWInlineHTMLBannerView: UIView, UIGestureRecognizerDelegate {

    var onTap: (() -> Void)?
    var onElementTap: ((String?) -> Void)?

    static let ownClickDelay: TimeInterval = 1

    private static let ownActionSelector =
        "a[href],button,input,select,textarea,label,[onclick],[role=button],[data-pw-id]"

    static var viewportHeight: CGFloat {
        max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    }

    static let heightMessage = "pushwooshInlineHeight"

    /// Runs in the native client's JS world, out of reach of the page's scripts. The height is the document's
    /// in-flow height (the root's in standards mode; in quirks mode, where the root fills the viewport, the
    /// lowest child of the body plus its bottom spacing), or the bottom of a lower absolute or fixed box.
    static let heightScript = """
        (function() {
            var root = document.documentElement, reported = -1;
            function bottomOf(rect, bottom) {
                return rect.width || rect.height ? Math.max(bottom, rect.bottom) : bottom;
            }
            function quirksBottom(body) {
                var range = document.createRange(), bottom = 0;
                for (var i = 0; i < body.childNodes.length; i++) {
                    var node = body.childNodes[i];
                    if (node.nodeType === 1) {
                        bottom = bottomOf(node.getBoundingClientRect(), bottom);
                    } else if (node.nodeType === 3) {
                        range.selectNode(node);
                        bottom = bottomOf(range.getBoundingClientRect(), bottom);
                    }
                }
                if (!bottom) return 0;
                var style = getComputedStyle(body);
                return bottom + parseFloat(style.paddingBottom) + parseFloat(style.borderBottomWidth) +
                    parseFloat(style.marginBottom);
            }
            function positionedBottom(body) {
                var bottom = 0, nodes = body.getElementsByTagName('*');
                for (var i = 0; i < nodes.length; i++) {
                    var position = getComputedStyle(nodes[i]).position;
                    if (position === 'absolute' || position === 'fixed') {
                        bottom = bottomOf(nodes[i].getBoundingClientRect(), bottom);
                    }
                }
                return bottom;
            }
            function report() {
                var body = document.body, height = 0;
                if (document.compatMode === 'CSS1Compat') {
                    height = root.getBoundingClientRect().height;
                } else if (body) {
                    height = quirksBottom(body);
                }
                if (body) height = Math.max(height, positionedBottom(body));
                height = Math.ceil(height + window.scrollY);
                if (height !== reported) {
                    reported = height;
                    window.webkit.messageHandlers.\(heightMessage).postMessage(height);
                }
            }
            var resizes = new ResizeObserver(report);
            function observe() {
                resizes.observe(root);
                var nodes = root.getElementsByTagName('*');
                for (var i = 0; i < nodes.length; i++) resizes.observe(nodes[i]);
            }
            new MutationObserver(function() { observe(); report(); })
                .observe(root, { childList: true, subtree: true });
            window.addEventListener('load', report);
            observe();
            report();
        })();
        """

    /// The document has reported its height: the banner shows it and may count as shown.
    private(set) var isContentReady = false

    private let html: String
    private let onClose: () -> Void
    private let onSizeChange: () -> Void
    private let canPostEvent: () -> Bool
    private let content = PWInlineHTMLView(frame: .zero)
    private let heightHandler = PWInlineHTMLHeightHandler()
    private lazy var height: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 1)
        constraint.priority = UILayoutPriority(999)
        return constraint
    }()
    private var isLoaded = false
    /// A tap waits for the hit test of the page.
    private var tapPending = false
    private var closeRequested = false
    private var closingActionRan = false
    private var pendingClick: DispatchWorkItem?

    init(html: String, onClose: @escaping () -> Void, onSizeChange: @escaping () -> Void,
         canPostEvent: @escaping () -> Bool) {
        self.html = html
        self.onClose = onClose
        self.onSizeChange = onSizeChange
        self.canPostEvent = canPostEvent
        super.init(frame: .zero)
        clipsToBounds = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: content.trailingAnchor),
            content.heightAnchor.constraint(equalToConstant: Self.viewportHeight),
            height,
        ])
        heightHandler.onHeight = { [weak self] documentHeight in
            self?.documentHeightChanged(documentHeight)
        }
        let scripts = content.webView.configuration.userContentController
        scripts.addUserScript(WKUserScript(source: Self.heightScript, injectionTime: .atDocumentEnd,
                                           forMainFrameOnly: true, in: .defaultClient))
        scripts.add(heightHandler, contentWorld: .defaultClient, name: Self.heightMessage)
        content.closeInApp = { [weak self] in
            self?.close()
        }
        content.closingActionDidRun = { [weak self] in
            self?.closingActionDidRun()
        }
        content.shouldPostEvent = { [weak self] in
            self?.canPostEvent() ?? false
        }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        recognizer.delegate = self
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesEnded = false
        content.webView.addGestureRecognizer(recognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, !isLoaded else {
            return
        }
        isLoaded = true
        content.loadHTMLString(html)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            reportPendingClick()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    /// The document's own height, measured in the fixed viewport, so the banner's height has no effect on it.
    func documentHeightChanged(_ documentHeight: CGFloat) {
        guard documentHeight.isFinite, documentHeight > 0 else {
            return
        }
        let visibleHeight = min(ceil(documentHeight), Self.viewportHeight)
        guard !isContentReady || visibleHeight != height.constant else {
            return
        }
        isContentReady = true
        height.constant = visibleHeight
        onSizeChange()
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        handleTap(at: recognizer.location(in: content.webView))
    }

    /// The hit test runs in its own JS world, out of reach of the page's scripts; for an unmarked control
    /// it answers once the control's click has run.
    func handleTap(at point: CGPoint) {
        guard onTap != nil || onElementTap != nil else {
            return
        }
        beginTap()
        let script = """
            var e = document.elementFromPoint(x, y);
            if (!e || !e.closest(selector)) return '';
            var marked = e.closest('[data-pw-id]');
            if (marked) return 'id:' + marked.getAttribute('data-pw-id');
            return new Promise(function(done) {
                var timer;
                function finish() {
                    clearTimeout(timer);
                    window.removeEventListener('click', clicked, true);
                    done('own');
                }
                function clicked() { setTimeout(finish, 0); }
                window.addEventListener('click', clicked, true);
                timer = setTimeout(finish, 1000);
            });
            """
        content.webView.callAsyncJavaScript(script, arguments: ["x": point.x, "y": point.y,
                                                                "selector": Self.ownActionSelector],
                                            in: nil, in: .defaultClient) { [weak self] result in
            guard case .success(let hit as String) = result else {
                self?.handleHit(nil)
                return
            }
            self?.handleHit(hit)
        }
    }

    /// A tap on the document began; a click held back from the previous tap is reported now.
    func beginTap() {
        reportPendingClick()
        tapPending = true
        closeRequested = false
        closingActionRan = false
    }

    /// Empty = the banner itself, `id:<data-pw-id>` = a marked element, `own` = an unmarked element with
    /// its own action, `nil` = the page did not answer.
    func handleHit(_ hit: String?) {
        guard tapPending else {
            return
        }
        tapPending = false
        let elementId = hit.flatMap { $0.hasPrefix("id:") && $0.count > 3 ? String($0.dropFirst(3)) : nil }
        if closeRequested {
            closeRequested = false
            if elementId != nil || closingActionRan {
                onElementTap?(elementId)
            }
            onClose()
            return
        }
        switch hit {
        case nil:
            break
        case "":
            onTap?()
        case "own":
            let click = DispatchWorkItem { [weak self] in
                self?.reportPendingClick()
            }
            pendingClick = click
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.ownClickDelay, execute: click)
        default:
            onElementTap?(elementId)
        }
    }

    /// `pushwoosh.closeInApp()`; during a tap it waits for the hit test to tell what was tapped.
    private func close() {
        if let click = pendingClick {
            click.cancel()
            pendingClick = nil
            if closingActionRan {
                onElementTap?(nil)
            }
            onClose()
        } else if tapPending {
            closeRequested = true
        } else {
            onClose()
        }
    }

    private func closingActionDidRun() {
        if tapPending || pendingClick != nil {
            closingActionRan = true
        }
    }

    private func reportPendingClick() {
        guard let click = pendingClick else {
            return
        }
        click.cancel()
        pendingClick = nil
        onElementTap?(nil)
    }
}

/// Hands the document height posted by the measuring script to its banner, which it does not retain.
private final class PWInlineHTMLHeightHandler: NSObject, WKScriptMessageHandler {

    var onHeight: ((CGFloat) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let height = message.body as? NSNumber else {
            return
        }
        onHeight?(CGFloat(height.doubleValue))
    }
}

private func pin(_ view: UIView, to container: UIView, insets: UIEdgeInsets) {
    NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top),
        view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets.left),
        container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: insets.right),
        container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: insets.bottom),
    ])
}

/// Share of the view's height inside the window and every clipping ancestor (0...1).
func visibleFraction(of view: UIView) -> CGFloat {
    guard view.bounds.height > 0, let visible = visibleRect(of: view) else {
        return 0
    }
    return visible.height / view.convert(view.bounds, to: view.window).height
}

/// The part of the view inside the window and every clipping ancestor, in window coordinates; for a
/// view without height, the line of its top edge. `nil` = off screen.
func visibleRect(of view: UIView) -> CGRect? {
    guard let window = view.window, !view.isHidden, view.bounds.width > 0 else {
        return nil
    }
    var visible = view.convert(view.bounds, to: window).intersection(window.bounds)
    var ancestor = view.superview
    while let current = ancestor, current !== window, !visible.isNull {
        if current.isHidden {
            return nil
        }
        if current.clipsToBounds {
            visible = visible.intersection(current.convert(current.bounds, to: window))
        }
        ancestor = current.superview
    }
    return visible.isNull || visible.width == 0 ? nil : visible
}

/// A banner with its close button over a top corner.
final class PWInlineClosableView: UIView {

    private static let inset: CGFloat = 8

    init(content: UIView, close: PWInlineClose, onClose: @escaping () -> Void) {
        super.init(frame: .zero)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        pin(content, to: self, insets: .zero)
        let button = PWInlineCloseButton(close: close, onClose: onClose)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor, constant: Self.inset),
            close.position == .topLeft
                ? button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset)
                : trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: Self.inset),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PWInlineCloseButton: UIButton {

    private static let touchMargin: CGFloat = 8
    private let onClose: () -> Void

    init(close: PWInlineClose, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: .zero)
        let symbol = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        tintColor = close.color
        backgroundColor = close.background
        layer.cornerRadius = min(close.cornerRadius, PWInlineClose.size / 2)
        accessibilityLabel = "Close"
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PWInlineClose.size),
            heightAnchor.constraint(equalToConstant: PWInlineClose.size),
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -Self.touchMargin, dy: -Self.touchMargin).contains(point)
    }

    @objc private func tapped() {
        onClose()
    }
}

// MARK: - Pager

/// Pages side by side with paging, a page indicator under them and optional automatic turning.
/// As tall as the tallest page; every page is as wide as the pager.
final class PWInlinePagerView: UIView, UIScrollViewDelegate {

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let pageCount: Int
    private let interval: TimeInterval?
    private var timer: Timer?

    init(pages: [UIView], pager: PWInlinePager) {
        pageCount = pages.count
        interval = pager.interval
        super.init(frame: .zero)
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView(arrangedSubviews: pages)
        row.axis = .horizontal
        row.alignment = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(row)
        addSubview(scrollView)

        let color = pager.indicatorColor ?? .label
        pageControl.numberOfPages = pages.count
        pageControl.hidesForSinglePage = true
        pageControl.currentPageIndicatorTintColor = color
        pageControl.pageIndicatorTintColor = color.withAlphaComponent(0.3)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.addAction(UIAction { [weak self] _ in self?.show(page: self?.pageControl.currentPage ?? 0) },
                              for: .valueChanged)
        addSubview(pageControl)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: content.topAnchor),
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.heightAnchor.constraint(equalTo: frame.heightAnchor),
            pageControl.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: bottomAnchor),
        ] + pages.map { $0.widthAnchor.constraint(equalTo: frame.widthAnchor) })
        if pages.count < 2 {
            pageControl.heightAnchor.constraint(equalToConstant: 0).isActive = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        window == nil ? stopTimer() : startTimer()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = scrollView.bounds.width
        if width > 0, !scrollView.isDragging, !scrollView.isDecelerating {
            scrollView.contentOffset.x = CGFloat(pageControl.currentPage) * width
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stopTimer()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        startTimer()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0, scrollView.isDragging || scrollView.isDecelerating else {
            return
        }
        pageControl.currentPage = min(max(Int((scrollView.contentOffset.x / width).rounded()), 0), pageCount - 1)
    }

    private func show(page: Int) {
        pageControl.currentPage = page
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * scrollView.bounds.width, y: 0), animated: true)
    }

    private func startTimer() {
        stopTimer()
        guard let interval = interval, pageCount > 1, window != nil, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }
            self.show(page: (self.pageControl.currentPage + 1) % self.pageCount)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Video

/// Muted looping video in its aspect ratio; plays while at least half of its height is on screen.
final class PWInlineVideoView: UIView {

    private let video: PWInlineVideo
    private var player: PWInAppVideoPlayerView?
    private var timer: Timer?

    init(_ video: PWInlineVideo) {
        self.video = video
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        PWInlineRenderer.aspectConstraint(self, video.aspect).isActive = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NotificationCenter.default.addObserver(self, selector: #selector(startPlayback),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopPlayback),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, player == nil {
            let player = PWInAppVideoPlayerView()
            player.translatesAutoresizingMaskIntoConstraints = false
            addSubview(player)
            pin(player, to: self, insets: .zero)
            player.configure(videoURL: video.url, posterURL: video.poster, fallbackImageURL: video.poster,
                             loop: true, muted: true, fill: true, managesAudioSession: false)
            self.player = player
        }
        startPlayback()
    }

    /// While the view is in a window of the running app, checks every 0.3 s whether it is on screen,
    /// scrolling included.
    @objc private func startPlayback() {
        timer?.invalidate()
        timer = nil
        guard window != nil else {
            player?.pause()
            return
        }
        updatePlayback()
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func stopPlayback() {
        timer?.invalidate()
        timer = nil
        player?.pause()
    }

    private func updatePlayback() {
        guard let player = player else {
            return
        }
        let visible = visibleFraction(of: self) >= 0.5
        if visible, !player.isPlaying {
            player.play()
        } else if !visible, player.isPlaying {
            player.pause()
        }
    }
}

// MARK: - Toast

/// A short message in a capsule near the bottom of the window, gone after a moment.
enum PWInlineToast {

    static func show(_ text: String, in window: UIWindow) {
        let toast = UIVisualEffectView(effect: PWInAppStyle.glassEffect(tint: UIColor(white: 0, alpha: 0.55)))
        toast.layer.cornerRadius = 22
        toast.layer.cornerCurve = .continuous
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.isUserInteractionEnabled = false
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        toast.contentView.addSubview(label)
        window.addSubview(toast)
        pin(label, to: toast.contentView, insets: UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20))
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 24),
            toast.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -64),
        ])
        UIAccessibility.post(notification: .announcement, argument: text)
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 16).scaledBy(x: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: [], animations: {
            toast.alpha = 1
            toast.transform = .identity
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 8)
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        })
    }
}
#endif
