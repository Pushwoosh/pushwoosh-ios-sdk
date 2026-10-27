//  PWModulesSwiftApiTest.swift
//  Created by André Kis

import XCTest
import PushwooshCore
import PushwooshFramework

private final class InAppRecorder: NSObject {
    var events: [String] = []
    var reloads = 0
    var interfaceNames: [String] = []

    @objc(postEvent:withAttributes:completion:)
    func postEvent(_ event: String, withAttributes attributes: [AnyHashable: Any]?, completion: ((Error?) -> Void)?) {
        record(event)
        completion?(nil)
    }

    @objc(postEvent:withAttributes:)
    func postEvent(_ event: String, withAttributes attributes: [AnyHashable: Any]?) {
        record(event)
    }

    private func record(_ event: String) {
        if !event.hasPrefix("PW_") {
            events.append(event)
        }
    }

    @objc(reloadInAppsWithCompletion:)
    func reloadInApps(completion: ((Error?) -> Void)?) {
        reloads += 1
        completion?(nil)
    }

    @objc(addJavascriptInterface:withName:)
    func addJavascriptInterface(_ interface: NSObject, withName name: String) {
        interfaceNames.append(name)
    }
}

private final class UserRecorder: NSObject {
    var resets = 0

    @objc(resetUserIdWithCompletion:)
    func resetUserId(completion: ((Error?) -> Void)?) {
        resets += 1
        completion?(nil)
    }
}

private final class UnregisterRecorder: NSObject {
    var calls = 0
    var completions = 0

    @objc(unregisterForPushNotificationsWithCompletion:)
    func unregister(completion: ((Error?) -> Void)?) {
        calls += 1
        completion?(nil)
    }
}

private final class JavaScriptBridge: NSObject, PWJavaScriptInterface {}

class PWModulesSwiftApiTest: XCTestCase {

    private var recorder = InAppRecorder()
    private var originalInAppManager: PWInAppManager?
    private var userRecorder = UserRecorder()
    private var originalInAppMessagesManager: Any?

    override func setUp() {
        super.setUp()
        _ = Pushwoosh.configure
        originalInAppManager = PWManagerBridge.shared().inAppManager
        recorder = InAppRecorder()
        PWManagerBridge.shared().setValue(recorder, forKey: "inAppManager")
        originalInAppMessagesManager = PWManagerBridge.shared().value(forKey: "inAppMessagesManager")
        userRecorder = UserRecorder()
        PWManagerBridge.shared().setValue(userRecorder, forKey: "inAppMessagesManager")
        sdkState("resetForTesting")
        sdkState("setReady")
    }

    override func tearDown() {
        PWManagerBridge.shared().inAppManager = originalInAppManager
        PWManagerBridge.shared().setValue(originalInAppMessagesManager, forKey: "inAppMessagesManager")
        sdkState("resetForTesting")
        super.tearDown()
    }

    private func sdkState(_ selector: String) {
        guard let provider = (NSClassFromString("PWSdkStateProvider") as? NSObject.Type)?
            .perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject else {
            return XCTFail("PWSdkStateProvider is missing")
        }
        provider.perform(NSSelectorFromString(selector))
    }

    /// Verifies that the in-app calls of Pushwoosh.configure compile from a sync function and reach the in-app manager.
    func testInAppCallsFromSyncFunction() {
        Pushwoosh.configure.postEvent("plain")
        Pushwoosh.configure.postEvent("no_attributes", withAttributes: nil)
        Pushwoosh.configure.postEvent("with_completion", withAttributes: ["k": "v"]) { _ in }
        Pushwoosh.configure.reloadInApps { _ in }
        Pushwoosh.configure.addJavascriptInterface(JavaScriptBridge(), withName: "PushMart")

        XCTAssertEqual(recorder.events, ["plain", "no_attributes", "with_completion"])
        XCTAssertEqual(recorder.reloads, 1)
        XCTAssertEqual(recorder.interfaceNames, ["PushMart"])
    }

    /// Verifies that postEvent and reloadInApps resolve to their async variants inside an async function.
    func testInAppCallsFromAsyncFunction() async throws {
        try await Pushwoosh.configure.postEvent("async_plain")
        try await Pushwoosh.configure.postEvent("async_attributes", withAttributes: ["k": "v"])
        try await Pushwoosh.configure.reloadInApps()

        XCTAssertEqual(recorder.events, ["async_plain", "async_attributes"])
        XCTAssertEqual(recorder.reloads, 1)
    }

    /// Verifies that resetUserId compiles from a sync function, with and without a trailing closure, and reaches the manager.
    func testResetUserIdFromSyncFunction() {
        Pushwoosh.configure.resetUserId()
        Pushwoosh.configure.resetUserId { _ in }

        XCTAssertEqual(userRecorder.resets, 2)
    }

    /// Verifies that resetUserId resolves to its async variant inside an async function.
    func testResetUserIdFromAsyncFunction() async throws {
        try await Pushwoosh.configure.resetUserId()

        XCTAssertEqual(userRecorder.resets, 1)
    }

    /// Verifies that unregisterForPushNotifications with a trailing closure compiles from a sync function and runs the closure.
    func testUnregisterTrailingClosureFromSyncFunction() {
        let unregister = UnregisterRecorder()
        let original = swapPushManager(unregister)
        defer { swapPushManager(original) }

        Pushwoosh.configure.unregisterForPushNotifications { _ in unregister.completions += 1 }

        XCTAssertEqual(unregister.calls, 1)
        XCTAssertEqual(unregister.completions, 1)
    }

    /// Verifies that the trailing closure form of unregisterForPushNotifications also compiles inside an async function.
    func testUnregisterTrailingClosureFromAsyncFunction() async {
        let unregister = UnregisterRecorder()
        let original = swapPushManager(unregister)
        defer { swapPushManager(original) }

        Pushwoosh.configure.unregisterForPushNotifications { _ in unregister.completions += 1 }

        XCTAssertEqual(unregister.calls, 1)
        XCTAssertEqual(unregister.completions, 1)
    }

    @discardableResult
    private func swapPushManager(_ manager: Any?) -> Any? {
        let original = PWManagerBridge.shared().value(forKey: "pushNotificationManager")
        PWManagerBridge.shared().setValue(manager, forKey: "pushNotificationManager")
        return original
    }

    /// Verifies that legacyRichMedia.richMediaStyle writes and reads the style, and nil restores a default one.
    func testLegacyRichMediaStyle() {
        let original = Pushwoosh.media.legacyRichMedia.richMediaStyle
        let style = PWRichMediaStyle()
        Pushwoosh.media.legacyRichMedia.richMediaStyle = style
        Pushwoosh.media.legacyRichMedia.richMediaStyle.closeButtonPresentingDelay = 7

        XCTAssertTrue(Pushwoosh.media.legacyRichMedia.richMediaStyle === style)
        XCTAssertEqual(style.closeButtonPresentingDelay, 7)

        Pushwoosh.media.legacyRichMedia.richMediaStyle = nil

        XCTAssertFalse(Pushwoosh.media.legacyRichMedia.richMediaStyle === style)
        XCTAssertEqual(Pushwoosh.media.legacyRichMedia.richMediaStyle.closeButtonPresentingDelay,
                       PWRichMediaStyle().closeButtonPresentingDelay)

        Pushwoosh.media.legacyRichMedia.richMediaStyle = original
    }

    /// Verifies that Pushwoosh.inbox.loadMessages compiles from a sync function and returns the message stored by PWInbox.
    func testInboxLoadMessagesFromSyncFunction() throws {
        let code = try storeInboxMessage()
        var loaded: [String] = []
        var loadError: Error?

        Pushwoosh.inbox.loadMessages { messages, error in
            loaded = (messages ?? []).compactMap { $0.code }
            loadError = error
        }

        XCTAssertNil(loadError)
        XCTAssertEqual(loaded, [code])
    }

    /// Verifies that Pushwoosh.inbox.loadMessages resolves to its async variant inside an async function.
    func testInboxLoadMessagesFromAsyncFunction() async throws {
        let code = try storeInboxMessage()

        let messages: [PWInboxMessageProtocol] = try await Pushwoosh.inbox.loadMessages()

        XCTAssertEqual(messages.compactMap { $0.code }, [code])
    }

    /// Verifies that Pushwoosh.InboxKit builds the inbox screen when PushwooshInboxKit is linked.
    func testInboxKitMakesViewControllerWithModule() {
        XCTAssertNotNil(Pushwoosh.InboxKit.makeViewController())
    }

    /// Verifies that Pushwoosh.InboxKit returns nil instead of a screen when PushwooshInboxKit is not linked.
    func testInboxKitMakesNoViewControllerWithoutModule() throws {
        let registry = try XCTUnwrap(NSClassFromString("PushwooshModuleRegistry") as? NSObject.Type)
        let missingModule: AnyClass = try XCTUnwrap(NSClassFromString("PWMissingModule"))
        let register = NSSelectorFromString("registerClass:forIdentifier:")
        let linkedModule = registry.perform(NSSelectorFromString("classForIdentifier:"), with: "inboxKit")?.takeUnretainedValue()
        registry.perform(register, with: missingModule, with: "inboxKit")
        defer { registry.perform(register, with: linkedModule, with: "inboxKit") }

        XCTAssertNil(Pushwoosh.InboxKit.makeViewController())
    }

    private func storeInboxMessage() throws -> String {
        PWInbox.resetApplication()
        addTeardownBlock { PWInbox.resetApplication() }
        let inbox = try XCTUnwrap((PWInbox.self as AnyObject).perform(NSSelectorFromString("sharedInstance"))?
            .takeUnretainedValue() as? NSObject)
        let service = try XCTUnwrap(inbox.value(forKey: "service") as? NSObject)
        service.setValue(nil, forKey: "currentUserID")
        service.setValue(Date(), forKey: "lastRequestTime")
        let message = try XCTUnwrap(PWInboxMessageInternal.message(with: [
            "inbox_id": "swift-api-1", "order": 1, "rt": 2000000000, "send_date": 1700000000,
            "text": "text", "action_type": 0, "status": 1, "action_params": "{}"]))
        try XCTUnwrap(inbox.value(forKey: "storage") as? PWInboxStorage).addInboxMessage(fromPushNotification: message)
        return message.code
    }
}
