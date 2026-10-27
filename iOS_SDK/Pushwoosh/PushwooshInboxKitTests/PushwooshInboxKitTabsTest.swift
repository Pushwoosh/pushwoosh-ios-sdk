//  PushwooshInboxKitTabsTest.swift
//  Created by André Kis

import XCTest
import UIKit
import PushwooshCore
@testable import PushwooshInboxKit

class PushwooshInboxKitTabsTest: XCTestCase, InboxScreenTesting {

    var sut: PushwooshInboxKitViewController!
    var facade: TestableInboxFacade!
    var delegate: SpyInboxDelegate!
    var window: UIWindow?

    override func setUp() {
        super.setUp()
        facade = TestableInboxFacade()
        delegate = SpyInboxDelegate()
        sut = PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
        sut.facade = facade
        sut.delegate = delegate
        sut.loadViewIfNeeded()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        sut = nil
        facade = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: - SDK-1094: a load error no longer wipes the cached feed

    /// Verifies that an offline load keeps the cached feed on screen instead of the full-screen error.
    func testCachedMessagesSurviveALoadError() {
        facade.outcome = .loaded([FakeMessage(code: "c1")], NSError(domain: "pw", code: -1009))
        loadAndWait()
        XCTAssertFalse(sut.tableView.isHidden)
        XCTAssertTrue(sut.errorStateLabel.isHidden)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 1)
    }

    /// Verifies that an error with nothing cached still shows the full-screen error.
    func testEmptyInboxWithErrorShowsFullScreenError() {
        facade.outcome = .loaded([], NSError(domain: "pw", code: -1009))
        loadAndWait()
        XCTAssertFalse(sut.errorStateLabel.isHidden)
        XCTAssertTrue(sut.tableView.isHidden)
    }

    /// Verifies that the delegate still receives the error on a load that returned cached messages.
    func testDelegateStillSeesTheError() {
        facade.outcome = .loaded([FakeMessage(code: "c1")], NSError(domain: "pw", code: -1009))
        loadAndWait()
        XCTAssertNotNil(delegate.didRefreshCalls.last?.1)
    }

    // MARK: - SDK-1094: InboxDataSource splits the full list from the filtered view

    /// Verifies that the table shows only the selected tab's messages while All shows everything.
    func testFilterBySelectedTab() {
        let ds = InboxDataSource()
        ds.replace([FakeMessage(code: "a", tabId: "t1"),
                    FakeMessage(code: "b", tabId: "t2"),
                    FakeMessage(code: "c", tabId: nil)], transform: { $0 })
        XCTAssertEqual(ds.count, 3)
        ds.selectedTabId = "t1"
        XCTAssertEqual(ds.messages.map { $0.code }, ["a"])
        ds.selectedTabId = nil
        XCTAssertEqual(ds.count, 3)
        XCTAssertEqual(ds.allMessages.count, 3)
    }

    /// Verifies that a message tagged with an id absent from the tab list shows only under All.
    func testUnknownTabIdShowsOnlyUnderAll() {
        let ds = InboxDataSource()
        ds.replace([FakeMessage(code: "a", tabId: "deleted-tab")], transform: { $0 })
        ds.selectedTabId = "t1"
        XCTAssertEqual(ds.count, 0)
        ds.selectedTabId = nil
        XCTAssertEqual(ds.count, 1)
    }

    /// Verifies that a merge update keeps the tab filter and adds a message pushed into the selected tab.
    func testMergeUpdateKeepsTheSelectedTabFilter() {
        let ds = InboxDataSource()
        ds.replace([FakeMessage(code: "a", tabId: "t1"), FakeMessage(code: "b", tabId: "t2")], transform: { $0 })
        ds.selectedTabId = "t1"

        ds.update([FakeMessage(code: "c", tabId: "t1"), FakeMessage(code: "d", tabId: "t2")], transform: { $0 })

        XCTAssertEqual(ds.messages.map { $0.code }.sorted(), ["a", "c"])
        XCTAssertEqual(ds.allMessages.count, 4)
        XCTAssertEqual(ds.unreadCount(forTabId: "t2"), 2)
    }

    /// Verifies that removing a filtered row drops the message from the full list too.
    func testRemoveDropsFromTheFullList() {
        let ds = InboxDataSource()
        ds.replace([FakeMessage(code: "a", tabId: "t1"), FakeMessage(code: "b", tabId: "t2")], transform: { $0 })
        ds.selectedTabId = "t1"
        _ = ds.remove(at: IndexPath(row: 0, section: 0))
        ds.selectedTabId = nil
        XCTAssertEqual(ds.allMessages.map { $0.code }, ["b"])
    }

    /// Verifies that deleting a message with no code drops it from the full list, not just the filtered view.
    func testRemoveWithoutACodeDropsFromTheFullList() {
        let ds = InboxDataSource()
        ds.replace([CodelessMessage(tabId: "t1"), FakeMessage(code: "b", tabId: "t2")], transform: { $0 })
        ds.selectedTabId = "t1"
        _ = ds.remove(at: IndexPath(row: 0, section: 0))
        ds.selectedTabId = nil
        XCTAssertEqual(ds.count, 1)
        XCTAssertEqual(ds.allMessages.first?.code, "b")
    }

    /// Verifies the per-tab and across-all unread counts.
    func testUnreadCounts() {
        let ds = InboxDataSource()
        ds.replace([FakeMessage(code: "a", tabId: "t1", isRead: false),
                    FakeMessage(code: "b", tabId: "t1", isRead: true),
                    FakeMessage(code: "c", tabId: "t2", isRead: false),
                    FakeMessage(code: "d", tabId: nil, isRead: false)], transform: { $0 })
        XCTAssertEqual(ds.unreadCount(forTabId: "t1"), 1)
        XCTAssertEqual(ds.unreadCount(forTabId: "t2"), 1)
        XCTAssertEqual(ds.unreadCount(forTabId: nil), 3)
        XCTAssertEqual(ds.unreadCount(forTabId: "missing"), 0)
    }

    /// Verifies that the delegate receives the whole inbox while a tab the reload keeps is selected.
    func testDelegateReceivesFullListWhileFiltered() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1"),
                                   FakeMessage(code: "b", tabId: "t2"),
                                   FakeMessage(code: "c", tabId: nil)], nil)
        loadAndWait()
        selectTab(atIndex: 1)
        XCTAssertEqual(sut.dataSource.selectedTabId, "t1")

        loadAndWait()

        XCTAssertEqual(sut.dataSource.selectedTabId, "t1")
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 1)
        XCTAssertEqual(delegate.didRefreshCalls.last?.0, 3)
    }

    /// Verifies that a swipe-deleted message stays gone after switching to All and back.
    func testSwipeDeletedMessageDoesNotComeBack() {
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1"), FakeMessage(code: "b", tabId: "t2")], nil)
        loadAndWait()
        sut.dataSource.selectedTabId = "t1"
        sut.tableView.reloadData()

        let cfg = sut.tableView(sut.tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))
        guard let action = cfg?.actions.first else {
            return XCTFail("the swipe action was not built")
        }
        let exp = expectation(description: "delete")
        action.handler(action, sut.tableView) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        sut.dataSource.selectedTabId = nil
        XCTAssertEqual(sut.dataSource.count, 1)
        sut.dataSource.selectedTabId = "t1"
        XCTAssertEqual(sut.dataSource.count, 0)
        XCTAssertEqual(facade.deleteCalls.count, 1)
    }

    // MARK: - SDK-1094: the tab strip

    /// Verifies that an inbox with no tabs renders no strip and leaves the table at the top of the view.
    func testNoTabsNoStrip() {
        facade.stubbedTabs = nil
        facade.outcome = .loaded([FakeMessage(code: "a")], nil)
        loadAndWait()
        XCTAssertNil(sut.view.subviews.first { $0 is InboxTabBarView })
    }

    /// Verifies that All comes first with the server's all-title, followed by the tabs in list order, All selected.
    func testStripOrderAndInitialSelection() {
        facade.stubbedTabs = tabs(allTitle: "All", [("a1b2c3", "Bills"), ("d4e5f6", "Promos")])
        facade.outcome = .loaded([], nil)
        loadAndWait()
        XCTAssertEqual(sut.tabBarForTesting?.buttonTitles, ["All", "Bills", "Promos"])
        XCTAssertNil(sut.dataSource.selectedTabId)
    }

    /// Verifies that selecting a tab filters the table and that All restores every row.
    func testSelectingATabFiltersTheTable() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1"),
                                   FakeMessage(code: "b", tabId: "t2"),
                                   FakeMessage(code: "c", tabId: "t2")], nil)
        loadAndWait()

        selectTab(atIndex: 1)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 1)

        selectTab(atIndex: 0)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 3)
    }

    /// Verifies that each tab, All included, shows its unread count and hides it at zero.
    func testUnreadBadges() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1", isRead: false),
                                   FakeMessage(code: "b", tabId: "t1", isRead: false),
                                   FakeMessage(code: "c", tabId: "t2", isRead: true)], nil)
        loadAndWait()

        let buttons = sut.tabBarForTesting?.buttons ?? []
        XCTAssertEqual(buttons.map { $0.title(for: .normal) }, ["All 2", "Tab One 2", "Tab Two"])
    }

    /// Verifies that reading a message through its own open action (not tab selection) refreshes both its tab's and All's badge.
    func testReadingAMessageThroughItsOwnActionRefreshesBadges() {
        let message = FakeMessage(code: "a", tabId: "t1", isRead: false)
        message.actionParams = ["l": "https://example.com"]
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded([message], nil)
        loadAndWait()
        selectTab(atIndex: 1)
        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) }, ["All 1", "Tab One 1"])

        sut.tableView(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        waitAFrame()

        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) }, ["All", "Tab One"])
    }

    /// Verifies that auto-reading a freshly selected tab's visible rows clears its badge and the one on All.
    func testAutoReadOfVisibleRowsRefreshesBadges() {
        sut.attributes.transform = { $0 }
        let readFeed = (0..<40).map { FakeMessage(code: "read\($0)", isRead: true) }
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded(readFeed + [FakeMessage(code: "a", tabId: "t1", isRead: false),
                                             FakeMessage(code: "b", tabId: "t1", isRead: false)], nil)
        loadAndWait()
        hostInWindow()
        waitAFrame()
        XCTAssertTrue(facade.readCalls.isEmpty)
        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) }, ["All 2", "Tab One 2"])

        selectTab(atIndex: 1)

        XCTAssertEqual(facade.readCalls.flatMap { $0 }.map { $0.code }.sorted(), ["a", "b"])
        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) }, ["All", "Tab One"])
    }

    /// Verifies that switching tabs reads the newly visible rows, and does not when automaticReadOnDisplay is off.
    func testSwitchingTabsReadsVisibleRows() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1", isRead: false)], nil)
        loadAndWait()
        hostInWindow()

        selectTab(atIndex: 1)
        XCTAssertEqual(facade.readCalls.flatMap { $0 }.map { $0.code }, ["a"])

        var offAttributes = PushwooshInboxKitAttributes()
        offAttributes.automaticReadOnDisplay = false
        let offFacade = TestableInboxFacade()
        offFacade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        offFacade.outcome = .loaded([FakeMessage(code: "b", tabId: "t1", isRead: false)], nil)
        let offSut = PushwooshInboxKitViewController(attributes: offAttributes)
        offSut.facade = offFacade
        offSut.loadViewIfNeeded()
        offSut.reloadData()
        waitAFrame()
        let offWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        offWindow.rootViewController = offSut
        offWindow.makeKeyAndVisible()
        offSut.view.layoutIfNeeded()

        offSut.tabBarForTesting?.simulateTap(atIndex: 1)
        waitAFrame()
        XCTAssertTrue(offFacade.readCalls.isEmpty)
        offWindow.isHidden = true
    }

    /// Verifies that a provisional table frame taller than the window reads only the rows inside the window.
    func testProvisionalOversizedFrameReadsOnlyRowsInsideTheWindow() {
        sut.attributes.transform = { $0 }
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded([FakeMessage(code: "onScreen", isRead: false)]
                                 + (0..<30).map { FakeMessage(code: "read\($0)", isRead: true) }
                                 + [FakeMessage(code: "belowTheFold", tabId: "t1", isRead: false)], nil)
        loadAndWait()
        hostInWindow()
        waitAFrame()
        XCTAssertEqual(facade.readCalls.flatMap { $0 }.map { $0.code }, ["onScreen"])

        sut.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 4000)
        sut.markDisplayedAsRead()

        XCTAssertEqual(facade.readCalls.flatMap { $0 }.map { $0.code }, ["onScreen"],
                       "a row 30 positions below the fold was read while nobody could see it")
        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) }, ["All 1", "Tab One 1"])
    }

    /// Verifies that the first message to land in an empty selected tab is read.
    func testFirstMessageLandingInAnEmptyTabIsRead() {
        let other = FakeMessage(code: "other", isRead: false)
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded([other], nil)
        loadAndWait()
        hostInWindow()
        selectTab(atIndex: 1)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 0,
                       "the selected tab must be empty for this test to mean anything")

        facade.outcome = .loaded([other, FakeMessage(code: "first", tabId: "t1", isRead: false)], nil)
        sut.loadMessages(mode: .replace)
        waitAFrame()

        XCTAssertTrue(facade.readCalls.flatMap { $0 }.contains { $0.code == "first" },
                      "the first message in the tab the user is watching stayed unread")
    }

    /// Verifies that the first load of a fresh screen with cached tabs reads one screen when the sync reports its new messages before the completion.
    func testFirstLoadAnnouncingNewMessagesReadsOneScreen() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.announcesLoadedMessages = true
        facade.outcome = .loaded((0..<30).map { FakeMessage(code: "m\($0)", sendDate: Date(timeIntervalSince1970: 2_000_000 - Double($0))) }, nil)
        sut = PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
        sut.facade = facade

        hostInWindow()
        waitAFrame()

        let read = facade.readCalls.flatMap { $0 }.map { $0.code }
        let onScreen = sut.tableView.indexPathsForVisibleRows?.count ?? 0
        XCTAssertFalse(read.isEmpty)
        XCTAssertLessThanOrEqual(read.count, onScreen, "the first load read \(read.count) messages while \(onScreen) rows fit the screen")
    }

    /// Verifies that an inbox loaded off-window before its host shows it reads the top screen, and only that, on appearance.
    func testInboxPreloadedOffWindowReadsOneScreenWhenShown() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded(unreadFeed(count: 30), nil)
        loadAndWait()
        XCTAssertTrue(facade.readCalls.isEmpty)

        hostInWindow()
        waitAFrame()

        let read = facade.readCalls.flatMap { $0 }.compactMap { $0.code }
        let onScreen = sut.tableView.indexPathsForVisibleRows?.count ?? 0
        XCTAssertTrue(read.contains("m0"), "the newest message on top of the screen stayed unread: \(read)")
        XCTAssertLessThanOrEqual(read.count, onScreen, "the preloaded inbox read \(read.count) messages while \(onScreen) rows fit the screen: \(read)")
    }

    /// Verifies that a refresh bringing nothing new reads nothing after a visit to an empty tab and a switch back.
    func testRefreshAfterReturningFromAnEmptyTabReadsNothingNew() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded(unreadFeed(count: 30, tabId: "t1"), nil)
        hostInWindow()
        waitAFrame()
        XCTAssertFalse(facade.readCalls.isEmpty)

        selectTab(atIndex: 2)
        loadAndWait()
        selectTab(atIndex: 1)
        let readAfterSwitch = facade.readCalls.flatMap { $0 }.count
        loadAndWait()

        XCTAssertEqual(facade.readCalls.flatMap { $0 }.count, readAfterSwitch,
                       "a refresh that brought nothing read the rows the unread-first sort lifted into view")
    }

    /// Verifies that an inbox shown empty and filled while its host showed another screen reads one screen when shown again.
    func testInboxFilledWhileHiddenReadsOneScreenWhenShownAgain() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        hostInWindow()
        waitAFrame()
        window?.rootViewController = UIViewController()
        waitAFrame()

        let feed = unreadFeed(count: 30, tabId: "t1")
        facade.outcome = .loaded(feed, nil)
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox"),
            object: nil,
            userInfo: ["messagesAdded": feed, "messagesDeleted": [], "messagesUpdated": []]
        )
        waitPastRefreshDebounce()
        XCTAssertTrue(facade.readCalls.isEmpty)

        window?.rootViewController = sut
        waitAFrame()

        let read = facade.readCalls.flatMap { $0 }.compactMap { $0.code }
        let onScreen = sut.tableView.indexPathsForVisibleRows?.count ?? 0
        XCTAssertTrue(read.contains("m0"), "the newest message on top of the screen stayed unread: \(read)")
        XCTAssertLessThanOrEqual(read.count, onScreen, "the re-shown inbox read \(read.count) messages while \(onScreen) rows fit the screen: \(read)")
    }

    /// Verifies that a selected tab missing from the next list falls back to All.
    func testVanishedSelectedTabFallsBackToAll() {
        facade.stubbedTabs = tabs(allTitle: "All", [("a1b2c3", "Invoices"), ("d4e5f6", "Promos")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "d4e5f6")], nil)
        loadAndWait()
        selectTab(atIndex: 2)
        XCTAssertEqual(sut.dataSource.selectedTabId, "d4e5f6")

        facade.stubbedTabs = tabs(allTitle: "All", [("a1b2c3", "Invoices")])
        loadAndWait()

        XCTAssertNil(sut.dataSource.selectedTabId)
        XCTAssertEqual(sut.tabBarForTesting?.buttonTitles.count, 2)
    }

    /// Verifies that a vanished tab list, nil or empty, clears the selection and the filter.
    func testVanishedTabListFallsBackToAll() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1"), FakeMessage(code: "b", tabId: "t2")], nil)
        loadAndWait()
        selectTab(atIndex: 2)
        XCTAssertEqual(sut.dataSource.selectedTabId, "t2")

        facade.stubbedTabs = nil
        loadAndWait()

        XCTAssertNil(sut.dataSource.selectedTabId)
        XCTAssertNil(sut.tabBarForTesting)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 2)

        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        loadAndWait()
        selectTab(atIndex: 2)
        XCTAssertEqual(sut.dataSource.selectedTabId, "t2")

        facade.stubbedTabs = PWInboxTabs(allTitle: "All", tabs: [])
        loadAndWait()

        XCTAssertNil(sut.dataSource.selectedTabId)
        XCTAssertNil(sut.tabBarForTesting)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 2)
    }

    /// Verifies that the selection indicator keeps tracking its title when the strip scrolls.
    func testSelectionIndicatorScrollsWithTheTitles() throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 160, height: 100))
        let strip = InboxTabBarView()
        host.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            strip.topAnchor.constraint(equalTo: host.topAnchor)
        ])
        strip.configure(tabs: tabs(allTitle: "Everything",
                                   [("t1", "The first long tab"),
                                    ("t2", "The second long tab"),
                                    ("t3", "The third long tab")]),
                        selectedTabId: nil,
                        style: PushwooshInboxKitAttributes().style)
        strip.simulateTap(atIndex: 2)
        host.layoutIfNeeded()

        let indicator = strip.selectionIndicatorForTesting
        let scrollView = try XCTUnwrap(indicator.superview as? UIScrollView)
        let button = strip.buttons[2]
        XCTAssertEqual(indicator.convert(indicator.bounds, to: host).minX,
                       button.convert(button.bounds, to: host).minX,
                       accuracy: 0.5)

        scrollView.contentOffset = CGPoint(x: 40, y: 0)
        host.layoutIfNeeded()
        XCTAssertEqual(indicator.convert(indicator.bounds, to: host).minX,
                       button.convert(button.bounds, to: host).minX,
                       accuracy: 0.5)
    }

    /// Verifies that a tab list already in the client's cache renders before any load completion has run.
    func testCachedTabsRenderBeforeTheFirstLoadCompletes() {
        let cachedFacade = TestableInboxFacade()
        cachedFacade.stubbedTabs = tabs(allTitle: "All", [("a1b2c3", "Bills"), ("d4e5f6", "Promos")])
        let offline = PushwooshInboxKitViewController(attributes: PushwooshInboxKitAttributes())
        offline.facade = cachedFacade

        offline.loadViewIfNeeded()

        XCTAssertEqual(cachedFacade.loadCallCount, 0)
        XCTAssertEqual(offline.tabBarForTesting?.buttonTitles, ["All", "Bills", "Promos"])
    }

    /// Verifies that the strip's buttons render in the style's title font, as the cards and the banner do.
    func testStripButtonsUseTheStyleTitleFont() {
        var style = PushwooshInboxKitAttributes().style
        style.titleFont = .monospacedSystemFont(ofSize: 19, weight: .bold)
        let strip = InboxTabBarView()

        strip.configure(tabs: tabs(allTitle: "All", [("t1", "Tab One")]), selectedTabId: nil, style: style)

        XCTAssertEqual(strip.buttons.compactMap { $0.titleLabel?.font }, [style.titleFont, style.titleFont])
    }

    /// Verifies that an unchanged tab list does not rebuild the strip.
    func testEqualTabListDoesNotRebuildTheStrip() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([], nil)
        loadAndWait()
        let identities = sut.tabBarForTesting?.buttons.map { ObjectIdentifier($0) }

        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        loadAndWait()

        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { ObjectIdentifier($0) }, identities)
    }

    /// Verifies that a renamed tab keeping its id rebuilds the strip and keeps the selection.
    func testRenamedTabKeepsSelection() {
        facade.stubbedTabs = tabs(allTitle: "All", [("a1b2c3", "Bills")])
        facade.outcome = .loaded([], nil)
        loadAndWait()
        selectTab(atIndex: 1)
        XCTAssertEqual(sut.dataSource.selectedTabId, "a1b2c3")

        facade.stubbedTabs = tabs(allTitle: "All", [("a1b2c3", "Invoices")])
        loadAndWait()

        XCTAssertEqual(sut.tabBarForTesting?.buttonTitles, ["All", "Invoices"])
        XCTAssertEqual(sut.dataSource.selectedTabId, "a1b2c3")
    }

    /// Verifies that an empty tab shows the empty-state label while the strip stays visible.
    func testEmptyTabShowsEmptyStateWithStripVisible() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1")], nil)
        loadAndWait()

        selectTab(atIndex: 2)

        XCTAssertFalse(sut.emptyStateLabel.isHidden)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 0)
        XCTAssertNotNil(sut.tabBarForTesting)
        XCTAssertFalse(sut.tabBarForTesting!.isHidden)
    }

    /// Verifies that an empty tab of a non-empty inbox keeps the table and its refresh control on screen.
    func testEmptyTabKeepsTheTableAndItsRefreshControlReachable() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1")], nil)
        loadAndWait()

        selectTab(atIndex: 2)

        XCTAssertFalse(sut.tableView.isHidden)
        XCTAssertNotNil(sut.tableView.refreshControl)
        XCTAssertFalse(sut.emptyStateLabel.isHidden)

        facade.outcome = .loaded([], nil)
        sut.loadMessages(mode: .replace)
        waitAFrame()

        XCTAssertTrue(sut.tableView.isHidden)
    }

    /// Verifies that a message object without a tabId selector does not crash the screen and shows only under All.
    func testObjCMessageWithoutTabIdSelector() {
        let legacy = LegacyObjCMessage(code: "legacy")
        sut.attributes.transform = { messages in messages + [legacy] }
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1")], nil)
        loadAndWait()

        XCTAssertFalse(sut.tableView.isHidden)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 2)

        selectTab(atIndex: 1)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 1)
    }

    // MARK: - SDK-1094: the bottom error banner

    /// Verifies that an error on an empty tab of a non-empty inbox shows the banner plus the empty label, not the full-screen error.
    func testErrorOnEmptyTabShowsBannerAndEmptyLabel() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "T1"), ("t2", "T2")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1")], nil)
        loadAndWait()
        selectTab(atIndex: 2)                                  // t2 — empty
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1")], NSError(domain: "pw", code: -1009))
        sut.reloadData(); waitAFrame()
        XCTAssertTrue(sut.errorBannerForTesting.isShowing)
        XCTAssertFalse(sut.errorBannerForTesting.isHidden)
        XCTAssertTrue(sut.view.subviews.contains(sut.errorBannerForTesting))
        XCTAssertFalse(sut.emptyStateLabel.isHidden)
        XCTAssertTrue(sut.errorStateLabel.isHidden)
    }

    /// Verifies that the banner shows the host's custom error message when set, and the error's own description when the host blanks it.
    func testBannerTextSource() {
        facade.outcome = .loaded([FakeMessage(code: "a")], nil)
        loadAndWait()

        let customError = NSError(domain: "pw", code: -1009, userInfo: [NSLocalizedDescriptionKey: "The request timed out."])

        sut.attributes.errorMessage = "Oops"
        facade.outcome = .loaded([FakeMessage(code: "a")], customError)
        sut.reloadData(); waitAFrame()
        XCTAssertEqual(sut.errorBannerForTesting.text, "Oops")

        sut.attributes.errorMessage = ""
        facade.outcome = .loaded([FakeMessage(code: "a")], customError)
        sut.reloadData(); waitAFrame()
        XCTAssertEqual(sut.errorBannerForTesting.text, "The request timed out.")
    }

    /// Verifies that a tap over the banner reaches the row underneath, which then reports its open.
    func testBannerLetsTapsThroughToTheRowUnderneath() throws {
        delegate.didSelectReturn = false
        facade.outcome = .loaded((0..<10).map { FakeMessage(code: "c\($0)") },
                                 NSError(domain: "pw", code: -1009))
        loadAndWait()
        hostInWindow()
        sut.view.layoutIfNeeded()
        let banner = sut.errorBannerForTesting
        XCTAssertTrue(banner.isShowing)

        let point = banner.convert(CGPoint(x: banner.bounds.midX, y: banner.bounds.midY), to: sut.view)
        let hit = try XCTUnwrap(sut.view.hitTest(point, with: nil))
        XCTAssertFalse(hit.isDescendant(of: banner))
        XCTAssertTrue(hit.isDescendant(of: sut.tableView))

        let indexPath = try XCTUnwrap(sut.tableView.indexPathForRow(at: sut.tableView.convert(point, from: sut.view)))
        sut.tableView(sut.tableView, didSelectRowAt: indexPath)
        XCTAssertEqual(delegate.didSelectCalls.map { $0.code },
                       [sut.dataSource.message(at: indexPath)?.code])
    }

    /// Verifies that an error with a completely empty inbox shows the full-screen error and no banner.
    func testEmptyInboxErrorKeepsFullScreenError() {
        facade.outcome = .loaded([], NSError(domain: "pw", code: -1009))
        loadAndWait()
        XCTAssertFalse(sut.errorStateLabel.isHidden)
        XCTAssertFalse(sut.errorBannerForTesting.isShowing)
    }

    /// Verifies that a successful refresh leaves no banner behind after a prior error showed one.
    func testSuccessfulRefreshHidesTheBanner() {
        facade.outcome = .loaded([FakeMessage(code: "a")], NSError(domain: "pw", code: -1009))
        loadAndWait()
        XCTAssertTrue(sut.errorBannerForTesting.isShowing)

        facade.outcome = .loaded([FakeMessage(code: "a")], nil)
        sut.reloadData(); waitAFrame()
        XCTAssertFalse(sut.errorBannerForTesting.isShowing)
    }

    /// Verifies that a state recomputation long after a failed refresh does not bring the banner back.
    func testStaleRefreshErrorDoesNotReviveTheBanner() {
        facade.outcome = .loaded([FakeMessage(code: "a")], NSError(domain: "pw", code: -1009))
        loadAndWait()
        XCTAssertTrue(sut.errorBannerForTesting.isShowing)
        sut.errorBannerForTesting.hide()

        sut.traitCollectionDidChange(nil)
        XCTAssertFalse(sut.errorBannerForTesting.isShowing)

        sut.attributes.errorMessage = "Offline"
        XCTAssertFalse(sut.errorBannerForTesting.isShowing)
        XCTAssertTrue(sut.errorBannerForTesting.isHidden)
    }

    // MARK: - SDK-1094: Liquid Glass across the whole screen

#if compiler(>=6.2)
    /// Verifies that the strip, its selection indicator and the banner render as glass when the flag is on under iOS 26.
    func testGlassSurfacesWhenEnabled() throws {
        guard #available(iOS 26.0, *) else { return }
        var attributes = PushwooshInboxKitAttributes()
        attributes.style.isLiquidGlass = true
        sut = PushwooshInboxKitViewController(attributes: attributes)
        sut.facade = facade
        sut.delegate = delegate
        sut.loadViewIfNeeded()

        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "T1")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1")], NSError(domain: "pw", code: -1009))
        loadAndWait()
        hostInWindow()
        sut.view.layoutIfNeeded()

        let strip = try XCTUnwrap(sut.tabBarForTesting)
        let container = try XCTUnwrap(effectViews(in: strip).first { $0.effect is UIGlassContainerEffect })
        let glass = try XCTUnwrap(effectViews(in: container.contentView).first { $0.effect is UIGlassEffect },
                                  "the strip has a glass container but no glass in it")
        XCTAssertEqual(glass.frame, container.contentView.bounds, "the glass does not cover the strip")
        XCTAssertGreaterThan(glass.frame.height, 0)
        let indicator = try XCTUnwrap(strip.selectionIndicatorForTesting as? UIVisualEffectView,
                                      "the selected tab's indicator is not a glass element")
        let indicatorGlass = try XCTUnwrap(indicator.effect as? UIGlassEffect)
        XCTAssertEqual(indicatorGlass.tintColor, sut.attributes.style.unreadBadgeColor)
        XCTAssertTrue(indicator.isDescendant(of: container.contentView), "the indicator is outside the strip's glass container")
        XCTAssertTrue(sut.errorBannerForTesting.effectForTesting is UIGlassEffect)
    }
#endif

    /// Verifies that a default-configured inbox installs no state plate.
    func testNoStatePlateWithDefaultAttributes() {
        facade.outcome = .loaded([], nil)
        loadAndWait()
        XCTAssertFalse(sut.emptyStateLabel.isHidden)
        XCTAssertFalse(containsStatePlate(sut.view))
    }

    /// Verifies that turning the Liquid Glass flag on installs the plates behind both state labels.
    func testStatePlatesInstalledWhenGlassEnabled() {
        var attributes = PushwooshInboxKitAttributes()
        attributes.style.isLiquidGlass = true
        let glassSut = PushwooshInboxKitViewController(attributes: attributes)
        glassSut.facade = facade
        glassSut.loadViewIfNeeded()
        XCTAssertEqual(glassSut.view.subviews.filter { $0 is InboxStatePlateView }.count, 2)
    }

    /// Verifies that the strip and its selection indicator are flat fills with no blur when the flag is off.
    func testFlatSurfacesWhenDisabled() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "T1")])
        loadAndWait()
        XCTAssertNil(sut.tabBarForTesting?.effectForTesting)
        XCTAssertEqual(sut.tabBarForTesting?.backgroundColor, sut.attributes.style.backgroundColor)
        let indicator = sut.tabBarForTesting?.selectionIndicatorForTesting
        XCTAssertNil((indicator as? UIVisualEffectView)?.effect)
        XCTAssertEqual(indicator?.backgroundColor, sut.attributes.style.unreadBadgeColor)
    }

    // MARK: - SDK-1094: a tab switch opens the new feed at the top

    /// Verifies that switching tabs opens the new tab at its first row.
    func testSwitchingTabsOpensTheNewTabAtTheTop() {
        sut.attributes.transform = { $0 }
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded((0..<30).map { FakeMessage(code: "filler\($0)", isRead: true) }
                                 + (0..<20).map { FakeMessage(code: "t1-\($0)", tabId: "t1", isRead: false) }, nil)
        loadAndWait()
        hostInWindow()
        waitAFrame()

        sut.tableView.setContentOffset(CGPoint(x: 0, y: sut.tableView.contentSize.height), animated: false)
        sut.tableView.layoutIfNeeded()

        selectTab(atIndex: 1)

        XCTAssertEqual(sut.tableView.contentOffset.y, -sut.tableView.adjustedContentInset.top, accuracy: 0.5)
        let read = facade.readCalls.flatMap { $0 }.map { $0.code }
        XCTAssertTrue(read.contains("t1-0"), "the tab opened somewhere other than its first row")
        XCTAssertFalse(read.contains("t1-19"), "a row at the bottom of the tab was read without ever being shown")
    }

    /// Verifies that a selected tab vanishing from the list puts the unfiltered feed back at the top.
    func testVanishedSelectedTabReturnsTheFeedToTheTop() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded((0..<30).map { FakeMessage(code: "a\($0)", tabId: "t2", isRead: true) }, nil)
        loadAndWait()
        hostInWindow()
        selectTab(atIndex: 2)
        sut.tableView.setContentOffset(CGPoint(x: 0, y: 300), animated: false)

        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        loadAndWait()

        XCTAssertNil(sut.dataSource.selectedTabId)
        XCTAssertEqual(sut.tableView.contentOffset.y, -sut.tableView.adjustedContentInset.top, accuracy: 0.5)
    }

    /// Verifies that removing the tab strip leaves the feed at its first row in the new geometry.
    func testRemovingTheTabStripReturnsTheFeedToTheTopOfTheNewGeometry() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One")])
        facade.outcome = .loaded((0..<30).map { FakeMessage(code: "a\($0)", tabId: "t1", isRead: true) }, nil)
        loadAndWait()
        hostInWindow()
        selectTab(atIndex: 1)
        sut.tableView.setContentOffset(CGPoint(x: 0, y: 300), animated: false)

        facade.stubbedTabs = nil
        loadAndWait()

        XCTAssertNil(sut.tabBarForTesting)
        XCTAssertEqual(sut.tableView.contentOffset.y, -sut.tableView.adjustedContentInset.top, accuracy: 0.5)
    }

    // MARK: - SDK-1094: the batch actions stay inbox-wide while a tab is selected

    /// Verifies that deleting everything while a tab is selected empties the whole inbox, not the tab.
    func testDeleteAllMessagesClearsEveryTabWhileATabIsSelected() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1"), FakeMessage(code: "b", tabId: "t2")], nil)
        loadAndWait()
        selectTab(atIndex: 1)

        sut.deleteAllMessages()

        XCTAssertEqual(facade.deleteCalls.flatMap { $0 }.map { $0.code }.sorted(), ["a", "b"])
        XCTAssertTrue(sut.dataSource.allMessages.isEmpty)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 0)
    }

    /// Verifies that clearing read messages with a tab selected drops the read rows of every tab.
    func testClearReadMessagesDropsReadRowsFromEveryTabWhileATabIsSelected() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1", isRead: true),
                                   FakeMessage(code: "b", tabId: "t2", isRead: true),
                                   FakeMessage(code: "c", tabId: "t1", isRead: false)], nil)
        loadAndWait()
        selectTab(atIndex: 1)

        sut.clearReadMessages()

        XCTAssertEqual(facade.deleteAllReadCallCount, 1)
        XCTAssertEqual(sut.dataSource.allMessages.map { $0.code }, ["c"])
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 1)
    }

    /// Verifies that marking everything read zeroes the badge of every tab, not of the selected one alone.
    func testMarkAllAsReadClearsTheBadgesOfEveryTab() {
        facade.stubbedTabs = tabs(allTitle: "All", [("t1", "Tab One"), ("t2", "Tab Two")])
        facade.outcome = .loaded([FakeMessage(code: "a", tabId: "t1", isRead: false),
                                   FakeMessage(code: "b", tabId: "t2", isRead: false)], nil)
        loadAndWait()
        selectTab(atIndex: 1)
        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) },
                       ["All 2", "Tab One 1", "Tab Two 1"])

        sut.markAllAsRead()

        XCTAssertEqual(facade.markAllAsReadCallCount, 1)
        XCTAssertEqual(sut.tabBarForTesting?.buttons.map { $0.title(for: .normal) },
                       ["All", "Tab One", "Tab Two"])
        XCTAssertEqual(sut.dataSource.unreadCount(forTabId: "t2"), 0)
    }

    // MARK: - Helpers

    /// Builds a `PWInboxTabs` fixture from `(identifier, title)` pairs, in the given order.
    private func tabs(allTitle: String, _ pairs: [(String, String)]) -> PWInboxTabs {
        PWInboxTabs(allTitle: allTitle, tabs: pairs.map { PWInboxTab(identifier: $0.0, title: $0.1) })
    }

    /// Taps the tab-strip button at `index` (0 is "All") and waits a frame for the selection to apply.
    private func selectTab(atIndex index: Int, file: StaticString = #filePath, line: UInt = #line) {
        guard let strip = sut.tabBarForTesting, strip.buttons.indices.contains(index) else {
            return XCTFail("no tab button at index \(index)", file: file, line: line)
        }
        strip.simulateTap(atIndex: index)
        waitAFrame()
    }

    /// Every `UIVisualEffectView` under `view`, including those nested in effect content views.
    private func effectViews(in view: UIView) -> [UIVisualEffectView] {
        view.subviews.flatMap { subview -> [UIVisualEffectView] in
            ((subview as? UIVisualEffectView).map { [$0] } ?? []) + effectViews(in: subview)
        }
    }

    /// True when any `InboxStatePlateView` is present anywhere under `view`.
    private func containsStatePlate(_ view: UIView) -> Bool {
        view.subviews.contains { $0 is InboxStatePlateView || containsStatePlate($0) }
    }
}

/// `PWInboxMessageProtocol` implementor with no `code` — a stored message whose payload carried no
/// inbox id, which deletion therefore cannot match by code.
private final class CodelessMessage: NSObject, PWInboxMessageProtocol {
    let code: String! = nil
    let title: String = "Codeless"
    let imageUrl: String? = nil
    let message: String = "Body"
    let sendDate: Date? = Date()
    let type: PWInboxMessageType = .plain
    let isRead: Bool = false
    let isActionPerformed: Bool = false
    let actionParams: [AnyHashable: Any]? = nil
    let attachmentUrl: String? = nil
    let tabId: String?

    init(tabId: String?) {
        self.tabId = tabId
    }
}

/// Stand-in for an Obj-C host class built against a pre-`tabId` SDK header: it conforms, but answers
/// `false` from `responds(to:)` for the `tabId` getter it never implemented.
private final class LegacyObjCMessage: NSObject, PWInboxMessageProtocol {
    let code: String
    let title: String = "Legacy"
    let imageUrl: String? = nil
    let message: String = "Body"
    let sendDate: Date? = Date()
    let type: PWInboxMessageType = .plain
    let isRead: Bool = false
    let isActionPerformed: Bool = false
    let actionParams: [AnyHashable: Any]? = nil
    let attachmentUrl: String? = nil
    var tabId: String? { nil }

    init(code: String) {
        self.code = code
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(getter: PWInboxMessageProtocol.tabId) {
            return false
        }
        return super.responds(to: aSelector)
    }
}

final class PWInboxFacadeLoadTest: XCTestCase {

    /// Verifies that the real facade hands a failed load's cached messages to the caller together with the error.
    func testLoadForwardsCachedMessagesTogetherWithTheError() {
        let savedBridge = PWManagerBridge.shared().inboxBridge
        defer { PWManagerBridge.shared().inboxBridge = savedBridge }
        PWManagerBridge.shared().inboxBridge = CachedFeedFailingInboxBridge.self
        CachedFeedFailingInboxBridge.messages = [FakeMessage(code: "c1"), FakeMessage(code: "c2")]
        CachedFeedFailingInboxBridge.error = NSError(domain: "pw", code: -1009)

        let loaded = expectation(description: "load")
        var result: InboxLoadResult?
        PWInboxFacade().loadMessages { loadResult in
            result = loadResult
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5.0)

        XCTAssertEqual(result?.messages.compactMap { $0.code }, ["c1", "c2"])
        XCTAssertEqual((result?.error as NSError?)?.code, -1009)
    }
}

/// `PWInboxBridge` double whose load answers like `PWInbox` offline: the cached messages plus the network error.
private final class CachedFeedFailingInboxBridge: NSObject, PWInboxBridge {
    static var messages: [PWInboxMessageProtocol] = []
    static var error: Error?

    static func isInboxPushNotification(_ userInfo: [AnyHashable: Any]) -> Bool { false }
    static func addInboxMessage(fromPushNotification userInfo: [AnyHashable: Any]) {}
    static func actionInboxMessage(fromPushNotification userInfo: [AnyHashable: Any]) {}
    static func resetApplication() {}
    static func updateInbox(forNewUserId completion: @escaping (UInt) -> Void) {}
    static func loadMessages(completion: (([PWInboxMessageProtocol]?, Error?) -> Void)?) {
        completion?(messages, error)
    }
    static func readMessages(withCodes codes: [String]) {}
    static func deleteMessages(withCodes codes: [String]) {}
    static func performActionForMessage(withCode code: String) {}
    static func reportActionForMessage(withCode code: String) {}
    static func markAllMessagesAsRead() {}
    static func deleteAllReadMessages() {}
}
