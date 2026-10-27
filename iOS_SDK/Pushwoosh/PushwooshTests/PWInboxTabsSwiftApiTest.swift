//  PWInboxTabsSwiftApiTest.swift
//  Created by André Kis

import XCTest
import PushwooshCore
import PushwooshFramework

class PWInboxTabsSwiftApiTest: XCTestCase {

    override func tearDown() {
        PWInboxStorage().updateTabs(fromPayload: nil)
        super.tearDown()
    }

    /// Verifies that the cached tab list reads back through Swift with the all-title and the tabs in server order.
    func testCachedTabsReadFromSwift() throws {
        PWInboxStorage().updateTabs(fromPayload: ["all_title": "All",
                                                  "tabs": [["id": "a1b2c3", "title": "Bills"],
                                                           ["id": "d4e5f6", "title": "Promos"]]])

        let tabs = try XCTUnwrap(PWInboxStorage().tabs())
        XCTAssertEqual(tabs.allTitle, "All")
        XCTAssertEqual(tabs.tabs.map { $0.identifier }, ["a1b2c3", "d4e5f6"])
        XCTAssertEqual(tabs.tabs.map { $0.title }, ["Bills", "Promos"])
    }

    /// Verifies that Pushwoosh.inbox.getTabs() imports into Swift as an optional PWInboxTabs and is nil after a reset.
    func testGetTabsReadsFromSwift() {
        PWInbox.resetApplication()
        let published: PWInboxTabs? = Pushwoosh.inbox.getTabs()
        XCTAssertNil(published)
    }

    /// Verifies that a message publishes its tab through tabId, and reads as nil when the payload carries no tab.
    func testMessageTabIdReadsFromSwift() throws {
        let tagged = try XCTUnwrap(PWInboxMessageInternal.message(with: [
            "inbox_id": "c1", "order": 1, "rt": 2000000000, "text": "text",
            "action_type": 1, "status": 1,
            "action_params": "{\"pw_inbox_tab\":\"a1b2c3\"}"]))
        XCTAssertEqual(tagged.tabId, "a1b2c3")

        let untagged = try XCTUnwrap(PWInboxMessageInternal.message(with: [
            "inbox_id": "c2", "order": 1, "rt": 2000000000, "text": "text",
            "action_type": 1, "status": 1,
            "action_params": "{}"]))
        XCTAssertNil(untagged.tabId)
    }
}
