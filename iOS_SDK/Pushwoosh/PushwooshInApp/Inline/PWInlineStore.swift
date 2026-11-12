//
//  PWInlineStore.swift
//  PushwooshInApp
//
//  Created by André Kis on 29.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import Foundation
import PushwooshCore

/// Cancels its store subscription when cancelled or released.
final class PWInlineSubscription {

    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        cancel()
    }
}

/// One banner per slot, persisted in Application Support so received banners survive a cold start
/// without network. Expired banners are dropped (on load, on update and on a timer while the app runs);
/// a banner the user closed is not taken back at the same or a lower version until its `expireDate`.
/// Banners, closed banners and reported shows belong to one user and application: under another owner
/// they are not shown and are cleared on the next sync. Between a user change and its sync (the server
/// confirming the user) the previous user's banners stay and their events go out for that user.
/// A file that cannot be read yet (before the first unlock) is not written over: it is read and merged
/// with what came meanwhile once it can be. Also keeps the slot ids the app uses, forgotten after 30 days
/// without a view. A test banner covers the live banner of its slot until relaunch: it, its close and
/// its reported show stay in memory. Main thread only.
final class PWInlineStore {

    static let defaultFileURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("PushwooshInApp", isDirectory: true)
            .appendingPathComponent("inline-banners.json")
    }()

    static let shared = PWInlineStore(fileURL: defaultFileURL)

    static let slotMemory: TimeInterval = 30 * 24 * 3600
    private static let slotSeenRefresh: TimeInterval = 24 * 3600

    /// Called with the slots whose banner changed, after their subscribers.
    var onChange: (([String]) -> Void)?

    private let fileURL: URL
    /// Reads and writes of every store, so a read sees all earlier writes.
    private static let ioQueue = DispatchQueue(label: "com.pushwoosh.inapp.inline-store")
    private let owner: () -> String?
    private let now: () -> Date
    private var cacheOwner: String?
    /// The file was read (or there was none); until then nothing is written over it.
    private var isLoaded = false
    /// Slot id to the last time a view showed it or the app requested it.
    private var knownSlots: [String: Date] = [:]
    private var banners: [String: PWInlineBanner] = [:]
    private struct Dismissal {
        /// The highest version the user closed.
        let version: Int
        /// The closed banner's `expireDate`; `nil` = kept for good.
        let until: Date?
    }

    private var dismissed: [String: Dismissal] = [:]
    /// Banner id to the highest version whose show (or control) was reported.
    private var reported: [String: Int] = [:]
    private var testBanners: [String: PWInlineBanner] = [:]
    private var dismissedTests: [String: Dismissal] = [:]
    private var reportedTests: [String: Int] = [:]
    private var observers: [String: [UUID: (PWInlineBanner?) -> Void]] = [:]
    private var expiryTimer: Timer?

    /// `owner` names the user and application the cache belongs to; `nil` = not known yet (no app code).
    init(fileURL: URL, owner: @escaping () -> String? = PWInlineStore.preferencesOwner,
         now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.owner = owner
        self.now = now
        load()
        syncOwner()
        scheduleExpiry()
    }

    static func preferencesOwner() -> String? {
        let preferences = PWPreferences.preferencesInstance()
        return owner(userId: preferences.userId, appCode: preferences.appCode)
    }

    static func owner(userId: String, appCode: String) -> String? {
        guard !appCode.isEmpty else {
            return nil
        }
        return "\(userId.isEmpty ? PWPreferences.preferencesInstance().hwid : userId)|\(appCode)"
    }

    func currentOwner() -> String? {
        owner()
    }

    /// Clears banners and closed banners kept for another user or application; `true` = the owner changed.
    @discardableResult
    func syncOwner() -> Bool {
        guard let current = owner(), current != cacheOwner else {
            return false
        }
        let cleared = Array(Set(banners.keys).union(testBanners.keys))
        let hadData = !banners.isEmpty || !dismissed.isEmpty || !reported.isEmpty || !testBanners.isEmpty
        banners = [:]
        dismissed = [:]
        reported = [:]
        testBanners = [:]
        dismissedTests = [:]
        reportedTests = [:]
        cacheOwner = current
        guard hadData else {
            return true
        }
        log("Inline banners belong to another user or application, \(cleared.count) slots cleared")
        save()
        scheduleExpiry()
        notify(cleared)
        return true
    }

    private var belongsToCurrentApplication: Bool {
        guard let current = owner(), let cacheOwner = cacheOwner else {
            return true
        }
        return Self.parts(of: current)?.appCode == Self.parts(of: cacheOwner)?.appCode
    }

    /// The user the shown banners belong to while the change to another user is not synced yet.
    var previousUserId: String? {
        guard let current = owner(), let cacheOwner = cacheOwner, current != cacheOwner,
              belongsToCurrentApplication, let userId = Self.parts(of: cacheOwner)?.userId else {
            return nil
        }
        return String(userId)
    }

    /// The user id and app code of an owner made by `owner(userId:appCode:)`; the app code has no `|`.
    private static func parts(of owner: String) -> (userId: Substring, appCode: Substring)? {
        owner.lastIndex(of: "|").map { (owner[..<$0], owner[owner.index(after: $0)...]) }
    }

    // MARK: - Known slots

    func rememberSlots(_ slotIds: [String]) {
        let now = self.now()
        var changed = false
        for slotId in slotIds where !slotId.isEmpty {
            if let seen = knownSlots[slotId], now.timeIntervalSince(seen) < Self.slotSeenRefresh {
                continue
            }
            knownSlots[slotId] = now
            changed = true
        }
        if changed {
            save()
        }
    }

    /// Slot ids seen in the last 30 days, sorted.
    func knownSlotIds() -> [String] {
        let now = self.now()
        let forgotten = knownSlots.filter { now.timeIntervalSince($0.value) >= Self.slotMemory }.keys
        if !forgotten.isEmpty {
            forgotten.forEach { knownSlots[$0] = nil }
            save()
        }
        return knownSlots.keys.sorted()
    }

    /// Puts the server's answer for `slotIds`: the slot's banner from `banners`, or empty when it has none;
    /// a test banner goes over the live one and leaves it as is. A banner with the same id and a version
    /// not above the stored one is a repeat and is skipped. Returns the slots whose shown banner changed.
    @discardableResult
    func apply(_ slotIds: [String], banners received: [String: PWInlineBanner]) -> [String] {
        guard previousUserId == nil else {
            log("Inline slots answer for a user the server has not confirmed yet is dropped")
            return []
        }
        syncOwner()
        var changed: [String] = []
        var liveChanged = false
        for slotId in slotIds {
            let shownBefore = banner(for: slotId)
            if let banner = received[slotId], banner.isTest {
                if isShowable(banner), !isRepeat(banner, of: testBanners[slotId]) {
                    testBanners[slotId] = banner
                }
            } else if let banner = received[slotId], isShowable(banner) {
                if !isRepeat(banner, of: banners[slotId]) {
                    banners[slotId] = banner
                    liveChanged = true
                }
            } else if banners.removeValue(forKey: slotId) != nil {
                liveChanged = true
            }
            if !Self.isSame(shownBefore, banner(for: slotId)) {
                changed.append(slotId)
            }
        }
        if liveChanged {
            save()
        }
        if liveChanged || !changed.isEmpty {
            scheduleExpiry()
        }
        if !changed.isEmpty {
            notify(changed)
        }
        return changed
    }

    private func isRepeat(_ banner: PWInlineBanner, of current: PWInlineBanner?) -> Bool {
        current.map { $0.bannerId == banner.bannerId && $0.version >= banner.version } ?? false
    }

    static func isSame(_ lhs: PWInlineBanner?, _ rhs: PWInlineBanner?) -> Bool {
        lhs?.bannerId == rhs?.bannerId && lhs?.version == rhs?.version && lhs?.isTest == rhs?.isTest
    }

    private func isShowable(_ banner: PWInlineBanner) -> Bool {
        let dismissals = banner.isTest ? dismissedTests : dismissed
        if let dismissal = dismissals[banner.bannerId], dismissal.version >= banner.version, !isOver(dismissal) {
            log("Inline banner '\(banner.bannerId)' was closed by the user, slot '\(banner.slotId)' stays empty")
            return false
        }
        return !isExpired(banner)
    }

    /// The user closed the banner in `slotId`: the slot collapses and the same banner does not come back
    /// before its `expireDate`.
    func dismiss(_ slotId: String) {
        guard belongsToCurrentApplication else {
            return
        }
        if let banner = testBanners.removeValue(forKey: slotId) {
            dismissedTests[banner.bannerId] = Dismissal(version: banner.version, until: banner.expireDate)
            log("Inline test banner '\(banner.bannerId)' closed by the user")
            notify([slotId])
            return
        }
        guard let banner = banners.removeValue(forKey: slotId) else {
            return
        }
        dismissed = dismissed.filter { !isOver($0.value) }
        dismissed[banner.bannerId] = Dismissal(version: banner.version, until: banner.expireDate)
        log("Inline banner '\(banner.bannerId)' closed by the user")
        save()
        notify([slotId])
    }

    private func isOver(_ dismissal: Dismissal) -> Bool {
        dismissal.until.map { $0 <= now() } ?? false
    }

    // MARK: - Reported shows

    func isReported(_ banner: PWInlineBanner) -> Bool {
        (banner.isTest ? reportedTests : reported)[banner.bannerId].map { $0 >= banner.version } ?? false
    }

    /// Records that the show (or control) of the banner's version was reported; `false` = already was,
    /// or the banner is not the current application's.
    func markReported(_ banner: PWInlineBanner) -> Bool {
        guard belongsToCurrentApplication, !isReported(banner) else {
            return false
        }
        if banner.isTest {
            reportedTests[banner.bannerId] = banner.version
            return true
        }
        reported[banner.bannerId] = banner.version
        save()
        return true
    }

    func banner(for slotId: String) -> PWInlineBanner? {
        guard belongsToCurrentApplication else {
            return nil
        }
        return [testBanners[slotId], banners[slotId]].compactMap { $0 }.first { !isExpired($0) }
    }

    /// Calls `handler` at once with the current banner, then on every change of `slotId`.
    func subscribe(_ slotId: String, _ handler: @escaping (PWInlineBanner?) -> Void) -> PWInlineSubscription {
        let token = UUID()
        observers[slotId, default: [:]][token] = handler
        handler(banner(for: slotId))
        return PWInlineSubscription { [weak self] in
            self?.observers[slotId]?[token] = nil
        }
    }

    private func notify(_ slotIds: [String]) {
        for slotId in slotIds {
            let banner = self.banner(for: slotId)
            observers[slotId]?.values.forEach { $0(banner) }
        }
        onChange?(slotIds)
    }

    // MARK: - Expiry

    private func isExpired(_ banner: PWInlineBanner) -> Bool {
        banner.expireDate.map { $0 <= now() } ?? false
    }

    private func scheduleExpiry() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard let next = (Array(banners.values) + testBanners.values).compactMap(\.expireDate).min() else {
            return
        }
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            self?.dropExpired()
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func dropExpired() {
        let expired = banners.filter { isExpired($0.value) }
        let expiredTests = testBanners.filter { isExpired($0.value) }
        for (slotId, banner) in expired {
            banners[slotId] = nil
            log("Inline banner '\(banner.bannerId)' expired, slot '\(slotId)' collapses")
        }
        for (slotId, banner) in expiredTests {
            testBanners[slotId] = nil
            log("Inline test banner '\(banner.bannerId)' expired in slot '\(slotId)'")
        }
        if !expired.isEmpty {
            save()
        }
        let slots = Set(expired.keys).union(expiredTests.keys)
        if !slots.isEmpty {
            notify(Array(slots))
        }
        scheduleExpiry()
    }

    // MARK: - Persistence

    private enum FileContents {
        case unreadable
        case read([String: Any])
    }

    /// A missing or damaged file reads as empty; a file the app may not read yet is `unreadable`.
    private func readFile() -> FileContents {
        let fileURL = self.fileURL
        return Self.ioQueue.sync {
            do {
                let data = try Data(contentsOf: fileURL)
                return .read((try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:])
            } catch CocoaError.fileReadNoPermission {
                return .unreadable
            } catch {
                return .read([:])
            }
        }
    }

    private func load() {
        guard case .read(let file) = readFile() else {
            PushwooshLog.pushwooshLog(.PW_LL_WARN, className: "PWInlineStore",
                                      message: "Inline banners cache is not readable yet, it is kept and read later")
            return
        }
        isLoaded = true
        decode(file)
    }

    /// Reads the file that could not be read before and keeps what came meanwhile over it: banners,
    /// closes and shows of the same owner, and every known slot.
    func reloadIfNeeded() {
        guard !isLoaded, case .read(let file) = readFile() else {
            return
        }
        isLoaded = true
        let slots = Set(banners.keys).union(observers.keys)
        let shownBefore = Dictionary(uniqueKeysWithValues: slots.map { ($0, banner(for: $0)) })
        let kept = (owner: cacheOwner, banners: banners, dismissed: dismissed, reported: reported,
                    knownSlots: knownSlots)
        cacheOwner = nil
        banners = [:]
        dismissed = [:]
        reported = [:]
        knownSlots = [:]
        decode(file)
        if let keptOwner = kept.owner, keptOwner != cacheOwner {
            banners = [:]
            dismissed = [:]
            reported = [:]
            cacheOwner = keptOwner
        }
        banners.merge(kept.banners) { _, kept in kept }
        dismissed.merge(kept.dismissed) { $0.version >= $1.version ? $0 : $1 }
        reported.merge(kept.reported, uniquingKeysWith: max)
        knownSlots.merge(kept.knownSlots, uniquingKeysWith: max)
        log("Inline banners cache is read, \(banners.count) banners")
        save()
        syncOwner()
        scheduleExpiry()
        let changed = Set(banners.keys).union(slots).filter { !Self.isSame(shownBefore[$0] ?? nil, banner(for: $0)) }
        if !changed.isEmpty {
            notify(changed.sorted())
        }
    }

    private func decode(_ file: [String: Any]) {
        cacheOwner = file["owner"] as? String
        let dismissals = file["dismissed"] as? [String: [String: Any]] ?? [:]
        dismissed = dismissals.compactMapValues { record in
            guard let version = record["version"] as? Int else {
                return nil
            }
            return Dismissal(version: version, until: (record["until"] as? Double).map(Date.init(timeIntervalSince1970:)))
        }.filter { !isOver($0.value) }
        reported = file["reported"] as? [String: Int] ?? [:]
        let slots = file["slots"] as? [String: Double] ?? [:]
        knownSlots = slots.mapValues { Date(timeIntervalSince1970: $0) }
        let records = file["banners"] as? [String: [String: Any]] ?? [:]
        for (slotId, record) in records {
            guard let receivedAt = record["receivedAt"] as? Double,
                  let banner = PWInlineParser.banner(from: record["banner"], slotId: slotId,
                                                     receivedAt: Date(timeIntervalSince1970: receivedAt)),
                  !isExpired(banner) else {
                continue
            }
            banners[slotId] = banner
        }
    }

    /// The file is written off the main thread, in call order.
    private func save() {
        guard isLoaded else {
            return
        }
        let records = banners.mapValues { banner -> [String: Any] in
            ["banner": banner.raw, "receivedAt": banner.receivedAt.timeIntervalSince1970]
        }
        let dismissals = dismissed.mapValues { dismissal -> [String: Any] in
            var record: [String: Any] = ["version": dismissal.version]
            record["until"] = dismissal.until?.timeIntervalSince1970
            return record
        }
        var file: [String: Any] = ["banners": records, "dismissed": dismissals, "reported": reported,
                                   "slots": knownSlots.mapValues(\.timeIntervalSince1970)]
        file["owner"] = cacheOwner
        let fileURL = self.fileURL
        Self.ioQueue.async {
            do {
                let data = try JSONSerialization.data(withJSONObject: file)
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                PushwooshLog.pushwooshLog(.PW_LL_WARN, className: "PWInlineStore",
                                          message: "Failed to persist inline banners: \(error.localizedDescription)")
            }
        }
    }

    private func log(_ message: String) {
        PushwooshLog.pushwooshLog(.PW_LL_INFO, className: "PWInlineStore", message: message)
    }
}
#endif
