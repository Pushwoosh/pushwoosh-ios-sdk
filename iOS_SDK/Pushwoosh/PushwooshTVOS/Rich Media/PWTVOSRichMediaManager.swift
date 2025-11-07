//
//  PWTVOSRichMediaManager.swift
//  PushwooshTVOS
//
//  Created by André Kis on 06.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit
import PushwooshBridge

/// Manager for displaying Rich Media content on tvOS.
///
/// This class handles the parsing, rendering, and display of HTML-based Rich Media
/// content with full support for tvOS Focus Engine and Apple TV remote navigation.
///
/// ## Overview
///
/// The Rich Media manager automatically:
/// - Parses HTML content with inline styles
/// - Renders native UIKit components
/// - Configures focus navigation for tvOS remote
/// - Handles button actions (events, tags, close)
/// - Manages presentation and dismissal animations
///
/// ## Usage
///
/// Configure Rich Media behavior during app initialization:
///
/// ```swift
/// Pushwoosh.TVoS.configureRichMediaWith(
///     position: .center,
///     presentAnimation: .fromBottom,
///     dismissAnimation: .toBottom
/// )
/// ```
@available(tvOS 11.0, *)
@objc(PWTVOSRichMediaManager)
public class PWTVOSRichMediaManager: NSObject {

    /// The screen position where Rich Media will be displayed.
    @objc public var position: PWTVOSRichMediaPosition = .center

    /// The animation type used when presenting Rich Media.
    @objc public var animationType: PWTVOSRichMediaPresentAnimation = .none

    /// The animation type used when dismissing Rich Media.
    @objc public var dismissAnimationType: PWTVOSRichMediaDismissAnimation = .none
    private var _showCloseButton: Bool = true
    private var _getTagsHandler: (([AnyHashable: Any]) -> Void)?

    /// Configures Rich Media presentation settings.
    ///
    /// - Parameters:
    ///   - position: Screen position for Rich Media display. Defaults to `.center`.
    ///   - presentAnimation: Animation when Rich Media appears.
    ///   - dismissAnimation: Animation when Rich Media disappears. Defaults to `.none`.
    @objc
    public func configureRichMediaWith(position: PWTVOSRichMediaPosition = .center, presentAnimation: PWTVOSRichMediaPresentAnimation, dismissAnimation: PWTVOSRichMediaDismissAnimation = .none) {
        self.position = position
        self.animationType = presentAnimation
        self.dismissAnimationType = dismissAnimation
    }

    /// Controls visibility of the Close button on Rich Media.
    ///
    /// - Parameter show: `true` to show Close button, `false` to hide it.
    @objc
    public func configureCloseButton(_ show: Bool) {
        self._showCloseButton = show
    }

    /// Sets a handler for getTags button actions in Rich Media.
    ///
    /// - Parameter handler: Closure called when getTags button is clicked, receiving tags dictionary.
    @objc
    public func setGetTagsHandler(_ handler: @escaping ([AnyHashable: Any]) -> Void) {
        self._getTagsHandler = handler
    }

    func getTagsHandler() -> (([AnyHashable: Any]) -> Void)? {
        return _getTagsHandler
    }

    /// Handles in-app resource for Rich Media display.
    ///
    /// - Parameter resource: Resource object containing pageUrl and code.
    /// - Returns: `true` if resource was handled successfully.
    @objc
    public func handleInAppResource(_ resource: AnyObject) -> Bool {
        guard let pageUrl = resource.value(forKey: "pageUrl") as? String else {
            return false
        }

        let code = (resource.value(forKey: "code") as? String) ?? ""

        DispatchQueue.main.async {
            self.showRichMedia(url: pageUrl, code: code)
        }

        return true
    }

    func handlePush(userInfo: [AnyHashable: Any]) -> Bool {
        guard let richMediaDict = userInfo["rm"] as? [String: Any] else {
            return false
        }

        let url: String
        let code: String

        if let urlString = richMediaDict["url"] as? String {
            url = urlString
        } else {
            return false
        }

        if let codeString = richMediaDict["code"] as? String {
            code = codeString
        } else {
            code = ""
        }

        DispatchQueue.main.async {
            self.showRichMedia(url: url, code: code)
        }

        return true
    }

    private func showRichMedia(url: String, code: String) {
        let rootViewController: UIViewController?

        if #available(tvOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            rootViewController = window.rootViewController
        } else {
            rootViewController = UIApplication.shared.keyWindow?.rootViewController
        }

        guard let rootVC = rootViewController else {
            return
        }

        let richMediaVC = PWTVOSRichMediaViewController(
            url: url,
            code: code,
            position: self.position,
            animationType: self.animationType,
            dismissAnimationType: self.dismissAnimationType,
            showCloseButton: self._showCloseButton,
            richMediaManager: self
        )

        if let presentedVC = rootVC.presentedViewController {
            presentedVC.present(richMediaVC, animated: true)
        } else {
            rootVC.present(richMediaVC, animated: true)
        }
    }

    /// Dismisses currently displayed Rich Media.
    ///
    /// - Parameter animated: Whether to animate the dismissal.
    @objc public func dismiss(animated: Bool) {
        if #available(tvOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController else {
                return
            }

            if let presentedVC = rootVC.presentedViewController {
                presentedVC.dismiss(animated: animated)
            }
        } else {
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController,
               let presentedVC = rootVC.presentedViewController {
                presentedVC.dismiss(animated: animated)
            }
        }
    }
}

@available(tvOS 11.0, *)
class PWTVOSRichMediaViewController: UIViewController {

    private let url: String
    private let code: String
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var localizationData: [String: Any]?

    private var pushwooshParser: PWTVOSHTMLParser!
    private var universalParser: PWTVOSUniversalHTMLParser!
    private var buttonActionHandler: PWTVOSButtonActionHandler!
    private var pushwooshRenderer: PWTVOSRichMediaRenderer!
    private var universalRenderer: PWTVOSUniversalRenderer!
    private var closeButton: UIButton?
    private var activeRenderer: Any?
    private var focusGuideView: UIView!
    private var shouldAllowButtonFocus: Bool = false
    weak var richMediaManager: PWTVOSRichMediaManager?

    var position: PWTVOSRichMediaPosition
    var animationType: PWTVOSRichMediaPresentAnimation
    var dismissAnimationType: PWTVOSRichMediaDismissAnimation
    var showCloseButton: Bool

    var richmediaCode: String {
        return code
    }

    var messageHash: String? {
        return nil
    }

    var inAppCode: String {
        return code
    }

    init(url: String, code: String, position: PWTVOSRichMediaPosition = .center, animationType: PWTVOSRichMediaPresentAnimation = .none, dismissAnimationType: PWTVOSRichMediaDismissAnimation = .none, showCloseButton: Bool = true, richMediaManager: PWTVOSRichMediaManager?) {
        self.url = url
        self.code = code
        self.position = position
        self.animationType = animationType
        self.dismissAnimationType = dismissAnimationType
        self.showCloseButton = showCloseButton
        self.richMediaManager = richMediaManager
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        focusGuideView = UIView()
        focusGuideView.translatesAutoresizingMaskIntoConstraints = false
        focusGuideView.isUserInteractionEnabled = false
        view.addSubview(focusGuideView)

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bounces = true
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.cornerRadius = 24
        scrollView.addSubview(contentView)

        if showCloseButton {
            let closeBtn = PWTVOSFocusButton(type: .system)
            closeBtn.setTitle("✕ Close", for: .normal)
            closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
            closeBtn.translatesAutoresizingMaskIntoConstraints = false
            closeBtn.addTarget(self, action: #selector(closeButtonTapped), for: .primaryActionTriggered)
            view.addSubview(closeBtn)
            self.closeButton = closeBtn
        }

        buttonActionHandler = PWTVOSButtonActionHandler(viewController: self, richMediaManager: richMediaManager)

        pushwooshParser = PWTVOSHTMLParser()
        universalParser = PWTVOSUniversalHTMLParser()
        pushwooshRenderer = PWTVOSRichMediaRenderer(actionHandler: buttonActionHandler)
        universalRenderer = PWTVOSUniversalRenderer(actionHandler: buttonActionHandler)

        loadLocalizationData()
        parseHTMLAndRender()

        let topMargin: CGFloat = showCloseButton ? 80 : 20
        let bottomMargin: CGFloat = showCloseButton ? 100 : 20

        var constraints: [NSLayoutConstraint] = []

        switch position {
        case .center:
            let sideMargin: CGFloat = showCloseButton ? 250 : 60
            constraints.append(contentsOf: [
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topMargin),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomMargin)
            ])

        case .left:
            let width: CGFloat = 700
            constraints.append(contentsOf: [
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topMargin),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
                scrollView.widthAnchor.constraint(equalToConstant: width),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomMargin)
            ])

        case .right:
            let width: CGFloat = 700
            constraints.append(contentsOf: [
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topMargin),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
                scrollView.widthAnchor.constraint(equalToConstant: width),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomMargin)
            ])

        case .top:
            let sideMargin: CGFloat = showCloseButton ? 250 : 60
            let height: CGFloat = 600
            constraints.append(contentsOf: [
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topMargin),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                scrollView.heightAnchor.constraint(equalToConstant: height)
            ])

        case .bottom:
            let sideMargin: CGFloat = showCloseButton ? 250 : 60
            let height: CGFloat = 600
            constraints.append(contentsOf: [
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomMargin),
                scrollView.heightAnchor.constraint(equalToConstant: height)
            ])
        }

        constraints.append(contentsOf: [
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        let heightConstraint = contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -40)
        heightConstraint.priority = .defaultHigh
        constraints.append(heightConstraint)

        if let closeButton = closeButton {
            constraints.append(contentsOf: [
                closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
                closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        }

        constraints.append(contentsOf: [
            focusGuideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            focusGuideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            focusGuideView.widthAnchor.constraint(equalToConstant: 1),
            focusGuideView.heightAnchor.constraint(equalToConstant: 1)
        ])

        NSLayoutConstraint.activate(constraints)

        setupInitialAnimationState()
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if shouldAllowButtonFocus {
            if let closeButton = closeButton {
                return [closeButton, focusGuideView]
            }
            return [focusGuideView]
        }
        return [focusGuideView]
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)

        if !shouldAllowButtonFocus {
            shouldAllowButtonFocus = true

            if let closeBtn = closeButton as? PWTVOSFocusButton {
                closeBtn.enableFocus()
            }

            var focusableViews: [UIView] = []
            if let universal = activeRenderer as? PWTVOSUniversalRenderer {
                focusableViews = universal.getFocusableViews()
            } else if let pushwoosh = activeRenderer as? PWTVOSRichMediaRenderer {
                focusableViews = pushwoosh.getFocusableViews()
            }

            for view in focusableViews {
                if let focusButton = view as? PWTVOSFocusButton {
                    focusButton.enableFocus()
                }
            }

            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if animationType != .none && scrollView.alpha == 1 {
            setupInitialAnimationState()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyEntryAnimation()
    }

    private func setupInitialAnimationState() {
        guard animationType != .none else { return }

        let screenBounds = view.bounds
        var startTransform: CGAffineTransform = .identity

        switch animationType {
        case .fromTop:
            startTransform = CGAffineTransform(translationX: 0, y: -screenBounds.height)
        case .fromBottom:
            startTransform = CGAffineTransform(translationX: 0, y: screenBounds.height)
        case .fromLeft:
            startTransform = CGAffineTransform(translationX: -screenBounds.width, y: 0)
        case .fromRight:
            startTransform = CGAffineTransform(translationX: screenBounds.width, y: 0)
        case .none:
            return
        }

        scrollView.transform = startTransform
        scrollView.alpha = 0
    }

    private func applyEntryAnimation() {
        guard animationType != .none else { return }

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut, animations: {
            self.scrollView.transform = .identity
            self.scrollView.alpha = 1
        })
    }

    private func loadLocalizationData() {
        let htmlPath = url.hasPrefix("file://") ? String(url.dropFirst(7)) : url
        let htmlURL = URL(fileURLWithPath: htmlPath)
        let dirPath = htmlURL.deletingLastPathComponent().path

        let htmlFileName = htmlURL.deletingPathExtension().lastPathComponent
        let jsonFileName = htmlFileName.replacingOccurrences(of: "index", with: "pushwoosh") + ".json"
        let jsonPath = (dirPath as NSString).appendingPathComponent(jsonFileName)

        let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath))

        guard let jsonData = jsonData,
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let localization = json["localization"] as? [String: Any] else {
            return
        }

        let languageCode = Locale.current.languageCode ?? "en"
        if let langData = localization[languageCode] as? [String: Any] {
            localizationData = langData
        } else if let defaultData = localization["en"] as? [String: Any] {
            localizationData = defaultData
        }
    }

    private func parseHTMLAndRender() {
        let htmlPath = url.hasPrefix("file://") ? String(url.dropFirst(7)) : url

        guard let htmlContent = try? String(contentsOfFile: htmlPath) else {
            return
        }

        let universalElements = universalParser.parseHTML(htmlContent, localization: localizationData)

        if !universalElements.isEmpty {
            universalRenderer.setShowCloseButton(showCloseButton)
            let renderedView = universalRenderer.renderElements(universalElements, containerWidth: scrollView.bounds.width)
            contentView.addSubview(renderedView)

            renderedView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                renderedView.topAnchor.constraint(equalTo: contentView.topAnchor),
                renderedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                renderedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                renderedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            activeRenderer = universalRenderer
        } else {
            let pushwooshElements = pushwooshParser.parseHTML(htmlContent, localization: localizationData)

            let renderedView = pushwooshRenderer.renderElements(pushwooshElements, containerWidth: scrollView.bounds.width)
            contentView.addSubview(renderedView)

            renderedView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                renderedView.topAnchor.constraint(equalTo: contentView.topAnchor),
                renderedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                renderedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                renderedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            activeRenderer = pushwooshRenderer
        }

        trackRichMediaShow()
    }

    private func trackRichMediaShow() {
        guard let inAppManagerClass = NSClassFromString("PWInAppManager") as? NSObject.Type else {
            return
        }

        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard let sharedManager = inAppManagerClass.perform(sharedManagerSelector)?.takeUnretainedValue() else {
            return
        }

        let inAppMessagesManagerSelector = NSSelectorFromString("inAppMessagesManager")
        guard let inAppMessagesManager = sharedManager.perform(inAppMessagesManagerSelector)?.takeUnretainedValue() else {
            return
        }

        let trackSelector = NSSelectorFromString("trackInAppWithCode:action:messageHash:")
        if inAppMessagesManager.responds(to: trackSelector) {
            let method = inAppMessagesManager.method(for: trackSelector)
            typealias TrackFunction = @convention(c) (AnyObject, Selector, String, String, String?) -> Void
            let trackFunc = unsafeBitCast(method, to: TrackFunction.self)
            trackFunc(inAppMessagesManager, trackSelector, code, "com.pushwoosh.PW_INAPP_ACTION_SHOW", messageHash)
        }
    }

    @objc private func closeButtonTapped() {
        dismissWithAnimation()
    }

    func enableButtonFocus() {
        var focusableViews: [UIView] = []

        if let universal = activeRenderer as? PWTVOSUniversalRenderer {
            focusableViews = universal.getFocusableViews()
        } else if let pushwoosh = activeRenderer as? PWTVOSRichMediaRenderer {
            focusableViews = pushwoosh.getFocusableViews()
        }

        for view in focusableViews {
            if let focusButton = view as? PWTVOSFocusButton {
                focusButton.enableFocus()
            }
        }
        setNeedsFocusUpdate()
    }

    func getTextFieldValues() -> [String: String] {
        if let universal = activeRenderer as? PWTVOSUniversalRenderer {
            return universal.getAllTextFieldValues()
        } else if let pushwoosh = activeRenderer as? PWTVOSRichMediaRenderer {
            return pushwoosh.getAllTextFieldValues()
        }
        return [:]
    }

    func dismissWithAnimation() {
        guard dismissAnimationType != .none else {
            dismiss(animated: true)
            return
        }

        let screenBounds = view.bounds
        var endTransform: CGAffineTransform = .identity

        switch dismissAnimationType {
        case .toTop:
            endTransform = CGAffineTransform(translationX: 0, y: -screenBounds.height)
        case .toBottom:
            endTransform = CGAffineTransform(translationX: 0, y: screenBounds.height)
        case .toLeft:
            endTransform = CGAffineTransform(translationX: -screenBounds.width, y: 0)
        case .toRight:
            endTransform = CGAffineTransform(translationX: screenBounds.width, y: 0)
        case .none:
            dismiss(animated: true)
            return
        }

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn, animations: {
            self.scrollView.transform = endTransform
            self.scrollView.alpha = 0
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }

}

