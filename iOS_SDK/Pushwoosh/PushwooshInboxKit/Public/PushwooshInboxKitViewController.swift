//
//  PushwooshInboxKitViewController.swift
//  PushwooshInboxKit
//
//  Created by André Kis on 29.04.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS) && os(iOS)
import UIKit
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

    private let dataSource = InboxDataSource()
    var facade: PWInboxFacade = .shared
    private var refreshControl: UIRefreshControl?
    private var didLogUnknownKindFallback = false
    private var lastError: Error?
    private var sawRealBackground = false

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
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(errorStateLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
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
        registerCells()
        applyAttributes()

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

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if attributes.automaticReadOnDisappear {
            markVisibleAsRead()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
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
    @available(iOS 13.0, *)
    public func reload() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            facade.loadMessages { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                switch result {
                case .success(let messages):
                    self.lastError = nil
                    self.dataSource.replace(messages, transform: self.attributes.transform)
                    self.tableView.reloadData()
                    self.updateStates()
                    self.delegate?.inboxKit(self, didRefreshWith: self.dataSource.messages, error: nil)
                    continuation.resume()
                case .failure(let error):
                    self.lastError = error
                    self.tableView.reloadData()
                    self.updateStates()
                    self.delegate?.inboxKit(self, didRefreshWith: self.dataSource.messages, error: error)
                    continuation.resume(throwing: error)
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
            switch result {
            case .success(let messages):
                self.lastError = nil
                switch mode {
                case .replace:
                    self.dataSource.replace(messages, transform: self.attributes.transform)
                case .merge:
                    self.dataSource.update(messages, transform: self.attributes.transform)
                }
                self.tableView.reloadData()
                self.updateStates()
                self.delegate?.inboxKit(self, didRefreshWith: self.dataSource.messages, error: nil)
            case .failure(let error):
                self.lastError = error
                self.tableView.reloadData()
                self.updateStates()
                self.delegate?.inboxKit(self, didRefreshWith: self.dataSource.messages, error: error)
            }
            self.refreshControl?.endRefreshing()
        }
    }

    // MARK: - Obj-C-friendly setters

    @objc public func setBackgroundColor(_ color: UIColor) {
        attributes.style.backgroundColor = color
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

        // The host view (page background) uses Apple's grouped page colour —
        // distinct from `style.backgroundColor`, which is the card surface
        // colour applied by individual cells. This produces the Apple-stock
        // contrast where cards float on a slightly tinted page.
        let pageBackground: UIColor = {
            if let traits = traits {
                return UIColor.systemGroupedBackground.resolvedColor(with: traits)
            }
            return .systemGroupedBackground
        }()
        view.backgroundColor = pageBackground
        tableView.backgroundColor = pageBackground
        tableView.separatorStyle = .none
        tableView.separatorColor = traits.map { attributes.style.separatorColor.resolvedColor(with: $0) } ?? attributes.style.separatorColor

        emptyStateLabel.text = attributes.emptyMessage
        errorStateLabel.text = attributes.errorMessage

        emptyStateLabel.textColor = traits.map { attributes.style.titleColorRead.resolvedColor(with: $0) } ?? attributes.style.titleColorRead
        errorStateLabel.textColor = traits.map { attributes.style.titleColorRead.resolvedColor(with: $0) } ?? attributes.style.titleColorRead

        registerCells()
        configureRefreshControl()
        updateStates()
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

            // Belt-and-braces: also kick a server reload to converge any
            // updates / deletions / read-state changes posted with the same
            // notification name. This is debounced via `lastInboxRefreshAt` so
            // we don't hammer the network when several pushes arrive together.
            self.scheduleInboxRefresh()
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
        let existingCodes = Set(dataSource.messages.compactMap { $0.code })
        let fresh = added.filter { msg in
            guard let code = msg.code else { return false }
            return !existingCodes.contains(code)
        }
        guard !fresh.isEmpty else { return }
        let merged = fresh + dataSource.messages
        dataSource.update(merged, transform: attributes.transform)
        tableView.reloadData()
        updateStates()
        delegate?.inboxKit(self, didRefreshWith: dataSource.messages, error: nil)
    }

    private func updateStates() {
        let hasError = lastError != nil
        let isEmpty = dataSource.isEmpty && !hasError
        emptyStateLabel.isHidden = !isEmpty
        errorStateLabel.isHidden = !hasError
        tableView.isHidden = isEmpty || hasError
    }

    private func markVisibleAsRead() {
        let visibleIndexPaths = tableView.indexPathsForVisibleRows ?? []
        let messages = visibleIndexPaths
            .compactMap { dataSource.message(at: $0) }
            .filter { !$0.isRead }
        guard !messages.isEmpty else { return }
        facade.read(messages: messages)
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
    }

    /// Marks every currently-stored unread inbox message as read. Routes
    /// through `PWInbox.markAllMessagesAsRead` so storage and server stay
    /// in sync. Suitable for a "Mark all as read" toolbar button.
    @objc public func markAllAsRead() {
        facade.markAllAsRead()
        tableView.reloadData()
    }

    /// Deletes every read message from the inbox in one batch. Useful for a
    /// "Clear read" affordance in the nav bar. Unread (and pinned-unread)
    /// messages are preserved.
    @objc public func clearReadMessages() {
        facade.deleteAllRead()
        // The bridge fires PWInboxMessagesDidUpdateNotification; the existing
        // observer reconciles the data source.
    }

    private func cellKind(for message: PWInboxMessageProtocol) -> String {
        if let forced = attributes.forceCellKind {
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
        }
        return cell
    }

    private func handleInlineButtonTap(_ button: PushwooshInboxButton,
                                       on message: PWInboxMessageProtocol,
                                       from cell: PushwooshInboxCell) {
        let shouldPerformDefault = delegate?.inboxKit(self, didTapButton: button, onMessage: message) ?? true
        guard shouldPerformDefault else { return }

        switch button.action {
        case .openURL(let url):
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            markRead(messages: [message])

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

    private func performMarkReadAction(for message: PWInboxMessageProtocol) {
        guard !message.isRead else { return }
        facade.read(messages: [message])
        // facade.read goes through PWInboxStorage.updateStatus(.read) which
        // mutates the same message ref the data source holds. The reload
        // here just redraws the row with the new isRead state.
        if let indexPath = indexPath(for: message) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func indexPath(for message: PWInboxMessageProtocol) -> IndexPath? {
        guard let code = message.code,
              let row = dataSource.messages.firstIndex(where: { $0.code == code })
        else { return nil }
        return IndexPath(row: row, section: 0)
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let message = dataSource.message(at: indexPath) else { return }
        delegate?.inboxKit(self, willDisplay: message, at: indexPath)
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let message = dataSource.message(at: indexPath) else { return }
        let shouldPerformDefault = delegate?.inboxKit(self, didSelect: message) ?? true
        if shouldPerformDefault {
            let wasUnread = !message.isRead
            facade.performAction(message: message)
            facade.read(messages: [message])
            if wasUnread {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
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
            let shouldDelete = self.delegate?.inboxKit(self, shouldDelete: message) ?? true
            if !shouldDelete {
                completion(false)
                return
            }
            self.facade.delete(messages: [message])
            _ = self.dataSource.remove(at: indexPath)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateStates()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
}
#endif
