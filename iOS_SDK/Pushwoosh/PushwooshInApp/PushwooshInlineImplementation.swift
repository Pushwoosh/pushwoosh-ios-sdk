//
//  PushwooshInlineImplementation.swift
//  PushwooshInApp
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if canImport(UIKit) && os(iOS)
import UIKit
import PushwooshBridge

/// Implementation behind `Pushwoosh.inline`, registered into `PushwooshModuleRegistry` from
/// `PushwooshInAppLoader.m` at module load. Conforms to the `PWInline` bridge protocol; forwards to
/// `PWInlineManager` on the main thread, waiting for it only where a result is returned.
@objc(PushwooshInlineImplementation)
public final class PushwooshInlineImplementation: NSObject, PWInline {

    @objc
    public static var delegate: PWInlineDelegate? {
        get { onMain { PWInlineManager.shared.delegate } }
        set { PWInlineManager.runOnMain { PWInlineManager.shared.delegate = newValue } }
    }

    @objc
    public static var colorScheme: PWInlineColorScheme {
        get { onMain { PWInlineManager.shared.colorScheme } }
        set { PWInlineManager.runOnMain { PWInlineManager.shared.colorScheme = newValue } }
    }

    @objc
    public static func requestSlots(_ slotIds: [String], completion: ((Error?) -> Void)?) {
        PWInlineManager.runOnMain { PWInlineManager.shared.requestSlots(slotIds, completion: completion) }
    }

    @objc
    public static func banner(forSlot slotId: String) -> PushwooshInlineBanner? {
        onMain { PWInlineManager.shared.banner(forSlot: slotId) }
    }

    @objc(trackShownForSlot:bannerId:)
    public static func trackShown(slotId: String, bannerId: String) {
        PWInlineManager.runOnMain { PWInlineManager.shared.trackShown(slotId: slotId, bannerId: bannerId) }
    }

    @objc(trackClickForSlot:bannerId:elementId:)
    public static func trackClick(slotId: String, bannerId: String, elementId: String?) {
        PWInlineManager.runOnMain {
            PWInlineManager.shared.trackClick(slotId: slotId, bannerId: bannerId, elementId: elementId)
        }
    }

    @objc(dismissSlot:bannerId:)
    public static func dismiss(slotId: String, bannerId: String) {
        PWInlineManager.runOnMain { PWInlineManager.shared.dismiss(slotId: slotId, bannerId: bannerId) }
    }

    /// Starts inline sessions on app activation; called once from `PushwooshInAppLoader.m`. The manager
    /// and its cache are created on the first notification, not at module load.
    @objc
    static func observeApplicationLifecycle() {
        observe(PWInlineManager.shared, in: .default)
    }

    static func observe(_ manager: @autoclosure @escaping () -> PWInlineManager, in center: NotificationCenter) {
        _ = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            manager().applicationDidBecomeActive()
        }
        _ = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            manager().applicationDidEnterBackground()
        }
        _ = center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil,
                               queue: .main) { _ in
            manager().store.reloadIfNeeded()
        }
        _ = center.addObserver(forName: CoreNotification.reachabilityChanged, object: nil, queue: .main) { _ in
            manager().networkReachabilityDidChange()
        }
        _ = center.addObserver(forName: CoreNotification.retryDelivered, object: nil, queue: .main) { note in
            guard note.userInfo?[CoreNotification.retryMethodNameKey] as? String == "trackInlineEvent",
                  let event = note.userInfo?[CoreNotification.retryBodyKey] as? [String: Any] else {
                return
            }
            manager().retriedEventDelivered(event)
        }
        _ = center.addObserver(forName: CoreNotification.applicationChanged, object: nil, queue: .main) { note in
            guard (note.userInfo?[CoreNotification.appCodeChangedKey] as? NSNumber)?.boolValue != false else {
                return
            }
            manager().activeApplicationDidChange()
        }
    }

    private static func onMain<T>(_ work: () -> T) -> T {
        Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)
    }

    /// Notifications and `userInfo` keys of Core, declared in headers the module does not see.
    enum CoreNotification {
        static let reachabilityChanged = Notification.Name("kPWReachabilityChangedNotification")
        static let retryDelivered = Notification.Name("PWRetryQueueDidDeliverRequestNotification")
        static let retryMethodNameKey = "methodName"
        static let retryBodyKey = "body"
        static let applicationChanged = Notification.Name("com.pushwoosh.sdk.activeApplicationChanged")
        static let appCodeChangedKey = "appCodeChanged"
    }
}
#endif
