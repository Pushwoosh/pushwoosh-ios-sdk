//
//  PushwooshSwiftInterface.swift
//  PushwooshiOS
//
//  Created by André Kis on 04.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import PushwooshCore
import PushwooshBridge

public extension Pushwoosh {

    /// Provides access to Live Activities functionality.
    ///
    /// Use this property to start, update, and stop Live Activities with Pushwoosh.
    ///
    /// ```swift
    /// func startDeliveryTracking(activityId: String, token: Data) {
    ///     Pushwoosh.LiveActivities.startLiveActivity(withToken: token, activityId: activityId)
    /// }
    ///
    /// func stopDeliveryTracking() {
    ///     Pushwoosh.LiveActivities.stopLiveActivity()
    /// }
    /// ```
    static var LiveActivities: PWLiveActivities.Type {
        return __liveActivities()
    }

    /// Provides access to debugging and logging functionality.
    ///
    /// Use this property to control SDK logging for development and troubleshooting.
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///     #if DEBUG
    ///     Pushwoosh.debug.setLogLevel(.PW_LL_VERBOSE)
    ///     #else
    ///     Pushwoosh.debug.setLogLevel(.PW_LL_ERROR)
    ///     #endif
    ///     return true
    /// }
    /// ```
    static var debug: PWDebug.Type {
        return __debug()
    }

    /// Provides access to VoIP push notifications functionality.
    ///
    /// Use this property to register for VoIP push notifications and handle incoming VoIP calls.
    ///
    /// ```swift
    /// func registerForVoIPNotifications() {
    ///     Pushwoosh.VoIP.registerForVoIPNotifications()
    /// }
    /// ```
    static var VoIP: PWVoIP.Type {
        return __voIP()
    }

    /// Provides access to tvOS-specific functionality.
    ///
    /// Use this property to configure Rich Media presentation on tvOS.
    ///
    /// ```swift
    /// func setupTVOSRichMedia() {
    ///     Pushwoosh.TVoS.presentRichMedia(with: htmlString)
    /// }
    /// ```
    static var TVoS: PWTVoS.Type {
        return __tVoS();
    }

    /// Provides access to foreground push notification configuration.
    ///
    /// Use this property to customize how push notifications are displayed when the app is in foreground.
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///     Pushwoosh.ForegroundPush.setAlertType(.banner)
    ///     return true
    /// }
    /// ```
    static var ForegroundPush: PWForegroundPush.Type {
        return __foregroundPush()
    }

    /// Provides access to persistent HWID functionality via iOS Keychain.
    ///
    /// Use this property to manage persistent device identification that survives app reinstalls.
    /// The module is automatically disabled in App Store builds for privacy compliance.
    ///
    /// ```swift
    /// // Clear the stored HWID from Keychain (development only)
    /// Pushwoosh.Keychain.clearPersistentHWID()
    /// ```
    ///
    /// - Note: Available starting from SDK version 7.0.16.
    static var Keychain: PWKeychain.Type {
        return __keychain()
    }

    /// Provides access to Pushwoosh configuration.
    ///
    /// Use this property to configure the SDK, register for push notifications, and manage user data.
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///     Pushwoosh.configure.delegate = self
    ///     Pushwoosh.configure.registerForPushNotifications()
    ///     return true
    /// }
    /// ```
    static var configure: PushwooshConfig.Type {
        return __configure() as! PushwooshConfig.Type
    }

    #if os(iOS)
    /// Provides access to Rich Media presentation configuration.
    ///
    /// Use this property to configure how Rich Media content (In-App messages) is displayed.
    /// Access style-specific configuration via `modalRichMedia` or `legacyRichMedia` sub-interfaces.
    ///
    /// ```swift
    /// func application(_ application: UIApplication,
    ///                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///
    ///     Pushwoosh.media.setRichMediaPresentationStyle(.modal)
    ///     Pushwoosh.media.modalRichMedia.configure(
    ///         position: .PWModalWindowPositionBottom,
    ///         presentAnimation: .PWAnimationPresentFromBottom,
    ///         dismissAnimation: .PWAnimationDismissDown
    ///     )
    ///     Pushwoosh.media.modalRichMedia.delegate = self
    ///
    ///     Pushwoosh.configure.registerForPushNotifications()
    ///     return true
    /// }
    /// ```
    ///
    /// - Note: Settings are persisted across app launches. If you remove the method call
    /// from your code, the setting will revert to Info.plist configuration on the next launch.
    static var media: PWMedia.Type {
        return __media() as! PWMedia.Type
    }
    #endif
}

#if os(iOS)
public extension PWMedia {

    /// Provides access to modal Rich Media configuration.
    ///
    /// Use this property to configure modal-specific settings such as window position,
    /// animations, haptic feedback, corner radius, and delegate.
    ///
    /// ```swift
    /// Pushwoosh.media.setRichMediaPresentationStyle(.modal)
    /// Pushwoosh.media.modalRichMedia.configure(
    ///     position: .PWModalWindowPositionBottom,
    ///     presentAnimation: .PWAnimationPresentFromBottom,
    ///     dismissAnimation: .PWAnimationDismissDown
    /// )
    /// Pushwoosh.media.modalRichMedia.delegate = self
    /// ```
    static var modalRichMedia: PWModalRichMedia.Type {
        return __modalRichMedia() as! PWModalRichMedia.Type
    }

    /// Provides access to legacy Rich Media configuration.
    ///
    /// Use this property to configure legacy-specific settings such as the delegate.
    ///
    /// ```swift
    /// Pushwoosh.media.setRichMediaPresentationStyle(.legacy)
    /// Pushwoosh.media.legacyRichMedia.delegate = self
    /// ```
    static var legacyRichMedia: PWLegacyRichMedia.Type {
        return __legacyRichMedia() as! PWLegacyRichMedia.Type
    }
}

public extension PWModalRichMedia {

    /// The delegate that receives Rich Media lifecycle events.
    ///
    /// Set this delegate to handle Rich Media presentation, dismissal, and error events.
    ///
    /// ```swift
    /// class AppDelegate: UIResponder, UIApplicationDelegate, PWRichMediaPresentingDelegate {
    ///     func application(_ application: UIApplication,
    ///                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///         Pushwoosh.media.setRichMediaPresentationStyle(.modal)
    ///         Pushwoosh.media.modalRichMedia.delegate = self
    ///         return true
    ///     }
    ///
    ///     func richMediaManager(_ richMediaManager: PWRichMediaManager,
    ///                           shouldPresent richMedia: PWRichMedia) -> Bool {
    ///         return !userIsInCheckout
    ///     }
    ///
    ///     func richMediaManager(_ richMediaManager: PWRichMediaManager,
    ///                           didPresent richMedia: PWRichMedia) {
    ///         Analytics.log("rich_media_shown")
    ///     }
    ///
    ///     func richMediaManager(_ richMediaManager: PWRichMediaManager,
    ///                           didClose richMedia: PWRichMedia) {
    ///         Analytics.log("rich_media_closed")
    ///     }
    /// }
    /// ```
    static var delegate: PWRichMediaPresentingDelegate? {
        get {
            return self.getDelegate()
        }
        set {
            self.setDelegate(newValue)
        }
    }
}

public extension PWLegacyRichMedia {

    /// The delegate that receives Rich Media lifecycle events.
    ///
    /// Set this delegate to handle Rich Media presentation, dismissal, and error events.
    ///
    /// ```swift
    /// class AppDelegate: UIResponder, UIApplicationDelegate, PWRichMediaPresentingDelegate {
    ///     func application(_ application: UIApplication,
    ///                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///         Pushwoosh.media.setRichMediaPresentationStyle(.legacy)
    ///         Pushwoosh.media.legacyRichMedia.delegate = self
    ///         return true
    ///     }
    ///
    ///     func richMediaManager(_ richMediaManager: PWRichMediaManager,
    ///                           shouldPresent richMedia: PWRichMedia) -> Bool {
    ///         return !userIsInCheckout
    ///     }
    ///
    ///     func richMediaManager(_ richMediaManager: PWRichMediaManager,
    ///                           didPresent richMedia: PWRichMedia) {
    ///         Analytics.log("rich_media_shown")
    ///     }
    ///
    ///     func richMediaManager(_ richMediaManager: PWRichMediaManager,
    ///                           didClose richMedia: PWRichMedia) {
    ///         Analytics.log("rich_media_closed")
    ///     }
    /// }
    /// ```
    static var delegate: PWRichMediaPresentingDelegate? {
        get {
            return self.getDelegate()
        }
        set {
            self.setDelegate(newValue)
        }
    }
}
#endif

public extension PushwooshConfig {

    /// The delegate that receives push notification events.
    ///
    /// Set this delegate to handle push notification received and opened events.
    ///
    /// ```swift
    /// class AppDelegate: UIResponder, UIApplicationDelegate, PWMessagingDelegate {
    ///     func application(_ application: UIApplication,
    ///                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///         Pushwoosh.configure.delegate = self
    ///         Pushwoosh.configure.registerForPushNotifications()
    ///         return true
    ///     }
    ///
    ///     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
    ///         print("Push received: \(message.payload ?? [:])")
    ///     }
    ///
    ///     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
    ///         print("Push opened: \(message.payload ?? [:])")
    ///     }
    /// }
    /// ```
    static var delegate: PWMessagingDelegate? {
        get {
            return self.getDelegate()
        }
        set {
            self.setDelegate(newValue)
        }
    }

    #if os(iOS)
    /// The delegate that receives In-App Purchase events from Rich Media.
    ///
    /// Set this delegate to handle purchase events triggered from Rich Media content.
    ///
    /// ```swift
    /// class AppDelegate: UIResponder, UIApplicationDelegate, PWPurchaseDelegate {
    ///     func application(_ application: UIApplication,
    ///                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///         Pushwoosh.configure.purchaseDelegate = self
    ///         return true
    ///     }
    ///
    ///     func onPWInAppPurchaseHelperProducts(_ products: [SKProduct]) {
    ///         // Handle available products
    ///     }
    ///
    ///     func onPWInAppPurchaseHelperPaymentComplete(_ identifier: String) {
    ///         // Handle successful purchase
    ///     }
    /// }
    /// ```
    static var purchaseDelegate: PWPurchaseDelegate? {
        get {
            return self.getPurchaseDelegate()
        }
        set {
            self.setPurchaseDelegate(newValue)
        }
    }
    #endif
}
