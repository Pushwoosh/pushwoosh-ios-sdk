//  InboxErrorBannerView.swift
//  Created by André Kis

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Transient bottom banner for a refresh error that left content on screen, pinned above the container's safe area.
/// Auto-hides after a few seconds; user interaction is off, so a tap over it reaches the row underneath.
final class InboxErrorBannerView: UIView {

    /// The visual surface, kept apart from this view's transparent layout role so the glass surface
    /// can replace it without touching the show/hide logic.
    private let surfaceView = UIView()
    private let label = UILabel()
    private var glassView: UIVisualEffectView?

    private weak var presentingContainer: UIView?
    private var hideWorkItem: DispatchWorkItem?

    private(set) var isShowing = false
    private(set) var text: String?

    /// The installed glass effect, `nil` on a flat fill — test-only window matching `isShowing`.
    var effectForTesting: UIVisualEffect? { glassView?.effect }

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
        isUserInteractionEnabled = false
        isHidden = true
        alpha = 0

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.layer.cornerRadius = 12
        surfaceView.clipsToBounds = true
        addSubview(surfaceView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        surfaceView.addSubview(label)

        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: topAnchor),
            surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),

            label.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -16)
        ])
    }

    /// Shows `text` pinned above `container`'s safe area and hides it after `duration`; a call while
    /// showing replaces the pending auto-hide instead of stacking a second one.
    func show(text: String, style: PushwooshInboxKitAttributes.Style, in container: UIView, duration: TimeInterval) {
        if presentingContainer !== container {
            attach(to: container)
        }

        self.text = text
        label.text = text
        label.font = style.titleFont
        label.textColor = style.titleColorUnread
        applyGlass(style: style)

        hideWorkItem?.cancel()
        isHidden = false
        isShowing = true
        alpha = 1

        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// Hides immediately and cancels any pending auto-hide — called when a refresh succeeds.
    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        isHidden = true
        isShowing = false
        alpha = 0
    }

    /// Installs a `UIGlassEffect` surface behind the label when `style.isLiquidGlass` is on under iOS 26+
    /// (Xcode 26+ toolchain), else keeps the flat `style.backgroundColor` fill.
    private func applyGlass(style: PushwooshInboxKitAttributes.Style) {
        var effect: UIVisualEffect?
#if compiler(>=6.2)
        if style.isLiquidGlass, #available(iOS 26.0, *) {
            effect = pwInboxGlassEffect()
        }
#endif
        guard let effect = effect else {
            glassView?.removeFromSuperview()
            glassView = nil
            surfaceView.backgroundColor = style.backgroundColor
            return
        }
        surfaceView.backgroundColor = .clear
        if let existing = glassView {
            existing.effect = effect
        } else {
            let view = UIVisualEffectView(effect: effect)
            view.translatesAutoresizingMaskIntoConstraints = false
            surfaceView.insertSubview(view, at: 0)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: surfaceView.topAnchor),
                view.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor)
            ])
            glassView = view
        }
    }

    private func attach(to container: UIView) {
        removeFromSuperview()
        container.addSubview(self)
        presentingContainer = container
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: container.centerXAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }
}
#endif
