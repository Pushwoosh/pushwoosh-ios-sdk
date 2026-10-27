//
//  PushwooshInboxKitViewController.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS) && os(iOS)
import UIKit
import AVFoundation
import AVKit
import PassKit
import PushwooshCore

/// Modern UIKit inbox controller backed by ``PWInboxService``.
///
/// Configure via a value-typed ``PushwooshInboxKitAttributes`` (Swift) or via
/// the Obj-C-friendly setters (`setBackgroundColor:`, `setEmptyMessage:`, ...).
@objc(PushwooshInboxKitViewController)
public class PushwooshInboxKitViewController: UIViewController {

    public weak var delegate: PushwooshInboxKitDelegate?

    public var attributes: PushwooshInboxKitAttributes {
        didSet { applyAttributes() }
    }

    @objc public private(set) lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.estimatedRowHeight = 88
        table.rowHeight = UITableView.automaticDimension
        return table
    }()

    public private(set) lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    public private(set) lazy var errorStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    let dataSource = InboxDataSource()
    var facade: PWInboxFacade = .shared
    private var emptyStatePlate: InboxStatePlateView?
    private var errorStatePlate: InboxStatePlateView?
    private let errorBanner = InboxErrorBannerView()
    private var tabBar: InboxTabBarView?
    private var currentTabs: PWInboxTabs?
    private var tableTopToView: NSLayoutConstraint!
    private var tableTopToTabBar: NSLayoutConstraint?
    private var refreshControl: UIRefreshControl?
    private var didActivateAudioSessionForVideo = false
    private var previousAudioCategory: AVAudioSession.Category?
    private var previousAudioCategoryOptions: AVAudioSession.CategoryOptions = []
    private var pendingWalletPass: PKPass?
    private var pendingWalletMessage: PWInboxMessageProtocol?
    private var walletAddInProgress = false
    private var didLogUnknownKindFallback = false
    private var lastError: Error?
    private var sawRealBackground = false
    /// True once the visible tab has shown rows on screen, set by a successful load or by any read of the screen;
    /// false again once a load leaves that tab empty, so a later refill is still treated as a first fill.
    private var hasShownContentInWindow = false

    @objc public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.attributes = PushwooshInboxKitAttributes()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public init(attributes: PushwooshInboxKitAttributes) {
        self.attributes = attributes
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        self.attributes = PushwooshInboxKitAttributes()
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pendingInboxRefresh?.cancel()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(errorStateLabel)

        let tableTopToView = tableView.topAnchor.constraint(equalTo: view.topAnchor)
        self.tableTopToView = tableTopToView

        NSLayoutConstraint.activate([
            tableTopToView,
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            errorStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            errorStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        tableView.dataSource = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        registerCells()
        applyAttributes()
        applyTabs(facade.tabs())

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInboxDidUpdate(_:)),
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInboxDidUpdate(_:)),
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidReceiveInPushNotification.com.pushwoosh.inbox"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppDidEnterBackground() {
        sawRealBackground = true
    }

    @objc private func handleAppDidBecomeActive() {
        guard sawRealBackground else { return }
        sawRealBackground = false
        DispatchQueue.main.async { [weak self] in
            self?.reloadData()
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Server is authoritative on re-entry; drops any locally-merged state.
        loadMessages(mode: .replace)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Restore the host's audio session after a full-screen video player was dismissed
        // (which brings this controller back). `.notifyOthersOnDeactivation` lets the host's
        // background audio resume. Guarded so we only deactivate a session we activated.
        // Only deactivate when no player is still on screen — a rapid second video tap can present
        // a new player before this fires, and we must not kill that player's audio session.
        if didActivateAudioSessionForVideo, presentedViewController == nil {
            deactivateVideoAudioSession()
        }
        markDisplayedAsRead()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if attributes.automaticReadOnDisappear {
            markVisibleAsRead()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            // Inbox is leaving for good (not merely covered by the video player). If we activated the
            // audio session for a video, viewDidAppear won't fire again to release it — do it here so
            // the host's background audio isn't left suppressed.
            if didActivateAudioSessionForVideo {
                deactivateVideoAudioSession()
            }
            delegate?.inboxKit(didDismiss: self)
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAttributes()
        for cell in tableView.visibleCells {
            if let inboxCell = cell as? PushwooshInboxCell,
               let indexPath = tableView.indexPath(for: cell),
               let message = dataSource.message(at: indexPath) {
                inboxCell.apply(message: message, attributes: attributes)
            }
        }
    }

    /// Reloads inbox messages from the SDK. Default mode is `.merge` —
    /// preserves any locally-added messages (e.g. just arrived via push)
    /// when the server response doesn't include them yet.
    @objc public func reloadData() {
        loadMessages(mode: .merge)
    }

    /// Async/await variant of `reloadData()`. Useful from SwiftUI hosts and
    /// XCTest where bridging completion handlers is awkward. Throws on
    /// network failure; on success, the data source is hard-replaced with
    /// fresh server truth and the table view is reloaded.
    public func reload() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            facade.loadMessages { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.applyLoadResult(result, mode: .replace)
                if let error = result.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    enum LoadMode { case merge, replace }

    /// Internal load entry point that lets callers choose how the response
    /// is reconciled with the existing data source. `viewWillAppear` and
    /// pull-to-refresh use `.replace` (hard truth); notification-driven
    /// reloads use `.merge` to survive the APNS-vs-server-sync race.
    func loadMessages(mode: LoadMode) {
        facade.loadMessages { [weak self] result in
            guard let self = self else { return }
            self.applyLoadResult(result, mode: mode)
            // Without tabs every successful load reads what it leaves on screen, as before tabs existed.
            if self.currentTabs == nil, result.error == nil {
                self.markDisplayedAsRead()
            }
        }
    }

    /// Shared completion of both load entry points. With tabs it auto-reads the first screen only on the first
    /// on-screen fill of a non-empty tab; later loads read only the messages they brought in.
    private func applyLoadResult(_ result: InboxLoadResult, mode: LoadMode) {
        // Read before the data source is reconciled: afterwards there is no way to tell which messages this load brought in.
        let isFirstFill = !hasShownContentInWindow
        let knownCodes = Set(dataSource.allMessages.compactMap { $0.code })
        if let error = result.error {
            lastError = error
            // An empty cached list means storage has nothing, so the full-screen error state stands.
            if !result.messages.isEmpty {
                reconcile(result.messages, mode: mode)
            }
            applyTabs(facade.tabs())
            tableView.reloadData()
            updateStates()
            showRefreshErrorBanner(for: error)
            delegate?.inboxKit(self, didRefreshWith: dataSource.allMessages, error: error)
        } else {
            lastError = nil
            reconcile(result.messages, mode: mode)
            applyTabs(facade.tabs())
            tableView.reloadData()
            updateStates()
            delegate?.inboxKit(self, didRefreshWith: dataSource.allMessages, error: nil)
            if currentTabs != nil {
                if isFirstFill {
                    markDisplayedAsRead()
                } else {
                    let arrived = Set(result.messages.compactMap { $0.code }).subtracting(knownCodes)
                    if !arrived.isEmpty {
                        markDisplayedAsRead(codes: arrived)
                    }
                }
            }
            // The gate tracks the tab on screen, not the whole inbox: an emptied tab re-arms it, an off-screen load leaves it as it stands.
            if dataSource.isEmpty {
                hasShownContentInWindow = false
            } else if onScreenRect() != nil {
                hasShownContentInWindow = true
            }
        }
        refreshControl?.endRefreshing()
    }

    private func reconcile(_ messages: [PWInboxMessageProtocol], mode: LoadMode) {
        switch mode {
        case .replace:
            dataSource.replace(messages, transform: attributes.transform)
        case .merge:
            dataSource.update(messages, transform: attributes.transform)
        }
    }

    // MARK: - Obj-C-friendly setters

    @objc public func setBackgroundColor(_ color: UIColor) {
        attributes.style.backgroundColor = color
    }

    /// Sets the card background as a dynamic colour, so the labels stay readable in both appearances.
    @objc public func setBackgroundColor(light: UIColor, dark: UIColor) {
        attributes.style.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    @objc public func setAccentColor(_ color: UIColor) {
        attributes.style.unreadBadgeColor = color
    }

    @objc public func setSeparatorColor(_ color: UIColor) {
        attributes.style.separatorColor = color
    }

    @objc public func setEmptyMessage(_ text: String) {
        attributes.emptyMessage = text
    }

    @objc public func setEmptyImage(_ image: UIImage?) {
        // Reserved for future empty-state image support.
        _ = image
    }

    @objc public func setErrorMessage(_ text: String) {
        attributes.errorMessage = text
    }

    @objc public func setErrorImage(_ image: UIImage?) {
        // Reserved for future error-state image support.
        _ = image
    }

    @objc public func setDateFormatter(_ block: @escaping (Date) -> String) {
        attributes.style.dateFormatter = block
    }

    @objc public func setAutomaticReadOnDisappear(_ enabled: Bool) {
        attributes.automaticReadOnDisappear = enabled
    }

    @objc public func setAutomaticReadOnDisplay(_ enabled: Bool) {
        attributes.automaticReadOnDisplay = enabled
    }

    @objc public func setSwipeToDeleteEnabled(_ enabled: Bool) {
        attributes.swipeToDeleteEnabled = enabled
    }

    @objc public func setEnableDarkTheme(_ enabled: Bool) {
        attributes.enableDarkTheme = enabled
    }

    @objc public func setPinningEnabled(_ enabled: Bool) {
        attributes.pinningEnabled = enabled
    }

    @objc public func setPinIndicatorVisible(_ visible: Bool) {
        attributes.pinIndicatorVisible = visible
    }

    @objc public func setInlineButtonsEnabled(_ enabled: Bool) {
        attributes.inlineButtonsEnabled = enabled
    }

    /// Forces every message to render with the named cell kind. Pass `nil`
    /// (or an unknown name) to revert to the server-driven resolver.
    @objc public func setForceCellKind(_ rawValue: String?) {
        if let rawValue = rawValue, let kind = PushwooshInboxKitAttributes.CellKind(rawValue: rawValue) {
            attributes.forceCellKind = kind
        } else {
            attributes.forceCellKind = nil
        }
    }

    @objc public func setButtonBackgroundColor(_ color: UIColor) {
        attributes.style.buttonBackgroundColor = color
    }

    @objc public func setButtonTextColor(_ color: UIColor) {
        attributes.style.buttonTextColor = color
    }

    @objc public func setButtonFont(_ font: UIFont) {
        attributes.style.buttonFont = font
    }

    @objc public func setPinIndicatorColor(_ color: UIColor) {
        attributes.style.pinIndicatorColor = color
    }

    @objc public func setPinIndicatorImage(_ image: UIImage?) {
        attributes.style.pinIndicatorImage = image
    }

    // MARK: - Internal

    func applyAttributes() {
        guard isViewLoaded else { return }
        let traits: UITraitCollection? = attributes.enableDarkTheme
            ? nil
            : UITraitCollection(userInterfaceStyle: .light)
        // Force the whole hierarchy (cells, glass effects, SF Symbols, system-drawn backgrounds) to
        // light when dark theme is disabled — manual colour resolution alone doesn't cover those.
        overrideUserInterfaceStyle = attributes.enableDarkTheme ? .unspecified : .light

        // The host view (page background) uses Apple's grouped page colour —
        // distinct from `style.backgroundColor`, which is the card surface
        // colour applied by individual cells. This produces the Apple-stock
        // contrast where cards float on a slightly tinted page.
        let pageBackground: UIColor = {
            if let traits = traits {
                return attributes.style.pageBackgroundColor.resolvedColor(with: traits)
            }
            return attributes.style.pageBackgroundColor
        }()
        view.backgroundColor = pageBackground
        tableView.backgroundColor = pageBackground
        tableView.separatorStyle = .none
        tableView.separatorColor = traits.map { attributes.style.separatorColor.resolvedColor(with: $0) } ?? attributes.style.separatorColor

        emptyStateLabel.text = attributes.emptyMessage
        errorStateLabel.text = attributes.errorMessage

        emptyStateLabel.textColor = traits.map { attributes.style.titleColorRead.resolvedColor(with: $0) } ?? attributes.style.titleColorRead
        errorStateLabel.textColor = traits.map { attributes.style.titleColorRead.resolvedColor(with: $0) } ?? attributes.style.titleColorRead

        syncStatePlates()

        registerCells()
        configureRefreshControl()
        if let strip = tabBar, let tabs = currentTabs {
            strip.configure(tabs: tabs, selectedTabId: dataSource.selectedTabId, style: attributes.style)
            refreshTabBarCounts()
        }
        updateStates()
    }

    /// Installs or tears down the backing plates behind the state labels. They are a Liquid Glass
    /// affordance only: with the flag off nothing is added to the hierarchy, so a default-configured
    /// inbox keeps the bare page background behind the empty/error text.
    private func syncStatePlates() {
        guard attributes.style.isLiquidGlass else {
            emptyStatePlate?.removeFromSuperview()
            emptyStatePlate = nil
            errorStatePlate?.removeFromSuperview()
            errorStatePlate = nil
            return
        }
        let empty = emptyStatePlate ?? installStatePlate(behind: emptyStateLabel)
        let error = errorStatePlate ?? installStatePlate(behind: errorStateLabel)
        emptyStatePlate = empty
        errorStatePlate = error
        empty.apply(style: attributes.style)
        error.apply(style: attributes.style)
        empty.isHidden = emptyStateLabel.isHidden
        error.isHidden = errorStateLabel.isHidden
    }

    private func installStatePlate(behind label: UILabel) -> InboxStatePlateView {
        let plate = InboxStatePlateView()
        view.insertSubview(plate, belowSubview: label)
        NSLayoutConstraint.activate([
            plate.topAnchor.constraint(equalTo: label.topAnchor, constant: -16),
            plate.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            plate.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -20),
            plate.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 20)
        ])
        return plate
    }

    private func registerCells() {
        for (kind, cls) in attributes.cells {
            tableView.register(cls, forCellReuseIdentifier: kind)
        }
    }

    private func configureRefreshControl() {
        if attributes.pullToRefreshEnabled {
            if refreshControl == nil {
                let control = UIRefreshControl()
                control.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
                tableView.refreshControl = control
                refreshControl = control
            }
        } else {
            tableView.refreshControl = nil
            refreshControl = nil
        }
    }

    @objc private func handlePullToRefresh() {
        loadMessages(mode: .replace)
    }

    @objc private func handleInboxDidUpdate(_ note: Notification) {
        let userInfo = note.userInfo
        // Captured before the async hop: the flag only holds for the duration of the synchronous call.
        let isOwnRead = Thread.isMainThread && isApplyingOwnRead
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // userInfo arrives from Obj-C NSNotification — try the typed Swift
            // bridge first, fall back to element-wise coercion when the
            // Obj-C runtime hands us NSArray<id>.
            if let added = userInfo?["messagesAdded"] as? [PWInboxMessageProtocol], !added.isEmpty {
                self.mergeIncomingMessages(added)
            } else if let nsArray = userInfo?["messagesAdded"] as? NSArray, nsArray.count > 0 {
                let coerced = nsArray.compactMap { $0 as? PWInboxMessageProtocol }
                if !coerced.isEmpty {
                    self.mergeIncomingMessages(coerced)
                }
            }

            // Debounced reload to converge other updates; skipped for our own auto-read to avoid re-reading the resorted tail.
            if !isOwnRead {
                self.scheduleInboxRefresh()
            }
        }
    }

    private var lastInboxRefreshAt: Date?
    private var pendingInboxRefresh: DispatchWorkItem?

    private func scheduleInboxRefresh(minimumInterval: TimeInterval = 1.5) {
        pendingInboxRefresh?.cancel()
        let now = Date()
        // Treat "never refreshed yet" as elapsed = 0 (not .infinity) — the first
        // notification-driven reload still respects the debounce window so the
        // server has time to sync after APNS delivery.
        let elapsed = lastInboxRefreshAt.map { now.timeIntervalSince($0) } ?? 0
        let delay = max(0, minimumInterval - elapsed)
        let work = DispatchWorkItem { [weak self] in
            self?.lastInboxRefreshAt = Date()
            self?.reloadData()
        }
        pendingInboxRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func mergeIncomingMessages(_ added: [PWInboxMessageProtocol]) {
        let existingCodes = Set(dataSource.allMessages.compactMap { $0.code })
        let fresh = added.filter { msg in
            guard let code = msg.code else { return false }
            return !existingCodes.contains(code)
        }
        guard !fresh.isEmpty else { return }
        let merged = fresh + dataSource.allMessages
        dataSource.update(merged, transform: attributes.transform)
        tableView.reloadData()
        updateStates()
        delegate?.inboxKit(self, didRefreshWith: dataSource.allMessages, error: nil)
        // Before the first fill the load completing next reads the screen; reading here too would read a second, re-sorted screen.
        if currentTabs != nil, hasShownContentInWindow {
            markDisplayedAsRead(codes: Set(fresh.compactMap { $0.code }))
        }
    }

    /// Recomputes empty/error/table visibility and may only hide the error banner. The table hides only for a
    /// fully empty inbox, so an empty tab keeps pull-to-refresh.
    private func updateStates() {
        let tabEmpty = dataSource.isEmpty
        let allEmpty = dataSource.allMessages.isEmpty
        let hasError = lastError != nil
        // Full-screen error is reserved for a totally empty inbox; a non-empty one surfaces the failure via the banner.
        let showFullScreenError = allEmpty && hasError

        emptyStateLabel.isHidden = !tabEmpty || showFullScreenError
        errorStateLabel.isHidden = !showFullScreenError
        emptyStatePlate?.isHidden = emptyStateLabel.isHidden
        errorStatePlate?.isHidden = errorStateLabel.isHidden
        tableView.isHidden = allEmpty

        if !hasError || allEmpty {
            errorBanner.hide()
        }

        refreshTabBarCounts()
    }

    /// Surfaces a refresh that has just failed, while content is still on screen. An inbox with
    /// nothing cached keeps the full-screen error instead.
    private func showRefreshErrorBanner(for error: Error) {
        guard !dataSource.allMessages.isEmpty else { return }
        let message = attributes.errorMessage.isEmpty ? error.localizedDescription : attributes.errorMessage
        errorBanner.show(text: message, style: attributes.style, in: view, duration: 2.5)
    }

    // MARK: - Tab strip

    /// Test-only window onto the strip, so tests can read its rendered state without the
    /// production-facing `tabBar` property becoming public.
    var tabBarForTesting: InboxTabBarView? { tabBar }

    /// Test-only window onto the bottom error banner, matching `tabBarForTesting`.
    var errorBannerForTesting: InboxErrorBannerView { errorBanner }

    /// Reconciles the strip with the Control-Panel tab list. `nil` or an empty list tears the
    /// strip down and restores today's layout; an unchanged list (`PWInboxTabs.isEqual:`, which
    /// compares every field and tab order) is left alone so a routine poll never flickers it.
    private func applyTabs(_ newTabs: PWInboxTabs?) {
        guard let newTabs = newTabs, !newTabs.tabs.isEmpty else {
            currentTabs = nil
            removeTabBar()
            clearSelectedTab()
            return
        }
        if let currentTabs = currentTabs, currentTabs.isEqual(newTabs) {
            return
        }
        currentTabs = newTabs

        let ids = Set(newTabs.tabs.map { $0.identifier })
        if let selected = dataSource.selectedTabId, !ids.contains(selected) {
            clearSelectedTab()
        }

        let strip = tabBar ?? makeTabBar()
        strip.configure(tabs: newTabs, selectedTabId: dataSource.selectedTabId, style: attributes.style)
        refreshTabBarCounts()
    }

    private func makeTabBar() -> InboxTabBarView {
        let strip = InboxTabBarView()
        strip.onSelect = { [weak self] tabId in
            self?.selectTab(tabId)
        }
        view.addSubview(strip)
        tableTopToView.isActive = false
        let tableTop = tableView.topAnchor.constraint(equalTo: strip.bottomAnchor)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableTop
        ])
        tableTopToTabBar = tableTop
        tabBar = strip
        return strip
    }

    private func removeTabBar() {
        guard let strip = tabBar else { return }
        tableTopToTabBar?.isActive = false
        tableTopToTabBar = nil
        strip.removeFromSuperview()
        tabBar = nil
        tableTopToView.isActive = true
    }

    /// Handles a tap on the strip: filters the table, resyncs the empty/error state for the new
    /// (possibly empty) filtered view, and reads whatever that filter now shows on screen. Both
    /// `updateStates()` and the read itself refresh the badges, so the counts outlive the tap.
    private func selectTab(_ tabId: String?) {
        dataSource.selectedTabId = tabId
        tableView.reloadData()
        scrollToTop()
        updateStates()
        markDisplayedAsRead()
    }

    /// Drops the tab filter the way `applyTabs` needs it: the feed the user was scrolled into is
    /// gone, so the offset goes with it before anything reads what is now under it.
    private func clearSelectedTab() {
        guard dataSource.selectedTabId != nil else { return }
        dataSource.selectedTabId = nil
        scrollToTop()
    }

    /// Drops the offset `reloadData()` keeps, so a switched tab opens at its first row and auto-read
    /// does not reach rows the user never saw.
    private func scrollToTop() {
        view.layoutIfNeeded()
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
        // The first layout pass after the reload can still move the offset, so pin it again once that pass has run.
        tableView.layoutIfNeeded()
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    private func refreshTabBarCounts() {
        guard let strip = tabBar, let tabs = currentTabs else { return }
        var counts: [String?: Int] = [nil: dataSource.unreadCount(forTabId: nil)]
        for tab in tabs.tabs {
            counts[tab.identifier] = dataSource.unreadCount(forTabId: tab.identifier)
        }
        strip.updateUnreadCounts(counts)
    }

    /// Reads the rows on screen while the inbox is actually showing them, narrowed to `codes` when
    /// the caller only means the messages it just brought in. Off-window calls (a load finishing
    /// before the first appearance) are skipped; `viewDidAppear` covers that case.
    func markDisplayedAsRead(codes: Set<String>? = nil) {
        guard attributes.automaticReadOnDisplay, viewIfLoaded?.window != nil else { return }
        tableView.layoutIfNeeded()
        markVisibleAsRead(limitedTo: codes)
    }

    /// Reads the unread rows currently on screen. With tabs only the rows inside the window, then repaints them and refreshes
    /// the badges; without tabs the table's visible rows, converged through the usual debounced reload, as before tabs existed.
    private func markVisibleAsRead(limitedTo codes: Set<String>? = nil) {
        guard currentTabs != nil else {
            let unread = (tableView.indexPathsForVisibleRows ?? []).filter { isUnread(at: $0, limitedTo: codes) }.compactMap { dataSource.message(at: $0) }
            if !unread.isEmpty { facade.read(messages: unread) }
            return
        }
        // A host that has not laid out yet leaves the table a provisional frame, and the rows read would not be the rows shown.
        view.layoutIfNeeded()
        guard let onScreen = onScreenRect() else { return }
        let shown = (tableView.indexPathsForVisibleRows ?? []).filter { tableView.rectForRow(at: $0).intersects(onScreen) }
        if !shown.isEmpty {
            hasShownContentInWindow = true
        }
        let rows = shown.filter { isUnread(at: $0, limitedTo: codes) }
        let messages = rows.compactMap { dataSource.message(at: $0) }
        guard !messages.isEmpty else { return }
        readWithoutSelfRefresh(messages)
        repaintRows(rows)
        refreshTabBarCounts()
    }

    private func isUnread(at indexPath: IndexPath, limitedTo codes: Set<String>?) -> Bool {
        guard let message = dataSource.message(at: indexPath), !message.isRead else { return false }
        guard let codes = codes else { return true }
        return message.code.map(codes.contains) ?? false
    }

    /// Repaints rows an auto-read just changed: `readWithoutSelfRefresh` silences the update
    /// notification whose debounced reload used to redraw them.
    private func repaintRows(_ indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard let cell = tableView.cellForRow(at: indexPath) as? PushwooshInboxCell,
                  let message = dataSource.message(at: indexPath) else { continue }
            cell.apply(message: message, attributes: attributes)
        }
    }

    private var isApplyingOwnRead = false

    /// Reads messages without the reload `handleInboxDidUpdate` would schedule: `PWInbox` posts its
    /// update inline, before `facade.read` returns.
    private func readWithoutSelfRefresh(_ messages: [PWInboxMessageProtocol]) {
        isApplyingOwnRead = true
        defer { isApplyingOwnRead = false }
        facade.read(messages: messages)
    }

    /// The table's bounds clipped to the window, in table coordinates, `nil` off-window: a provisional frame
    /// taller than the screen would otherwise count rows below the fold as visible.
    private func onScreenRect() -> CGRect? {
        guard let window = tableView.window else { return nil }
        let boundsInWindow = tableView.convert(tableView.bounds, to: window)
        let onScreenInWindow = boundsInWindow.intersection(window.bounds)
        guard !onScreenInWindow.isNull, !onScreenInWindow.isEmpty else { return nil }
        return window.convert(onScreenInWindow, to: tableView)
    }

    /// Marks the given messages as read both server-side and locally
    /// (persisted to `PWInboxStorage`).
    ///
    /// Use this from a custom delegate handler when you returned `false`
    /// from ``PushwooshInboxKitDelegate/inboxKit(_:didSelect:)`` (skipping
    /// the default action) but still want the row to reflect the read
    /// state immediately. Idempotent — already-read messages are skipped.
    /// Survives process restart even if the network request is still
    /// pending acknowledgment.
    @objc public func markRead(messages: [PWInboxMessageProtocol]) {
        let unread = messages.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        facade.read(messages: unread)
        let rowsToReload = unread.compactMap { indexPath(for: $0) }
        if !rowsToReload.isEmpty {
            tableView.reloadRows(at: rowsToReload, with: .none)
        }
        refreshTabBarCounts()
    }

    /// Marks every currently-stored unread inbox message as read. Routes
    /// through `Pushwoosh.inbox.markAllMessagesAsRead()` so storage and server stay
    /// in sync. Suitable for a "Mark all as read" toolbar button.
    @objc public func markAllAsRead() {
        facade.markAllAsRead()
        tableView.reloadData()
        refreshTabBarCounts()
    }

    /// Deletes every read message from the inbox in one batch. Useful for a
    /// "Clear read" affordance in the nav bar. Unread (and pinned-unread)
    /// messages are preserved.
    @objc public func clearReadMessages() {
        facade.deleteAllRead()
        // Reflect the deletion in the already-visible table immediately. `deleteAllRead`
        // removes read messages from storage/server, but the background notification does
        // not refresh an open controller, so update the data source directly here (mirrors
        // `markAllAsRead`) — read rows drop out at once instead of only after a reopen.
        let remaining = dataSource.allMessages.filter { !$0.isRead }
        dataSource.replace(remaining, transform: attributes.transform)
        tableView.reloadData()
        updateStates()
    }

    /// Deletes every message in the inbox — read AND unread — in one batch and refreshes the
    /// open table immediately. Use for a "Clear all" / trash affordance, where the user expects
    /// the whole inbox to empty (unlike ``clearReadMessages``, which keeps unread messages).
    @objc public func deleteAllMessages() {
        let all = dataSource.allMessages
        guard !all.isEmpty else { return }
        facade.delete(messages: all)
        dataSource.replace([], transform: attributes.transform)
        tableView.reloadData()
        updateStates()
    }

    private func cellKind(for message: PWInboxMessageProtocol) -> String {
        if let forced = attributes.forceCellKind, attributes.cells[forced.rawValue] != nil {
            return forced.rawValue
        }
        let kind = attributes.cellKindResolver(message)
        if attributes.cells[kind] != nil {
            return kind
        }
        if !didLogUnknownKindFallback {
            didLogUnknownKindFallback = true
            PushwooshLog.pushwooshLog(
                .PW_LL_WARN,
                className: PushwooshInboxKitViewController.self,
                message: "Unknown inbox cell kind '\(kind)' returned by resolver. Falling back to 'default'."
            )
        }
        return "default"
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

/// What a card opens on its own, without the message payload.
private enum CardDestination {
    case video(URL)
    case wallet(URL)
}

extension PushwooshInboxKitViewController: UITableViewDataSource, UITableViewDelegate {

    public func numberOfSections(in tableView: UITableView) -> Int { 1 }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let message = dataSource.message(at: indexPath) else {
            return UITableViewCell()
        }
        let kind = cellKind(for: message)
        let cell = tableView.dequeueReusableCell(withIdentifier: kind, for: indexPath)
        if let inboxCell = cell as? PushwooshInboxCell {
            inboxCell.apply(message: message, attributes: attributes)
            inboxCell.onInlineButtonTap = { [weak self, weak inboxCell] button in
                guard let self = self, let inboxCell = inboxCell else { return }
                self.handleInlineButtonTap(button, on: message, from: inboxCell)
            }
            if let carouselCell = inboxCell as? PushwooshInboxCarouselCell {
                carouselCell.onCarouselSlideTap = { [weak self] url in
                    self?.handleCarouselSlideTap(url, on: message)
                }
            }
            if let videoCell = inboxCell as? PushwooshInboxVideoCell {
                videoCell.onVideoTap = { [weak self] url in
                    guard let self = self else { return }
                    if self.hasMessageAction(message) {
                        self.performDefaultSelection(for: message)
                    } else {
                        self.handleVideoTap(url, on: message)
                    }
                }
            }
            if let walletCell = inboxCell as? PushwooshInboxWalletCell {
                walletCell.onAddToWallet = { [weak self] url in
                    guard let self = self else { return }
                    if self.hasMessageAction(message) {
                        self.performDefaultSelection(for: message)
                    } else {
                        self.handleAddToWallet(url, on: message)
                    }
                }
            }
        }
        return cell
    }

    private func handleInlineButtonTap(_ button: PushwooshInboxButton,
                                       on message: PWInboxMessageProtocol,
                                       from cell: PushwooshInboxCell) {
        // A link button on a message that carries its own l/rm runs the message action instead
        // of the button URL, so one tap never opens two destinations. That path reports the open
        // itself; reporting it here as well would count the tap twice.
        let runsMessageAction: Bool
        if case .openURL = button.action {
            runsMessageAction = hasMessageAction(message)
        } else {
            runsMessageAction = false
        }

        // Any interaction with a card counts as an open, so this lands before the delegate can
        // take the navigation away from us.
        if !runsMessageAction {
            facade.reportAction(message: message)
            repaintRow(for: message)
        }

        let shouldPerformDefault = delegate?.inboxKit(self, didTapButton: button, onMessage: message) ?? true
        guard shouldPerformDefault else {
            if runsMessageAction {
                facade.reportAction(message: message)
                repaintRow(for: message)
            }
            return
        }

        switch button.action {
        case .openURL(let url):
            if runsMessageAction {
                performMessageAction(for: message)
            } else {
                openExternalURL(url)
                markRead(messages: [message])
            }

        case .dismiss:
            // Message is being removed — read state is irrelevant.
            performDismissAction(for: message)

        case .markRead:
            performMarkReadAction(for: message)

        case .custom:
            // Host owns the side-effect, but the user has clearly seen and
            // interacted with the card — flip to read for parity with the
            // card-level tap and with Mail / Slack / Apple Notifications.
            markRead(messages: [message])
        }
    }

    /// Handles a carousel slide tap. A slide carrying its own URL opens it (honoring the
    /// `didSelect` opt-out, so the host can intercept the tap exactly like a full-row tap) and
    /// marks the message read; a slide without a link, or any slide of a message that carries
    /// its own l/rm, falls through to the message's default selection action, matching the row tap.
    private func handleCarouselSlideTap(_ url: URL?, on message: PWInboxMessageProtocol) {
        guard let url = url, !hasMessageAction(message) else {
            performDefaultSelection(for: message)
            return
        }
        facade.reportAction(message: message)
        repaintRow(for: message)
        let shouldPerformDefault = delegate?.inboxKit(self, didSelect: message) ?? true
        guard shouldPerformDefault else { return }
        openExternalURL(url)
        markRead(messages: [message])
    }

    /// Opens a server-supplied URL through the system. Card content is untrusted, so schemes that
    /// are unsafe to hand straight to `UIApplication.open` are refused: `file:`/`javascript:`/`data:`
    /// (local/script payloads) and `facetime:`/`facetime-audio:` (place a call with no confirmation
    /// prompt). Custom app deep links (e.g. `myapp://…`) and `http(s)`/`mailto`/`tel`/`sms` pass
    /// through — blocking those would break the primary CTA use case.
    private func openExternalURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        guard !["file", "javascript", "data", "facetime", "facetime-audio"].contains(scheme) else {
            PushwooshLog.pushwooshLog(
                .PW_LL_WARN,
                className: "PushwooshInboxKit",
                message: "Refusing to open inbox URL with unsafe scheme: \(scheme)"
            )
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Runs the message's default selection action (honoring the delegate opt-out), marks it
    /// read, and refreshes the row. Shared by full-row taps and no-URL carousel slide taps.
    private func performDefaultSelection(for message: PWInboxMessageProtocol) {
        let shouldPerformDefault = delegate?.inboxKit(self, didSelect: message) ?? true
        guard shouldPerformDefault else {
            // The host navigates instead of us, but the tap happened: this is the path
            // that was zeroing the open counter.
            facade.reportAction(message: message)
            facade.read(messages: [message])
            repaintRow(for: message)
            refreshTabBarCounts()
            return
        }
        performMessageAction(for: message)
    }

    /// Reports the open and runs the message's own l/rm, then marks it read.
    private func performMessageAction(for message: PWInboxMessageProtocol) {
        let wasUnread = !message.isRead
        facade.performAction(message: message)
        facade.read(messages: [message])
        if wasUnread {
            if let indexPath = indexPath(for: message) {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            refreshTabBarCounts()
        }
    }

    /// Whether the message carries an action of its own (`l`, `rm`, `h` or `r`, the keys the SDK
    /// runs on an inbox open). Such a message answers every tap with that action, so a card element
    /// with a destination of its own (a link button, a slide URL, the video, the wallet pass) does
    /// not open a second one.
    private func hasMessageAction(_ message: PWInboxMessageProtocol) -> Bool {
        guard let params = message.actionParams as NSDictionary? else { return false }
        if let richMedia = params["rm"], !(richMedia is NSNull) { return true }
        return ["l", "h", "r"].contains { key in
            guard let value = params[key] as? String else { return false }
            return !value.isEmpty
        }
    }

    /// Presents a full-screen player (sound on, transport controls) for a tapped video card and
    /// marks the carrying message read. Picture-in-Picture is disabled so closing the player
    /// slides it away cleanly instead of shrinking it into a screen corner. Plays even with the
    /// silent switch on (`.playback` audio session).
    private func handleVideoTap(_ url: URL, on message: PWInboxMessageProtocol) {
        // The interaction happened; the open ships before the guards below.
        facade.reportAction(message: message)
        repaintRow(for: message)
        // Something is already presented (a player from a rapid double-tap, or a host sheet):
        // present() would silently fail, leaving the audio session activated with no player on
        // screen and the message wrongly marked read. Bail, mirroring the wallet-add guard.
        guard presentedViewController == nil else { return }
        let session = AVAudioSession.sharedInstance()
        // Snapshot the host's audio configuration before overriding it. The audio session is a
        // process-wide singleton; leaving `.playback` set would hijack a host that is itself an
        // audio/VoIP app (e.g. one using `.playAndRecord`/`.mixWithOthers`).
        previousAudioCategory = session.category
        previousAudioCategoryOptions = session.categoryOptions
        try? session.setCategory(.playback)
        try? session.setActive(true)
        didActivateAudioSessionForVideo = true
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        // Full-screen guarantees this controller's viewDidAppear fires on dismissal, where
        // the audio session is restored.
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true) { player.play() }
        markRead(messages: [message])
    }

    /// Deactivates the audio session activated for a full-screen video and restores the host's
    /// previous category/options, so an audio/VoIP host isn't left with our `.playback` category.
    private func deactivateVideoAudioSession() {
        didActivateAudioSessionForVideo = false
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        if let category = previousAudioCategory {
            try? session.setCategory(category, options: previousAudioCategoryOptions)
            previousAudioCategory = nil
            previousAudioCategoryOptions = []
        }
    }

    /// Adds the pass at `url` to Apple Wallet. If `url` returns raw `.pkpass` bytes (e.g. a direct
    /// download URL), the system add-passes sheet is shown in-app. Otherwise — e.g. a Pushwoosh
    /// Wallet "install link", which is a web URL — the URL is handed to the system, which adds the
    /// pass via Safari/Wallet. Either way the carrying message is marked read.
    private func handleAddToWallet(_ url: URL, on message: PWInboxMessageProtocol) {
        // Before the serializing guard: otherwise a second tap during a download is
        // lost to statistics entirely.
        facade.reportAction(message: message)
        repaintRow(for: message)
        // Serialize: ignore a second tap while a wallet add is already downloading/presenting, so a
        // concurrent completion can't overwrite pendingWalletPass/Message and mis-attribute the
        // success callback. Cleared in the failure/fallback branches and in addPassesViewControllerDidFinish.
        guard !walletAddInProgress else { return }
        walletAddInProgress = true
        URLSession.shared.dataTask(with: url) { [weak self] data, response, networkError in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Raw .pkpass bytes → in-app add-passes sheet. Success / cancel is reported to the
                // host via the PKAddPassesViewControllerDelegate callback below.
                if let data = data, let pass = try? PKPass(data: data) {
                    // Already in Wallet — don't re-present or re-open the .pkpass URL, but the pass IS
                    // in the user's Wallet, so still report success so the host shows its confirmation.
                    if PKPassLibrary().containsPass(pass) {
                        self.walletAddInProgress = false
                        self.markRead(messages: [message])
                        self.delegate?.inboxKit(self, didAddWalletPassFor: message)
                        return
                    }
                    if let addVC = PKAddPassesViewController(pass: pass) {
                        // If something is already presented, present() silently fails and would leave
                        // walletAddInProgress stuck true — bail and reset the flag instead.
                        guard self.presentedViewController == nil else {
                            self.walletAddInProgress = false
                            return
                        }
                        self.pendingWalletPass = pass
                        self.pendingWalletMessage = message
                        addVC.delegate = self
                        self.present(addVC, animated: true)
                        self.markRead(messages: [message])
                        return
                    }
                }
                self.walletAddInProgress = false
                // Nothing downloaded → hard failure; surface it to the host.
                if data == nil {
                    self.delegate?.inboxKit(self, didFailToAddWalletPassFor: message, error: networkError)
                    return
                }
                // Bytes that aren't a raw pass AND an HTTP error status → a broken URL (404/500),
                // not a Wallet install link. Report failure instead of opening Safari on the error.
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    self.delegate?.inboxKit(self, didFailToAddWalletPassFor: message, error: networkError)
                    return
                }
                // Got bytes that aren't a raw pass (e.g. a Pushwoosh install link / web URL) → hand
                // off to the system, which adds the pass via Safari/Wallet. That flow's result isn't
                // observable, so no success/error callback fires here.
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                self.markRead(messages: [message])
            }
        }.resume()
    }

    private func performDismissAction(for message: PWInboxMessageProtocol) {
        let shouldDelete = delegate?.inboxKit(self, shouldDelete: message) ?? true
        guard shouldDelete else { return }
        facade.delete(messages: [message])
        if let indexPath = indexPath(for: message) {
            _ = dataSource.remove(at: indexPath)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            updateStates()
        }
    }

    /// Repaints a row whose status changed. A reported open already makes `isRead` true,
    /// so `markRead` returns early and no longer gets to redraw anything.
    private func repaintRow(for message: PWInboxMessageProtocol) {
        guard let indexPath = indexPath(for: message) else { return }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    private func performMarkReadAction(for message: PWInboxMessageProtocol) {
        guard !message.isRead else { return }
        facade.read(messages: [message])
        // facade.read goes through PWInboxStorage.updateStatus(.read) which
        // mutates the same message ref the data source holds. The reload
        // here just redraws the row with the new isRead state.
        if let indexPath = indexPath(for: message) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        refreshTabBarCounts()
    }

    private func indexPath(for message: PWInboxMessageProtocol) -> IndexPath? {
        guard let code = message.code,
              let row = dataSource.messages.firstIndex(where: { $0.code == code })
        else { return nil }
        return IndexPath(row: row, section: 0)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        markDisplayedAsRead()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        markDisplayedAsRead()
    }

    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        markDisplayedAsRead()
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let message = dataSource.message(at: indexPath) else { return }
        delegate?.inboxKit(self, willDisplay: message, at: indexPath)
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let message = dataSource.message(at: indexPath) else { return }
        if handleRowTapOwnedByCard(message) { return }
        performDefaultSelection(for: message)
    }

    /// A card that carries a destination of its own owns the whole row: the poster and the title
    /// of one card must not lead to two different places, so the tap opens the card's destination.
    /// A message with its own `l` / `rm` owns the row instead, and the row tap performs that action.
    ///
    /// The host keeps the same veto it has on every other tap — the card's destination is still a
    /// default action, so `didSelect` is asked first and a `false` leaves navigation to the host.
    private func handleRowTapOwnedByCard(_ message: PWInboxMessageProtocol) -> Bool {
        guard let destination = ownDestination(for: message) else { return false }

        let shouldPerformDefault = delegate?.inboxKit(self, didSelect: message) ?? true
        guard shouldPerformDefault else {
            facade.reportAction(message: message)
            facade.read(messages: [message])
            repaintRow(for: message)
            return true
        }

        switch destination {
        case .video(let url):
            handleVideoTap(url, on: message)
        case .wallet(let url):
            handleAddToWallet(url, on: message)
        }
        return true
    }

    /// The destination a card carries by itself, or nil for a card that leaves the row to the
    /// message payload.
    private func ownDestination(for message: PWInboxMessageProtocol) -> CardDestination? {
        guard !hasMessageAction(message) else { return nil }
        switch cellKind(for: message) {
        case PushwooshInboxKitAttributes.CellKind.video.rawValue:
            guard let content = PushwooshInboxVideoContent.decode(from: message) else { return nil }
            return .video(content.videoURL)

        case PushwooshInboxKitAttributes.CellKind.wallet.rawValue:
            guard let pass = PushwooshInboxWalletPass.decode(from: message) else { return nil }
            return .wallet(pass.passURL)

        default:
            return nil
        }
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard attributes.swipeToDeleteEnabled else { return nil }
        let action = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self,
                  let message = self.dataSource.message(at: indexPath) else {
                completion(false)
                return
            }
            // A swipe is the same interaction as the dismiss button, and counts the same.
            self.facade.reportAction(message: message)
            let shouldDelete = self.delegate?.inboxKit(self, shouldDelete: message) ?? true
            if !shouldDelete {
                // The row stays, and the open just made it read — repaint it, or it keeps
                // drawing as unread until the next load.
                self.repaintRow(for: message)
                completion(false)
                return
            }
            self.facade.delete(messages: [message])
            // The model may have shifted since the swipe config was built (a concurrent reload from
            // an incoming push). Only animate the row out if it was actually removed at this index;
            // otherwise resync the whole table to avoid an invalid-update crash.
            if self.dataSource.remove(at: indexPath) != nil {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } else {
                tableView.reloadData()
            }
            self.updateStates()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
}

// MARK: - UITableViewDataSourcePrefetching

extension PushwooshInboxKitViewController: UITableViewDataSourcePrefetching {

    /// Warms image caches for rows about to scroll into view — the message image and any carousel
    /// slide images — so they're decoded before the cell is displayed.
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard let message = dataSource.message(at: indexPath) else { continue }
            // Both slots a card can fill: the hero attachment and the message icon.
            if let url = PushwooshInboxKitAttributes.resolvedBannerURL(from: message) {
                MessageImageLoader.shared.prefetch(url)
            }
            if let icon = PushwooshInboxKitAttributes.resolvedImageURL(from: message) {
                MessageImageLoader.shared.prefetch(icon)
            }
            for slide in PushwooshInboxCarouselSlide.decode(from: message) {
                MessageImageLoader.shared.prefetch(slide.imageUrl)
            }
        }
    }
}

// MARK: - PKAddPassesViewControllerDelegate

extension PushwooshInboxKitViewController: PKAddPassesViewControllerDelegate {
    public func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true)
        // The sheet finishes on both "Add" and "Cancel"; a pass now present in the library means
        // it was added. Cancellation reports nothing — it is neither success nor error.
        if let pass = pendingWalletPass, let message = pendingWalletMessage,
           PKPassLibrary().containsPass(pass) {
            delegate?.inboxKit(self, didAddWalletPassFor: message)
        }
        pendingWalletPass = nil
        pendingWalletMessage = nil
        walletAddInProgress = false
    }
}

// MARK: - State-label backing plate

/// Rounded backing plate behind `emptyStateLabel` / `errorStateLabel`, installed only while
/// `style.isLiquidGlass` is on: a `UIGlassEffect` surface under iOS 26+ (Xcode 26+ toolchain), and a
/// flat `style.backgroundColor` fill where glass is unavailable, as in `InboxErrorBannerView`.
final class InboxStatePlateView: UIView {
    private var glassView: UIVisualEffectView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        clipsToBounds = true
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func apply(style: PushwooshInboxKitAttributes.Style) {
        var effect: UIVisualEffect?
#if compiler(>=6.2)
        if style.isLiquidGlass, #available(iOS 26.0, *) {
            effect = pwInboxGlassEffect()
        }
#endif
        guard let effect = effect else {
            glassView?.removeFromSuperview()
            glassView = nil
            backgroundColor = style.backgroundColor
            return
        }
        backgroundColor = .clear
        if let existing = glassView {
            existing.effect = effect
        } else {
            let view = UIVisualEffectView(effect: effect)
            view.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(view, at: 0)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            glassView = view
        }
    }
}
#endif
