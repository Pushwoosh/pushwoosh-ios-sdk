//  InboxTabBarView.swift
//  Created by André Kis

#if canImport(UIKit) && !os(watchOS)
import UIKit
import PushwooshCore

/// Horizontally scrolling strip of tab buttons above the inbox feed: "All" first, then every tab
/// of the ``PWInboxTabs`` list in server order, so long titles stay whole and a longer list scrolls.
final class InboxTabBarView: UIView {

    /// Fires with the tapped tab's identifier, `nil` for "All".
    var onSelect: ((String?) -> Void)?

    /// Rendered button titles, "All" first, without the unread-count suffix.
    private(set) var buttonTitles: [String] = []

    /// The buttons backing `buttonTitles`, in the same order. Internal so both this view's own
    /// styling code and the test target (`@testable import`) can reach them.
    private(set) var buttons: [UIButton] = []

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let indicator = UIVisualEffectView(effect: nil)
    private let indicatorHeight: CGFloat = 2
    private lazy var indicatorBottom = indicator.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor)
    private var glassView: UIVisualEffectView?

    /// `nil` at index 0 for "All", a tab identifier at every later index — parallel to `buttons`.
    private var tabIds: [String?] = []
    private var selectedIndex: Int = 0
    private var style: PushwooshInboxKitAttributes.Style?
    private var indicatorLeading: NSLayoutConstraint?
    private var indicatorWidth: NSLayoutConstraint?

    /// The installed glass effect, `nil` on a flat fill — test-only window matching `buttonTitles`.
    var effectForTesting: UIVisualEffect? { glassView?.effect }

    /// The underline under the selected tab — test-only window matching `effectForTesting`.
    var selectionIndicatorForTesting: UIView { indicator }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        host(scrollView, in: self)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 20
        scrollView.addSubview(stack)

        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        // Lives in the scrolling content, so it travels with the title it underlines.
        scrollView.addSubview(indicator)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),

            indicator.heightAnchor.constraint(equalToConstant: indicatorHeight),
            indicatorBottom,

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    /// Rebuilds the strip's buttons from `tabs`, always; callers skip an unchanged list
    /// (`PWInboxTabs.isEqual:` compares all fields and order).
    func configure(tabs: PWInboxTabs, selectedTabId: String?, style: PushwooshInboxKitAttributes.Style) {
        self.style = style
        applyGlass(style: style)

        buttons.forEach { $0.removeFromSuperview() }

        tabIds = [nil] + tabs.tabs.map { $0.identifier }
        buttonTitles = [tabs.allTitle] + tabs.tabs.map { $0.title }
        buttons = buttonTitles.enumerated().map { index, title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.tag = index
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            return button
        }

        selectedIndex = tabIds.firstIndex(of: selectedTabId) ?? 0
        applySelectionStyle()
    }

    /// Updates the number beside each tab's title, hidden at zero. `counts` is keyed the same way
    /// `InboxDataSource.unreadCount(forTabId:)` is — `nil` for "All".
    func updateUnreadCounts(_ counts: [String?: Int]) {
        for (index, tabId) in tabIds.enumerated() where buttons.indices.contains(index) {
            let count = counts[tabId] ?? 0
            let title = buttonTitles[index]
            buttons[index].setTitle(count > 0 ? "\(title) \(count)" : title, for: .normal)
        }
    }

    @objc private func handleTap(_ sender: UIButton) {
        guard tabIds.indices.contains(sender.tag) else { return }
        selectedIndex = sender.tag
        applySelectionStyle()
        onSelect?(tabIds[selectedIndex])
    }

    /// Routes straight to `handleTap` like a real touch-up-inside: in the host-less test bundle
    /// `UIControl.sendActions` never reaches a registered target.
    func simulateTap(atIndex index: Int) {
        guard buttons.indices.contains(index) else { return }
        handleTap(buttons[index])
    }

    /// Hosts the stack in a `UIGlassContainerEffect` with an accent-tinted glass indicator when `style.isLiquidGlass`
    /// is on under iOS 26+ (Xcode 26+ toolchain), else keeps the flat `style.backgroundColor` and accent fills.
    private func applyGlass(style: PushwooshInboxKitAttributes.Style) {
        var effect: UIVisualEffect?
        var indicatorEffect: UIVisualEffect?
#if compiler(>=6.2)
        if style.isLiquidGlass, #available(iOS 26.0, *) {
            effect = pwInboxGlassContainerEffect(spacing: 8)
            indicatorEffect = pwInboxTintedGlassEffect(tint: style.unreadBadgeColor)
        }
#endif
        indicator.effect = indicatorEffect
        indicator.backgroundColor = indicatorEffect == nil ? style.unreadBadgeColor : .clear
        // Glass draws a soft edge past its frame, which the strip's bottom edge would clip.
        indicatorBottom.constant = indicatorEffect == nil ? 0 : -4
        guard let effect = effect else {
            glassView?.removeFromSuperview()
            glassView = nil
            backgroundColor = style.backgroundColor
            host(scrollView, in: self)
            return
        }
        backgroundColor = .clear
        if let existing = glassView {
            existing.effect = effect
        } else {
            let view = UIVisualEffectView(effect: effect)
            view.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(view, at: 0)
            // A glass container renders nothing by itself, only the glass elements placed in it.
            let background = UIVisualEffectView(effect: pwInboxGlassEffect())
            background.translatesAutoresizingMaskIntoConstraints = false
            view.contentView.addSubview(background)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                background.topAnchor.constraint(equalTo: view.contentView.topAnchor),
                background.leadingAnchor.constraint(equalTo: view.contentView.leadingAnchor),
                background.trailingAnchor.constraint(equalTo: view.contentView.trailingAnchor),
                background.bottomAnchor.constraint(equalTo: view.contentView.bottomAnchor)
            ])
            glassView = view
            host(scrollView, in: view.contentView)
        }
    }

    private func host(_ content: UIView, in container: UIView) {
        guard content.superview !== container else { return }
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func applySelectionStyle() {
        guard let style = style else { return }
        for (index, button) in buttons.enumerated() {
            button.titleLabel?.font = style.titleFont
            button.setTitleColor(index == selectedIndex ? style.unreadBadgeColor : style.titleColorRead, for: .normal)
        }
        pinIndicatorToSelectedButton()
    }

    private func pinIndicatorToSelectedButton() {
        indicatorLeading?.isActive = false
        indicatorWidth?.isActive = false
        indicatorLeading = nil
        indicatorWidth = nil

        guard buttons.indices.contains(selectedIndex) else {
            indicator.isHidden = true
            return
        }
        indicator.isHidden = false

        let button = buttons[selectedIndex]
        let leading = indicator.leadingAnchor.constraint(equalTo: button.leadingAnchor)
        let width = indicator.widthAnchor.constraint(equalTo: button.widthAnchor)
        NSLayoutConstraint.activate([leading, width])
        indicatorLeading = leading
        indicatorWidth = width
    }
}
#endif
