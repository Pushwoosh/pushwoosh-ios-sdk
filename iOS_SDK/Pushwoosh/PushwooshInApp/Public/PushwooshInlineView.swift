//
//  PushwooshInlineView.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import PushwooshCore

/// Inline banner slot. Place it anywhere in a UIKit layout and give it a slot id: it stays at zero
/// height until the slot gets a banner (`Pushwoosh.inline.requestSlots(_:completion:)`), then expands to
/// the banner's height with a spring animation, so Auto Layout and stack-view neighbours move aside on
/// their own. An empty answer for the slot collapses it back. Received banners are kept on disk and shown
/// again after relaunch. A banner past its `expireDate` is not shown; the close button collapses the slot
/// and the closed banner does not come back before its `expireDate`. A banner counts as shown once at
/// least half of its height stays on screen for 0.3 s; a control-group slot stays empty and counts the
/// same way by its position.
///
/// ```swift
/// let slot = PushwooshInlineView(slotId: "home_top")
/// stackView.addArrangedSubview(slot)
/// Pushwoosh.inline.requestSlots(["home_top"]) { error in }
/// ```
///
/// In a storyboard set the custom class to `PushwooshInlineView` (module `PushwooshInApp`) and
/// fill **Slot Id** in the Attributes inspector.
@objc(PushwooshInlineView)
public final class PushwooshInlineView: UIView {

    /// The slot this view shows. Assigning another id rebinds the view.
    @IBInspectable @objc public var slotId: String = "" {
        didSet {
            if slotId != oldValue {
                bind()
            }
        }
    }

    /// Height the banner needs at the current width (0 = empty); for hosts that size the slot by frame
    /// (SwiftUI, cross-platform views).
    @objc public var onHeightChange: ((CGFloat) -> Void)?

    private let manager: PWInlineManager
    private var subscription: PWInlineSubscription?
    private static let visibleShare: CGFloat = 0.5
    private static let showDelay: TimeInterval = 0.3
    /// Besides on every scroll and layout, the slot is checked every 0.3 s while its banner is off screen
    /// and every 0.1 s while the 0.3 s on screen are counted.
    private static let idleCheckInterval: TimeInterval = 0.3
    private static let visibleCheckInterval: TimeInterval = 0.1

    private var shownBanner: PWInlineBanner?
    private var visibilityTimer: Timer?
    /// Runs out once the banner has been on screen for 0.3 s.
    private var showTimer: Timer?
    private var scrollObservations: [NSKeyValueObservation] = []
    private var content: UIView?
    /// The html document of the shown banner, which counts only once it has drawn.
    private weak var document: PWInlineHTMLBannerView?
    private var contentBottom: NSLayoutConstraint?
    private var reportedHeight: CGFloat = 0
    private var lastWidth: CGFloat = 0
    /// Clips the banner vertically while it expands and collapses, leaving room on the sides for its shadow.
    private let clip = UIView()
    private lazy var maxHeight = heightAnchor.constraint(lessThanOrEqualToConstant: 0)
    private lazy var collapse: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = UILayoutPriority(999)
        return constraint
    }()

    @objc public convenience init(slotId: String) {
        self.init(slotId: slotId, manager: .shared)
    }

    init(slotId: String, manager: PWInlineManager) {
        self.manager = manager
        super.init(frame: .zero)
        setUp()
        self.slotId = slotId
        bind()
    }

    public override init(frame: CGRect) {
        manager = .shared
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        manager = .shared
        super.init(coder: coder)
        setUp()
    }

    deinit {
        visibilityTimer?.invalidate()
        showTimer?.invalidate()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        clip.frame = bounds.insetBy(dx: -32, dy: 0)
        if bounds.width != lastWidth {
            lastWidth = bounds.width
            reportHeight()
        }
        if visibilityTimer != nil {
            checkVisibility()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            contentSizeChanged()
        }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyColorScheme()
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        applyColorScheme()
        reportOnScreen()
        trackVisibility()
    }

    private func setUp() {
        clip.backgroundColor = .black
        mask = clip
        collapse.isActive = true
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorScheme),
                                               name: PWInlineManager.colorSchemeDidChange, object: manager)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func applicationDidBecomeActive() {
        applyColorScheme()
        trackVisibility()
    }

    @objc private func applicationDidEnterBackground() {
        stopTrackingVisibility()
    }

    /// `.app` leaves the banner on the slot's own traits (its window and view controller).
    private var bannerInterfaceStyle: UIUserInterfaceStyle {
        let screen = window?.windowScene?.screen ?? UIScreen.main
        return manager.colorScheme.interfaceStyle(system: screen.traitCollection.userInterfaceStyle)
    }

    @objc private func applyColorScheme() {
        content?.overrideUserInterfaceStyle = bannerInterfaceStyle
    }

    private func bind() {
        subscription?.cancel()
        subscription = nil
        guard !slotId.isEmpty else {
            refresh()
            return
        }
        subscription = manager.store.subscribe(slotId) { [weak self] _ in
            self?.refresh()
        }
        reportOnScreen()
    }

    private func reportOnScreen() {
        if window != nil, !slotId.isEmpty {
            manager.slotDidAppear(slotId)
        }
    }

    // MARK: - Content

    private func refresh() {
        let banner = slotId.isEmpty ? nil : manager.store.banner(for: slotId)
        guard !PWInlineStore.isSame(banner, shownBanner) else {
            return
        }
        show(banner)
        trackVisibility()
    }

    private func show(_ banner: PWInlineBanner?) {
        let old = content
        let oldBottom = contentBottom
        shownBanner = banner
        stopTrackingVisibility()
        guard banner != nil || old != nil else {
            return
        }
        let animated = window != nil && !UIAccessibility.isReduceMotionEnabled
        let new = banner.flatMap { $0.isControl ? nil : install($0) }
        content = new
        document = new.flatMap { Self.document(in: $0) }
        contentBottom = new.map { $0.bottomAnchor.constraint(equalTo: bottomAnchor) }
        contentBottom?.priority = UILayoutPriority(998)

        if animated, let new = new {
            new.alpha = 0
            new.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            UIView.performWithoutAnimation { window?.layoutIfNeeded() }
        }
        if new != nil {
            oldBottom?.isActive = false
        }
        contentBottom?.isActive = true
        collapse.isActive = new == nil
        maxHeight.constant = banner?.maxHeight ?? 0
        maxHeight.isActive = banner?.maxHeight != nil
        reportHeight()

        animate(animated, {
            new?.alpha = 1
            new?.transform = .identity
            old?.alpha = 0
            old?.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: {
            old?.removeFromSuperview()
        })
    }

    private func install(_ banner: PWInlineBanner) -> UIView {
        var renderer = PWInlineRenderer(onSizeChange: { [weak self] in
            DispatchQueue.main.async { self?.contentSizeChanged() }
        }, onAction: { [weak self] action, nodeId in
            self?.perform(action, nodeId: nodeId, from: banner)
        }, canPostEvent: { [weak self] in
            self?.manager.canPostBannerEvent ?? false
        })
        renderer.onElementTap = { [weak self] elementId in
            self?.manager.didClick(banner, elementId: elementId)
        }
        let view = renderer.makeView(banner)
        view.overrideUserInterfaceStyle = bannerInterfaceStyle
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        return view
    }

    private static func document(in view: UIView) -> PWInlineHTMLBannerView? {
        view as? PWInlineHTMLBannerView ?? view.subviews.lazy.compactMap { document(in: $0) }.first
    }

    private func perform(_ action: PWInlineAction, nodeId: String?, from banner: PWInlineBanner) {
        let report = { (type: String, value: String) in
            self.log("Inline banner '\(banner.bannerId)' node '\(nodeId ?? "banner")' clicked: \(type) \(value)")
            self.manager.didClick(banner, elementId: nodeId)
        }
        switch action {
        case .url(let url):
            report("url", url.absoluteString)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .deeplink(let url):
            report("deeplink", url.absoluteString)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .postEvent(let name, let attributes):
            report("postEvent", name)
            manager.postBannerEvent(name, attributes: attributes)
        case .copy(let text, let toast):
            report("copy", text)
            UIPasteboard.general.string = text
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if let window = window {
                PWInlineToast.show(toast ?? "Copied", in: window)
            }
        case .close:
            manager.dismiss(slotId: banner.slotId, bannerId: banner.bannerId)
        }
    }

    // MARK: - Visibility

    private func trackVisibility() {
        guard let banner = shownBanner, window != nil, !manager.store.isReported(banner) else {
            stopTrackingVisibility()
            return
        }
        if visibilityTimer == nil {
            checkVisibility(every: Self.idleCheckInterval)
            observeScrolling()
        }
        checkVisibility()
    }

    private func checkVisibility(every interval: TimeInterval) {
        visibilityTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.checkVisibility()
        }
        RunLoop.main.add(timer, forMode: .common)
        visibilityTimer = timer
    }

    private func observeScrolling() {
        scrollObservations = sequence(first: self as UIView, next: { $0.superview }).compactMap { $0 as? UIScrollView }
            .map { $0.observe(\.contentOffset) { [weak self] _, _ in self?.checkVisibility() } }
    }

    private func stopTrackingVisibility() {
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        showTimer?.invalidate()
        showTimer = nil
        scrollObservations = []
    }

    /// Starts counting the 0.3 s once at least half of the banner is on screen and stops once it is not.
    private func checkVisibility() {
        guard let banner = shownBanner, window != nil, !manager.store.isReported(banner) else {
            stopTrackingVisibility()
            return
        }
        let onScreen = isOnScreen(banner)
        if onScreen, showTimer == nil {
            let timer = Timer(timeInterval: Self.showDelay, repeats: false) { [weak self] _ in
                self?.showDelayPassed()
            }
            RunLoop.main.add(timer, forMode: .common)
            showTimer = timer
            checkVisibility(every: Self.visibleCheckInterval)
        } else if !onScreen, showTimer != nil {
            showTimer?.invalidate()
            showTimer = nil
            checkVisibility(every: Self.idleCheckInterval)
        }
    }

    private func showDelayPassed() {
        showTimer = nil
        guard let banner = shownBanner, window != nil, !manager.store.isReported(banner), isOnScreen(banner) else {
            checkVisibility(every: Self.idleCheckInterval)
            checkVisibility()
            return
        }
        stopTrackingVisibility()
        manager.bannerDidBecomeVisible(banner)
    }

    private func isOnScreen(_ banner: PWInlineBanner) -> Bool {
        document?.isContentReady != false && isInActiveScene && isFrontmost && isVisibleEnough(banner)
    }

    private var isInActiveScene: Bool {
        window?.windowScene.map { $0.activationState == .foregroundActive } ?? true
    }

    /// No other window of the scene is in front, and nothing is presented over the slot's screen.
    private var isFrontmost: Bool {
        guard let window = window else {
            return false
        }
        if let keyWindow = window.windowScene?.keyWindow, keyWindow !== window {
            return false
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        guard let screen = top, screen !== window.rootViewController, screen.isViewLoaded else {
            return true
        }
        return isDescendant(of: screen.view)
    }

    private func isVisibleEnough(_ banner: PWInlineBanner) -> Bool {
        banner.isControl ? visibleRect(of: self) != nil : visibleFraction(of: self) >= Self.visibleShare
    }

    private func contentSizeChanged() {
        reportHeight()
        animate(window != nil && !UIAccessibility.isReduceMotionEnabled, {}, completion: {})
    }

    private func animate(_ animated: Bool, _ changes: @escaping () -> Void, completion: @escaping () -> Void) {
        guard animated, let window = window else {
            changes()
            completion()
            return
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            changes()
            window.layoutIfNeeded()
        }, completion: { _ in
            completion()
        })
    }

    // MARK: - Height

    private func reportHeight() {
        let height = fittingHeight()
        guard height != reportedHeight else {
            return
        }
        reportedHeight = height
        onHeightChange?(height)
    }

    private func fittingHeight() -> CGFloat {
        guard let content = content, bounds.width > 0 else {
            return 0
        }
        let target = CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = content.systemLayoutSizeFitting(target, withHorizontalFittingPriority: .required,
                                                     verticalFittingPriority: .fittingSizeLevel).height.rounded(.up)
        return min(height, shownBanner?.maxHeight ?? height)
    }

    private func log(_ message: String) {
        PushwooshLog.pushwooshLog(.PW_LL_INFO, className: "PushwooshInlineView", message: message)
    }
}
#endif
