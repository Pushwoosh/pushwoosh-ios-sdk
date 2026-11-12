//
//  PWInlineSlotViewTest.swift
//  PushwooshTests
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import XCTest
import AVFoundation
import WebKit
import PushwooshCore
import PushwooshBridge
@testable import PushwooshInApp

private final class PWAudioSessionRecorder: PWAudioSessionControl {
    enum Event: Equatable {
        case category(AVAudioSession.Category)
        case deactivation
    }

    private(set) var category: AVAudioSession.Category
    private(set) var mode: AVAudioSession.Mode = .default
    private(set) var categoryOptions: AVAudioSession.CategoryOptions = []
    private(set) var events: [Event] = []

    var categories: [AVAudioSession.Category] {
        events.compactMap { event in
            guard case .category(let category) = event else {
                return nil
            }
            return category
        }
    }

    var deactivations: Int {
        events.filter { $0 == .deactivation }.count
    }

    init(category: AVAudioSession.Category) {
        self.category = category
    }

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws {
        self.category = category
        self.mode = mode
        categoryOptions = options
        events.append(.category(category))
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if !active, options.contains(.notifyOthersOnDeactivation) {
            events.append(.deactivation)
        }
    }
}

private final class PWInlineHeightRecorder: NSObject, WKScriptMessageHandler {
    var heights: [CGFloat] = []
    var onHeight: (() -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let height = message.body as? NSNumber else {
            return
        }
        heights.append(CGFloat(height.doubleValue))
        onHeight?()
    }
}

class PWInlineSlotViewTest: XCTestCase {

    private var fileURL: URL!
    private var response: [String: Any] = [:]
    private var manager: PWInlineManager!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("banners.json")
        manager = makeManager(store: PWInlineStore(fileURL: fileURL))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    private var scheduled: [() -> Void] = []
    private var sent: [[String]] = []

    private func makeManager(store: PWInlineStore) -> PWInlineManager {
        PWInlineManager(store: store, scheduler: { [unowned self] _, work in self.scheduled.append(work) },
                        transport: { [unowned self] request, completion in
            self.sent.append(request.slots)
            request.parseResponse(self.response)
            completion(nil)
        }, eventSender: { _, completion in completion(nil) })
    }

    private let banner: [String: Any] = [
        "bannerId": "promo", "version": 1, "format": "native",
        "native": ["root": ["type": "stack", "padding": 16, "background": "#FFE8CC", "cornerRadius": 12, "children": [
            ["type": "text", "text": "Free shipping over $20", "size": 18, "weight": "bold"],
            ["type": "button", "title": "Shop now"],
        ]]],
    ]

    private let htmlBanner: [String: Any] = [
        "bannerId": "story", "version": 1, "format": "html",
        "html": "<html><body><h1>Autumn sale</h1><a href=\"https://example.com/sale\">Shop</a></body></html>",
    ]

    private struct Screen {
        let window: UIWindow
        let slot: UIView
        let below: UILabel
    }

    private func makeScreen(with slot: UIView) -> Screen {
        let above = UILabel()
        above.text = "Today's deals"
        let below = UILabel()
        below.text = "Recently viewed"
        let stack = UIStackView(arrangedSubviews: [above, slot, below])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: window.topAnchor),
            stack.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])
        window.layoutIfNeeded()
        return Screen(window: window, slot: slot, below: below)
    }

    private func answer(_ slots: [String: Any]) {
        response = ["slots": slots]
        manager.requestSlots(Array(slots.keys), completion: nil)
    }

    /// Verifies that a slot view put on screen asks for its slot in the shared request for new slots.
    func testViewOnScreenRequestsItsSlot() {
        response = ["slots": ["home_top": banner]]
        let screen = makeScreen(with: PushwooshInlineView(slotId: "home_top", manager: manager))

        scheduled.forEach { $0() }
        screen.window.layoutIfNeeded()

        XCTAssertEqual(sent, [["home_top"]])
        XCTAssertGreaterThan(screen.slot.frame.height, 0)
    }

    /// Verifies that an empty slot takes no height, so the screen looks as if it were not there.
    func testEmptySlotHasZeroHeight() {
        let screen = makeScreen(with: PushwooshInlineView(slotId: "home_top", manager: manager))

        XCTAssertEqual(screen.slot.frame.height, 0)
    }

    /// Verifies that a banner from the slots answer expands the slot and pushes the views below it down.
    func testAnsweredBannerExpandsSlotAndPushesSiblings() {
        let screen = makeScreen(with: PushwooshInlineView(slotId: "home_top", manager: manager))
        let belowBefore = screen.below.frame.minY

        answer(["home_top": banner])
        screen.window.layoutIfNeeded()

        XCTAssertGreaterThan(screen.slot.frame.height, 40)
        XCTAssertEqual(screen.below.frame.minY, belowBefore + screen.slot.frame.height, accuracy: 0.5)
    }

    /// Verifies that an empty answer for the slot collapses it back to zero and the siblings return.
    func testEmptyAnswerCollapsesSlot() {
        let screen = makeScreen(with: PushwooshInlineView(slotId: "home_top", manager: manager))
        let belowBefore = screen.below.frame.minY
        answer(["home_top": banner])
        screen.window.layoutIfNeeded()

        answer(["home_top": NSNull()])
        screen.window.layoutIfNeeded()

        XCTAssertEqual(screen.slot.frame.height, 0)
        XCTAssertEqual(screen.below.frame.minY, belowBefore, accuracy: 0.5)
    }

    /// Verifies that a slot created after relaunch shows the banner persisted before, without any request.
    func testColdStartShowsPersistedBanner() {
        answer(["home_top": banner])

        let relaunched = makeManager(store: PWInlineStore(fileURL: fileURL))
        let screen = makeScreen(with: PushwooshInlineView(slotId: "home_top", manager: relaunched))

        XCTAssertGreaterThan(screen.slot.frame.height, 40)
    }

    /// Verifies that a slot decoded from a storyboard binds once Interface Builder sets slotId via KVC.
    func testStoryboardDecodedSlotBindsSlotId() throws {
        let slotId = "storyboard_\(UUID().uuidString)"
        let archived = try NSKeyedArchiver.archivedData(withRootObject: PushwooshInlineView(frame: .zero),
                                                        requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archived)
        unarchiver.requiresSecureCoding = false
        let decoded = try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? PushwooshInlineView)
        decoded.setValue(slotId, forKey: "slotId")
        let store = PWInlineManager.shared.store
        defer { store.apply([slotId], banners: [:]) }

        let parsed = try XCTUnwrap(PWInlineParser.banner(from: banner, slotId: slotId, receivedAt: Date()))
        store.apply([slotId], banners: [slotId: parsed])
        let screen = makeScreen(with: decoded)
        screen.window.layoutIfNeeded()

        XCTAssertGreaterThan(screen.slot.frame.height, 0)
    }

    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ([view as? T].compactMap { $0 }) + view.subviews.flatMap { views(type, in: $0) }
    }

    private func target(_ action: PWInlineAction) -> String {
        switch action {
        case .url(let url), .deeplink(let url):
            return url.absoluteString
        case .postEvent(let name, _):
            return name
        case .copy(let text, _):
            return text
        case .close:
            return "close"
        }
    }

    /// Verifies that a tap on the banner body runs the banner action and an image with its own action runs that one.
    func testBannerTapRunsBannerActionAndImageRunsItsOwn() throws {
        let raw: [String: Any] = [
            "bannerId": "promo", "version": 1, "format": "native",
            "action": ["type": "deeplink", "value": "pushmart://sale"],
            "native": ["root": ["type": "stack", "padding": 16, "children": [
                ["type": "text", "text": "Autumn sale"],
                ["type": "image", "id": "hero", "url": "https://example.invalid/hero.png", "aspect": 2,
                 "action": ["type": "url", "value": "https://example.com/hero"]],
            ]]],
        ]
        let parsed = try XCTUnwrap(PWInlineParser.banner(from: raw, slotId: "home_top", receivedAt: Date()))
        var taps: [String] = []
        let view = PWInlineRenderer(onSizeChange: {}, onAction: { action, nodeId in
            taps.append("\(nodeId ?? "banner")=\(self.target(action))")
        }, canPostEvent: { true }).makeView(parsed)

        let tappable = views(PWInlineBoxView.self, in: view).filter { $0.onTap != nil }
        tappable.forEach { _ = $0.accessibilityActivate() }

        XCTAssertEqual(taps, ["banner=pushmart://sale", "hero=https://example.com/hero"])
    }

    /// Verifies how each banner color scheme maps to the interface style the banner is drawn in.
    func testColorSchemeMapsToInterfaceStyle() {
        XCTAssertEqual(PWInlineColorScheme.app.interfaceStyle(system: .dark), .unspecified)
        XCTAssertEqual(PWInlineColorScheme.system.interfaceStyle(system: .dark), .dark)
        XCTAssertEqual(PWInlineColorScheme.system.interfaceStyle(system: .light), .light)
        XCTAssertEqual(PWInlineColorScheme.light.interfaceStyle(system: .dark), .light)
        XCTAssertEqual(PWInlineColorScheme.dark.interfaceStyle(system: .light), .dark)
    }

    /// Verifies that a banner follows the dark theme of the app by default and a manual scheme restyles it on the fly.
    func testBannerFollowsAppThemeAndManualSchemeRestylesOnTheFly() throws {
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let screen = makeScreen(with: slot)
        screen.window.overrideUserInterfaceStyle = .dark
        answer(["home_top": banner])
        screen.window.layoutIfNeeded()
        let content = try XCTUnwrap(slot.subviews.last)
        XCTAssertEqual(content.traitCollection.userInterfaceStyle, .dark)

        manager.colorScheme = .light
        screen.window.layoutIfNeeded()
        XCTAssertEqual(content.traitCollection.userInterfaceStyle, .light)

        manager.colorScheme = .app
        screen.window.layoutIfNeeded()
        XCTAssertEqual(content.traitCollection.userInterfaceStyle, .dark)
    }

    /// Verifies that an html banner is drawn in its slot with the height of its document.
    func testHTMLBannerHeightFollowsDocumentHeight() throws {
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let screen = makeScreen(with: slot)
        answer(["home_top": htmlBanner])
        screen.window.layoutIfNeeded()
        let html = try XCTUnwrap(views(PWInlineHTMLBannerView.self, in: slot).first)

        html.documentHeightChanged(180)
        screen.window.layoutIfNeeded()

        XCTAssertEqual(slot.frame.height, 180, accuracy: 0.5)
    }

    /// Loads `html` in a 390 × 600 web view with the banner's height script and waits until `done` accepts the
    /// heights reported so far.
    private func measure(_ html: String, in window: UIWindow,
                         until done: @escaping ([CGFloat]) -> Bool) -> (WKWebView, PWInlineHeightRecorder) {
        let recorder = PWInlineHeightRecorder()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(source: PWInlineHTMLBannerView.heightScript, injectionTime: .atDocumentEnd,
                         forMainFrameOnly: true, in: .defaultClient))
        configuration.userContentController.add(recorder, contentWorld: .defaultClient,
                                                name: PWInlineHTMLBannerView.heightMessage)
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), configuration: configuration)
        window.addSubview(webView)
        let reported = expectation(description: "height")
        recorder.onHeight = { [unowned recorder] in
            if done(recorder.heights) {
                recorder.onHeight = nil
                reported.fulfill()
            }
        }
        webView.loadHTMLString(html, baseURL: nil)
        wait(for: [reported], timeout: 60)
        return (webView, recorder)
    }

    /// Verifies the document height: in-flow content with and without a doctype, absolute boxes, and not the
    /// content an overflow clips.
    func testDocumentHeightCountsInFlowAndPositionedContentOnly() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let documents: [(String, CGFloat)] = [
            ("<!DOCTYPE html><html><body style=\"margin:0\"><div style=\"height:150px\"></div></body></html>", 150),
            ("<html><body><div style=\"height:150px\"></div></body></html>", 166),
            ("<!DOCTYPE html><html><body style=\"margin:0\"><div><div style=\"position:absolute;top:30px;"
             + "width:10px;height:100px\"></div></div></body></html>", 130),
            ("<!DOCTYPE html><html><body style=\"margin:0\"><div style=\"height:100px;overflow:hidden\">"
             + "<div style=\"height:2000px\"></div></div></body></html>", 100),
        ]
        for (html, expected) in documents {
            let (webView, recorder) = measure(html, in: window) { ($0.last ?? 0) > 0 }
            XCTAssertEqual(recorder.heights.last ?? 0, expected, accuracy: 1, html)
            webView.removeFromSuperview()
        }
    }

    /// Verifies that content the page adds after loading is reported as a new height.
    func testDocumentHeightFollowsContentAddedLater() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let html = "<!DOCTYPE html><html><body style=\"margin:0\"><div style=\"height:100px\"></div></body></html>"
        let (webView, recorder) = measure(html, in: window) { $0.last == 100 }

        let grown = expectation(description: "grown")
        recorder.onHeight = { [unowned recorder] in
            if recorder.heights.last == 350 {
                grown.fulfill()
            }
        }
        webView.evaluateJavaScript("var block = document.createElement('div');"
                                   + "block.style.cssText = 'position:absolute;top:300px;width:10px;height:50px';"
                                   + "document.body.appendChild(block);")
        wait(for: [grown], timeout: 60)
        webView.removeFromSuperview()
    }

    /// Runs `script` in the page and returns its string result, waiting for it.
    private func evaluate(_ script: String, in webView: WKWebView) -> String? {
        let done = expectation(description: "evaluate")
        var value: String?
        webView.evaluateJavaScript(script) { result, _ in
            value = result as? String
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        return value
    }

    /// Verifies that an inline HTML document keeps the legacy `pushManager.postEvent` after garbage collections, also
    /// on a WebKit with a `pushManager` of its own, whose wrapper drops properties set on it.
    func testInlineDocumentKeepsLegacyPushManager() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        let view = PWInlineHTMLView(frame: window.bounds)
        window.addSubview(view)
        view.loadHTMLString("<!DOCTYPE html><html><body>legacy</body></html>")
        let loaded = expectation(description: "loaded")
        func check() {
            view.webView.evaluateJavaScript("!!document.body && document.body.innerText.indexOf('legacy') >= 0") { result, _ in
                if result as? Bool == true {
                    loaded.fulfill()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { check() }
                }
            }
        }
        check()
        wait(for: [loaded], timeout: 60)

        let probe = "(function() { var junk = []; for (var i = 0; i < 300000; i++) { junk.push({ i: i }); } "
            + "junk = null; return typeof pushManager.postEvent; })()"
        var types: [String?] = []
        for _ in 0..<6 {
            types.append(evaluate(probe, in: view.webView))
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        }

        XCTAssertEqual(types, Array(repeating: "function", count: 6))
        view.removeFromSuperview()
    }

    /// Verifies that the web view keeps the viewport height whatever the document reports, so a document sized by
    /// its viewport (`height: 100%`, `100vh`) cannot grow the banner, which stops at one viewport.
    func testHTMLViewportKeepsItsHeightWhateverTheDocumentReports() throws {
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let screen = makeScreen(with: slot)
        answer(["home_top": htmlBanner])
        screen.window.layoutIfNeeded()
        let html = try XCTUnwrap(views(PWInlineHTMLBannerView.self, in: slot).first)
        let content = try XCTUnwrap(views(PWInlineHTMLView.self, in: slot).first)
        let viewport = PWInlineHTMLBannerView.viewportHeight

        content.webView.scrollView.contentSize = CGSize(width: 390, height: 10_000)
        screen.window.layoutIfNeeded()
        XCTAssertEqual(content.webView.bounds.height, viewport, accuracy: 0.5)

        html.documentHeightChanged(viewport + 16)
        screen.window.layoutIfNeeded()
        XCTAssertEqual(slot.frame.height, viewport, accuracy: 0.5)
        XCTAssertEqual(content.webView.bounds.height, viewport, accuracy: 0.5)
    }

    /// Verifies that a video banner leaves the app's audio session as the app set it, while shown and after.
    func testVideoBannerKeepsAppAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        let original = (session.category, session.categoryOptions)
        try session.setCategory(.playback, options: [.mixWithOthers])
        defer { try? session.setCategory(original.0, options: original.1) }
        weak var player: PWInAppVideoPlayerView?

        try autoreleasepool {
            let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
            let screen = makeScreen(with: slot)
            answer(["home_top": ["bannerId": "clip", "version": 1, "format": "native",
                                 "native": ["root": ["type": "video", "url": "https://example.invalid/clip.mp4"]]]])
            screen.window.layoutIfNeeded()
            player = try XCTUnwrap(views(PWInAppVideoPlayerView.self, in: slot).first)

            XCTAssertEqual(session.category, .playback)
            XCTAssertEqual(session.categoryOptions, [.mixWithOthers])
        }

        XCTAssertNil(player)
        XCTAssertEqual(session.category, .playback)
        XCTAssertEqual(session.categoryOptions, [.mixWithOthers])
    }

    /// Verifies that with an inline video alive, closing a Modal video gives the app its category back, and an
    /// app on the default `.soloAmbient` mixes with other apps' audio while the inline video lives.
    func testModalVideoTeardownGivesCategoryBackBesideInlineVideo() throws {
        let session = AVAudioSession.sharedInstance()
        let original = (session.category, session.mode, session.categoryOptions)
        defer { try? session.setCategory(original.0, mode: original.1, options: original.2) }
        let url = try XCTUnwrap(URL(string: "https://example.invalid/clip.mp4"))
        let audio = PWInAppAudioSession(session: session)
        let inline = PWInAppVideoPlayerView(audioSession: audio)
        let modal = PWInAppVideoPlayerView(audioSession: audio)

        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        inline.configure(videoURL: url, posterURL: nil, fallbackImageURL: nil, loop: true, muted: true,
                         managesAudioSession: false)
        modal.configure(videoURL: url, posterURL: nil, fallbackImageURL: nil, loop: false, muted: true)
        XCTAssertEqual(session.category, .ambient)
        modal.teardown()
        XCTAssertEqual(session.category, .playback)
        XCTAssertEqual(session.categoryOptions, [.mixWithOthers])
        inline.teardown()

        try session.setCategory(.soloAmbient, mode: .default, options: [])
        inline.configure(videoURL: url, posterURL: nil, fallbackImageURL: nil, loop: true, muted: true,
                         managesAudioSession: false)
        XCTAssertEqual(session.category, .ambient)
        modal.configure(videoURL: url, posterURL: nil, fallbackImageURL: nil, loop: false, muted: false)
        XCTAssertEqual(session.category, .playback)
        modal.teardown()
        XCTAssertEqual(session.category, .ambient)
        inline.teardown()
        XCTAssertEqual(session.category, .soloAmbient)
    }

    /// Verifies that the session is deactivated for other apps once the last player that activated it goes, while a
    /// muted inline video stays, with the app's category, mode and options back; a muted inline video alone does not.
    func testAudioSessionIsDeactivatedWhenLastActivatingPlayerGoes() {
        let session = PWAudioSessionRecorder(category: .playback)
        let audio = PWInAppAudioSession(session: session)
        let inline = NSObject()
        let modal = NSObject()
        let sheet = NSObject()

        audio.mixWithOthers(for: inline)
        audio.leave(inline)
        XCTAssertEqual(session.deactivations, 0)
        XCTAssertTrue(session.categories.isEmpty)

        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        audio.mixWithOthers(for: inline)
        audio.take(.playback, activate: true, for: modal)
        audio.take(.ambient, activate: true, for: sheet)
        audio.leave(modal)
        XCTAssertEqual(session.deactivations, 0)
        audio.leave(sheet)
        XCTAssertEqual(session.deactivations, 1)
        XCTAssertEqual(session.category, .playback)
        XCTAssertEqual(session.mode, .moviePlayback)
        XCTAssertEqual(session.categoryOptions, [.mixWithOthers])
        audio.leave(inline)
        XCTAssertEqual(session.deactivations, 1)
    }

    /// Verifies that a muted inline video moving an app on `.soloAmbient` to `.ambient` gives the category back
    /// without deactivating the session, which may carry the app's own audio.
    func testMutedInlineVideoLeavesSessionActivationToTheApp() {
        let session = PWAudioSessionRecorder(category: .soloAmbient)
        let audio = PWInAppAudioSession(session: session)
        let inline = NSObject()

        audio.mixWithOthers(for: inline)
        XCTAssertEqual(session.category, .ambient)
        audio.leave(inline)

        XCTAssertEqual(session.category, .soloAmbient)
        XCTAssertEqual(session.deactivations, 0)
    }

    /// Verifies that a category the app set while a player held the session is not overwritten when the player goes.
    func testAudioSessionKeepsCategoryTheAppSetMeanwhile() {
        let session = PWAudioSessionRecorder(category: .soloAmbient)
        let audio = PWInAppAudioSession(session: session)
        let inline = NSObject()

        audio.mixWithOthers(for: inline)
        XCTAssertEqual(session.category, .ambient)
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [])
        audio.leave(inline)

        XCTAssertEqual(session.category, .playAndRecord)
        XCTAssertEqual(session.mode, .voiceChat)
    }

    /// Verifies that closeInApp of an html banner hides it in its slot.
    func testHTMLCloseInAppHidesBanner() throws {
        let slot = PushwooshInlineView(slotId: "home_top", manager: manager)
        let screen = makeScreen(with: slot)
        answer(["home_top": htmlBanner])
        screen.window.layoutIfNeeded()
        let html = try XCTUnwrap(views(PWInlineHTMLView.self, in: slot).first)

        html.closeInApp?()
        screen.window.layoutIfNeeded()

        XCTAssertNil(manager.store.banner(for: "home_top"))
        XCTAssertEqual(slot.frame.height, 0)
    }
}
#endif
