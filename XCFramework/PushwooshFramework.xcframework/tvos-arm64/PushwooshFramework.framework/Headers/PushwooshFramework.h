//
//  PushwooshFramework.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2024
//

/**
 @mainpage Pushwoosh iOS SDK - Integration Guide

 @section overview Overview

 Pushwoosh is a customer engagement platform for push notifications, in-app messages,
 emails, SMS, and WhatsApp. This SDK handles device registration, notification delivery,
 user segmentation, Live Activities (iOS 16.1+), and rich media notifications.

 @section requirements Requirements

 - iOS 11.0+ / tvOS 12.0+ / macOS 10.14+ / watchOS 6.0+
 - Xcode 14.0+
 - Apple Developer account with Push Notifications capability

 @section quick_start Quick Start Guide

 @subsection step1 Step 1: Install SDK

 CocoaPods (Podfile):
 ```ruby
 pod 'PushwooshXCFramework'
 ```

 Swift Package Manager:
 ```
 https://github.com/Pushwoosh/Pushwoosh-XCFramework
 ```

 @subsection step2 Step 2: Configure Info.plist

 Add to your Info.plist (replace XXXXX-XXXXX with your App Code from Pushwoosh Control Panel):
 ```xml
 <key>Pushwoosh_APPID</key>
 <string>XXXXX-XXXXX</string>
 ```

 @subsection step3 Step 3: Enable Capabilities in Xcode

 1. Select your project target
 2. Go to "Signing & Capabilities"
 3. Add "Push Notifications" capability
 4. Add "Background Modes" and enable "Remote notifications"

 @subsection step4 Step 4: Integrate in AppDelegate (Swift)

 ```swift
 import PushwooshFramework

 @main
 class AppDelegate: UIResponder, UIApplicationDelegate {

     func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

         Pushwoosh.configure.delegate = self
         Pushwoosh.configure.registerForPushNotifications()
         return true
     }

     func application(_ application: UIApplication,
                      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
         Pushwoosh.configure.handlePushRegistration(deviceToken)
     }

     func application(_ application: UIApplication,
                      didFailToRegisterForRemoteNotificationsWithError error: Error) {
         Pushwoosh.configure.handlePushRegistrationFailure(error)
     }
 }

 extension AppDelegate: PWMessagingDelegate {
     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
         print("Push received: \(message.payload ?? [:])")
     }

     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
         print("Push opened: \(message.payload ?? [:])")
     }
 }
 ```

 @subsection step5 Step 5: SwiftUI Integration

 ```swift
 import SwiftUI
 import PushwooshFramework

 @main
 struct MyApp: App {
     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

     var body: some Scene {
         WindowGroup {
             ContentView()
         }
     }
 }

 class AppDelegate: NSObject, UIApplicationDelegate, PWMessagingDelegate {
     func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
         Pushwoosh.configure.delegate = self
         Pushwoosh.configure.registerForPushNotifications()
         return true
     }

     func application(_ application: UIApplication,
                      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
         Pushwoosh.configure.handlePushRegistration(deviceToken)
     }

     func application(_ application: UIApplication,
                      didFailToRegisterForRemoteNotificationsWithError error: Error) {
         Pushwoosh.configure.handlePushRegistrationFailure(error)
     }

     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
         // Handle notification tap - navigate to relevant screen
     }
 }
 ```

 @section common_use_cases Common Use Cases

 @subsection user_id User Identification

 ```swift
 // After user login
 Pushwoosh.configure.setUserId("user_12345")
 Pushwoosh.configure.setEmail("user@example.com")
 ```

 @subsection tags User Segmentation with Tags

 ```swift
 Pushwoosh.configure.setTags([
     "subscription": "premium",
     "age": 25,
     "interests": ["sports", "music"],
     "last_purchase": Date()
 ])

 // Increment numeric tags
 Pushwoosh.configure.setTags([
     "purchases_count": PWTagsBuilder.incrementalTag(withInteger: 1)
 ])
 ```

 @subsection deep_links Handle Deep Links

 ```swift
 func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
     if let deepLink = message.customData?["deep_link"] as? String {
         handleDeepLink(deepLink)
     }
 }
 ```

 @subsection logout Unregister on Logout

 ```swift
 func handleLogout() {
     Pushwoosh.configure.unregisterForPushNotifications { error in
         if let error = error {
             print("Unregister failed: \(error)")
         }
     }
 }
 ```

 @section optional_modules Optional Modules

 @subsection live_activities Live Activities (iOS 16.1+)

 Add to Podfile: `pod 'PushwooshXCFramework/PushwooshLiveActivities'`

 ```swift
 // Push-to-start token (iOS 17.2+)
 if #available(iOS 17.2, *) {
     for await data in Activity<MyAttributes>.pushToStartTokenUpdates {
         let token = data.map { String(format: "%02x", $0) }.joined()
         Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: token)
     }
 }

 // Activity token
 for await data in activity.pushTokenUpdates {
     let token = data.map { String(format: "%02x", $0) }.joined()
     Pushwoosh.LiveActivities.startLiveActivity(token: token, activityId: "order_123")
 }

 // Stop activity
 Pushwoosh.LiveActivities.stopLiveActivity(activityId: "order_123")
 ```

 @subsection voip VoIP Push

 Add to Podfile: `pod 'PushwooshXCFramework/PushwooshVoIP'`

 @subsection geozones Geofencing

 Add to Podfile: `pod 'PushwooshXCFramework/Geozones'`

 @section rich_notifications Rich Notifications (Images, Buttons)

 1. File → New → Target → Notification Service Extension
 2. Name it "NotificationService"
 3. Add to Podfile:
    ```ruby
    target 'NotificationService' do
      pod 'PushwooshXCFramework'
    end
    ```
 4. Replace NotificationService.swift:

 ```swift
 import UserNotifications
 import PushwooshFramework

 class NotificationService: UNNotificationServiceExtension {
     var contentHandler: ((UNNotificationContent) -> Void)?
     var bestAttemptContent: UNMutableNotificationContent?

     override func didReceive(_ request: UNNotificationRequest,
                              withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
         self.contentHandler = contentHandler
         bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
         PWNotificationExtensionManager.shared().handle(request, contentHandler: contentHandler)
     }

     override func serviceExtensionTimeWillExpire() {
         if let contentHandler = contentHandler, let content = bestAttemptContent {
             contentHandler(content)
         }
     }
 }
 ```

 @section troubleshooting Troubleshooting

 Push token is nil:
 - Verify Push Notifications capability is enabled
 - Check provisioning profile includes push entitlements
 - Use real device (not simulator) for testing
 - Check Info.plist has Pushwoosh_APPID

 Notifications not received:
 - Upload APNs certificate to Pushwoosh Control Panel
 - Check notification permission in Settings
 - Enable Background Modes → Remote notifications

 Enable debug logging:
 ```swift
 Pushwoosh.debug.setLogLevel(.PW_LL_DEBUG)
 ```
 */

#import <Foundation/Foundation.h>
#import <PushwooshBridge/PushwooshBridge.h>
#import <PushwooshCore/PushwooshCore.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PushwooshConfig.h>
#import <PushwooshCore/PWPreferences.h>

#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV

#import <UserNotifications/UserNotifications.h>

#endif

#if TARGET_OS_IOS

#import <StoreKit/StoreKit.h>

#endif

#define PUSHWOOSH_VERSION @"7.0.26"


@class Pushwoosh, PWMessage, PWNotificationCenterDelegateProxy, PushwooshConfig;
@protocol PWLiveActivities, PWVoIP, PWForegroundPush, PWTVoS, PWDebug, PWMedia, PWKeychain;


typedef void (^PushwooshRegistrationHandler)(NSString * _Nullable token, NSError * _Nullable error);
typedef void (^PushwooshGetTagsHandler)(NSDictionary * _Nullable tags);
typedef void (^PushwooshErrorHandler)(NSError * _Nullable error);


/**
 Delegate protocol for handling push notification events.

 The `PWMessagingDelegate` protocol defines methods that notify your app about push notification lifecycle events.
 Implement these methods to respond to notifications being received and opened by users.

 ## Overview

 This protocol provides two key notification events:
 - When a push notification arrives (received)
 - When a user taps on a push notification (opened)

 Both methods are called with a `PWMessage` object containing the notification payload and metadata.

 ## Usage

 Set your delegate:

 ```swift
 Pushwoosh.configure.delegate = self
 ```

 Then implement the desired delegate methods to handle notifications:

 ```swift
 func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
     updateBadgeCount()
     prefetchContent(for: message)
 }

 func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
     if let deepLink = message.customData?["screen"] as? String {
         router.navigate(to: deepLink)
     }
 }
 ```

 @note Both methods are optional. Implement only the events you need to handle.
 @see PWMessage for details on accessing notification content
 */
@protocol PWMessagingDelegate <NSObject>

@optional
/**
 Called when the application receives a push notification.

 This method is invoked when a push notification arrives, regardless of whether the app is in the foreground or background.
 Use this method to process notification content, update your UI, or trigger background work.

 This method is called even when the app is in the foreground, allowing you to handle notifications without displaying the system alert.

 @param pushwoosh The Pushwoosh instance that received the notification
 @param message The notification message containing payload data, custom fields, and metadata

 @see PWMessage for accessing notification content
*/
- (void)pushwoosh:(Pushwoosh * _Nonnull)pushwoosh onMessageReceived:(PWMessage * _Nonnull)message;

/**
 Called when the user taps on a push notification.

 This method is invoked when a user interacts with a push notification by tapping on it.
 Use this method to navigate to relevant content, open deep links, or perform actions based on the notification.

 This method is only called when the user explicitly taps the notification, not when it's received.

 @param pushwoosh The Pushwoosh instance that received the notification
 @param message The notification message that was opened, containing payload data and custom fields

 @see PWMessage for accessing notification content and custom data
*/
- (void)pushwoosh:(Pushwoosh * _Nonnull)pushwoosh onMessageOpened:(PWMessage * _Nonnull)message;

@end

#if TARGET_OS_IOS
/**
 `PWPurchaseDelegate` protocol defines the methods that can be implemented in the delegate of the `Pushwoosh` class' singleton object.
 These methods provide callbacks for events related to purchasing In-App products from rich medias, such as successful purchase event, failed payment, etc.
 These methods implementation allows to react on such events properly.
 */

@protocol PWPurchaseDelegate <NSObject>

@optional
/**
 Tells the delegate that the application received the array of products.

 This method is called when StoreKit returns available products for in-app purchases initiated from rich media.
 Use this to display product information or prepare the purchase flow.

 @param products Array of SKProduct instances representing available products
 */
- (void)onPWInAppPurchaseHelperProducts:(NSArray<SKProduct *>* _Nullable)products;

/**
 Tells the delegate that the transaction is in queue and the user has been charged.

 This method is called when a purchase transaction completes successfully. The transaction has been added
 to the payment queue and the user's account has been charged.

 Use this method to unlock content, update your app's state, or provide confirmation to the user.

 @param identifier Product identifier agreed upon with the store
 */
- (void)onPWInAppPurchaseHelperPaymentComplete:(NSString* _Nullable)identifier;

/**
 Tells the delegate that the transaction was cancelled or failed before being added to the server queue.

 This method is called when a purchase transaction fails or is cancelled by the user. Use this to handle errors,
 display appropriate messages to the user, or log the failure for analytics.

 Common reasons for failure include user cancellation, invalid product IDs, or network issues.

 @param identifier The unique product identifier
 @param error The error that caused the transaction to fail
 */
- (void)onPWInAppPurchaseHelperPaymentFailedProductIdentifier:(NSString* _Nullable)identifier error:(NSError* _Nullable)error;

/**
 Tells the delegate that a user initiates an IAP buy from the App Store.

 This method is called when a user initiates an in-app purchase directly from the App Store (promoted IAP).
 Use this to handle the promoted purchase flow and start the transaction.

 @param identifier Product identifier of the promoted product
 */
- (void)onPWInAppPurchaseHelperCallPromotedPurchase:(NSString* _Nullable)identifier;

/**
 Tells the delegate that an error occurred while restoring transactions.

 This method is called when the restore purchases operation fails. Use this to inform the user that
 their purchases could not be restored and provide appropriate error handling.

 @param error Error describing why the restore operation failed
 */
- (void)onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:(NSError * _Nullable)error;

@end
#endif




/**
 Main SDK interface for push notification management.

 The `Pushwoosh` class provides a singleton interface for integrating push notifications into your iOS application.
 It handles device registration with Apple Push Notification service (APNs), manages notification delivery,
 and provides methods for user segmentation and messaging.

 ## Overview

 Pushwoosh SDK manages the entire push notification lifecycle:
 - Device registration and token management
 - Push notification delivery and handling
 - User identification and segmentation with tags
 - Badge management
 - In-app purchase tracking
 - Deep link processing

 ## Initialization

 Configure the App Code in Info.plist with key `Pushwoosh_APPID` and call `registerForPushNotifications()` to enable push notifications.

 ## Registration

 Register for push notifications in your AppDelegate:

 ```swift
 func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     Pushwoosh.configure.registerForPushNotifications()
     return true
 }

 func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
     Pushwoosh.configure.handlePushRegistration(deviceToken)
 }
 ```

 ## User Segmentation

 Use tags to segment users for targeted messaging:

 ```swift
 Pushwoosh.configure.setTags([
     "subscription_plan": user.plan.rawValue,
     "last_purchase_date": user.lastPurchase,
     "items_in_cart": cart.items.count
 ])
 ```

 ## Topics

 ### SDK Access
 - sharedInstance()

 ### Registration
 - registerForPushNotifications()
 - unregisterForPushNotifications()
 - handlePushRegistration:

 ### User Management
 - setUserId:
 - setEmail:
 - setTags:
 - getTags:onFailure:

 ### Notification Handling
 - handlePushReceived:
 - delegate

 ### Badge Management
 - sendBadges:

 @note All API calls are performed asynchronously and do not block the main thread.
 @see PWMessagingDelegate for handling notification events
 @see PWMessage for accessing notification content
 */
@interface Pushwoosh : NSObject

#pragma mark - Live Activity
+ (Class<PWLiveActivities>_Nonnull)LiveActivities NS_REFINED_FOR_SWIFT;

#pragma mark - Logging
+ (Class<PWDebug>_Nonnull)debug NS_REFINED_FOR_SWIFT;

#pragma mark - VoIP
+ (Class<PWVoIP>_Nonnull)VoIP NS_REFINED_FOR_SWIFT;

#pragma mark - Configuration
+ (Class _Nonnull)configure NS_REFINED_FOR_SWIFT;

#pragma mark - Custom Foreground Push Notifications
+ (Class<PWForegroundPush>_Nonnull)ForegroundPush NS_REFINED_FOR_SWIFT;

#pragma mark - tvOS Features
+ (Class<PWTVoS>_Nonnull)TVoS NS_REFINED_FOR_SWIFT;

#pragma mark - Keychain Persistent HWID
+ (Class<PWKeychain>_Nonnull)Keychain NS_REFINED_FOR_SWIFT;

#if TARGET_OS_IOS
#pragma mark - Rich Media
+ (Class<PWMedia>_Nonnull)media NS_REFINED_FOR_SWIFT;
#endif

/**
 Pushwoosh Application ID. Usually retrieved automatically from Info.plist parameter `Pushwoosh_APPID`
 */
@property (nonatomic, copy, readonly) NSString * _Nonnull applicationCode;

/**
 `PushNotificationDelegate` protocol delegate that would receive the information about events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification.
 Pushwoosh Runtime sets it to ApplicationDelegate by default
 */
@property (nonatomic, weak) NSObject<PWMessagingDelegate> * _Nullable delegate;

#if TARGET_OS_IOS
/**
 `PushPurchaseDelegate` protocol delegate that would receive the information about events related to purchasing InApp products from rich medias
 */
@property (nonatomic, weak) NSObject<PWPurchaseDelegate> * _Nullable purchaseDelegate;
#endif

#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV

/**
 Show push notifications alert when push notification is received while the app is running, default is `YES`
 */
@property (nonatomic, assign) BOOL showPushnotificationAlert;

#endif

#if TARGET_OS_IOS || TARGET_OS_WATCH

/**
 Authorization options in addition to UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionCarPlay.
 */
@property (nonatomic) UNAuthorizationOptions additionalAuthorizationOptions __IOS_AVAILABLE(12.0);

#endif

/**
 Returns push notification payload if the app was started in response to push notification or null otherwise
 */
@property (nonatomic, copy, readonly) NSDictionary * _Nullable launchNotification;

/**
 Proxy contains UNUserNotificationCenterDelegate objects.
*/
@property (nonatomic, readonly) PWNotificationCenterDelegateProxy * _Nullable notificationCenterDelegateProxy;

/**
 Set custom application language. Must be a lowercase two-letter code according to ISO-639-1 standard ("en", "de", "fr", etc.).
 Device language used by default.
 Set to nil if you want to use device language again.
 */
@property (nonatomic) NSString * _Nonnull language;

/**
 Initializes the Pushwoosh SDK with your application code.

 @param appCode Your Pushwoosh Application Code from the Pushwoosh Control Panel

 @note You can configure the Application Code in Info.plist with key `Pushwoosh_APPID` instead of calling this method.
 @see sharedInstance() to access the configured SDK instance
 */
+ (void)initializeWithAppCode:(NSString *_Nonnull)appCode;

/**
 Returns the shared Pushwoosh SDK instance.

 Access this singleton to interact with the Pushwoosh SDK after initialization.
 All SDK operations are performed through this shared instance.

 @return The singleton Pushwoosh instance

 Example:

 ```swift
 Pushwoosh.configure.delegate = self
 Pushwoosh.configure.registerForPushNotifications()
 Pushwoosh.configure.setTags(["user_type": "premium"])
 ```

 @note The SDK must be initialized with initializeWithAppCode: or via Info.plist before accessing the shared instance.
 @see initializeWithAppCode: for SDK initialization
 */
+ (instancetype _Nonnull )sharedInstance;

/**
 Registers the device for push notifications.

 This method initiates the push notification registration process by requesting user permission
 to display notifications and registering the device with Apple Push Notification service (APNs).

 When called, the system will display a permission dialog to the user asking them to allow notifications.
 Once the user grants permission, the device will receive a push token from APNs which will be
 automatically sent to Pushwoosh servers for future push notification delivery.

 The registration process is asynchronous. The device token will be handled automatically by the SDK.

 This method should be called after configuring the Pushwoosh App Code in Info.plist with key `Pushwoosh_APPID`.

 Example usage:

 ```swift
 Pushwoosh.configure.registerForPushNotifications()
 ```

 @note The permission dialog will only be shown once. If the user denies permission, subsequent calls
 will not show the dialog again. Users must manually enable notifications in Settings.

 @see registerForPushNotificationsWithCompletion: for a version with completion handler
 @see unregisterForPushNotifications for disabling push notifications
 */
- (void)registerForPushNotifications;

/**
 Registers the device for push notifications with a completion handler.

 @param completion Block called when registration completes, providing the push token or an error
 */
- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler _Nullable )completion;

/**
 Registers the device for push notifications and sets initial tags.

 This method combines device registration with tag assignment in a single call. It requests user permission
 for notifications, registers with APNs, and immediately sets the provided tags on the device.

 @param tags Dictionary of tag names and values to set during registration

 Example:

 ```swift
 Pushwoosh.configure.registerForPushNotifications()
 Pushwoosh.configure.setTags([
     "user_type": "premium",
     "signup_date": Date(),
     "platform": "iOS"
 ])
 ```

 @note This is equivalent to calling registerForPushNotifications() followed by setTags:, but more efficient as it combines both operations.
 @see registerForPushNotifications() for simple registration without tags
 @see registerForPushNotificationsWithCompletion: for registration with completion callback
 @see setTags: for setting tags after registration
 */
- (void)registerForPushNotificationsWith:(NSDictionary * _Nonnull)tags;

/**
 Registers the device for push notifications with initial tags and a completion handler.

 This method combines device registration and tag assignment, providing a callback when the operation completes.
 Use this when you need to know whether registration succeeded and want to set initial tags.

 @param tags Dictionary of tag names and values to set during registration
 @param completion Block called when registration completes, providing the push token or an error

 Example:

 ```swift
 Pushwoosh.configure.registerForPushNotifications()
 Pushwoosh.configure.setTags([
     "user_type": user.isPremium ? "premium" : "free",
     "signup_date": user.createdAt
 ])
 ```

 @note The tags are only set if registration succeeds. If registration fails, the tags will not be applied.
 @see registerForPushNotificationsWith: for version without completion handler
 @see registerForPushNotificationsWithCompletion: for registration without tags
 */
- (void)registerForPushNotificationsWith:(NSDictionary * _Nonnull)tags completion:(PushwooshRegistrationHandler _Nullable )completion;


/**
 Registration methods for Whatsapp and SMS
 */
- (void)registerSmsNumber:(NSString * _Nonnull) number;
- (void)registerWhatsappNumber:(NSString * _Nonnull) number;

/**
 Unregisters the device from push notifications.

 Removes the device from receiving push notifications. This method disables push notifications
 for the current device and notifies Pushwoosh servers to stop sending notifications to this device token.

 Example:

 ```swift
 func handleLogout() {
     Pushwoosh.configure.unregisterForPushNotifications()
 }
 ```

 @note Unregistration is permanent until registerForPushNotifications() is called again.
 @see unregisterForPushNotificationsWithCompletion: for a version with completion handler
 @see registerForPushNotifications() to re-enable push notifications
 */
- (void)unregisterForPushNotifications;

/**
 Unregisters the device from push notifications with a completion handler.

 Similar to unregisterForPushNotifications() but provides a callback when the operation completes.

 @param completion Block called when unregistration completes, providing an error if the operation failed

 Example:

 ```swift
 func handleLogout(completion: @escaping (Bool) -> Void) {
     Pushwoosh.configure.unregisterForPushNotifications { error in
         if let error = error {
             self.showAlert("Failed to unregister: \(error.localizedDescription)")
             completion(false)
         } else {
             self.clearUserSession()
             completion(true)
         }
     }
 }
 ```

 @see unregisterForPushNotifications() for a version without completion handler
 */
- (void)unregisterForPushNotificationsWithCompletion:(void (^_Nullable)(NSError * _Nullable error))completion;

/**
 Manually handles the device push token registration.

 Call this method from your AppDelegate's `application:didRegisterForRemoteNotificationsWithDeviceToken:`
 to forward the device token to Pushwoosh. The SDK normally handles this automatically, but you can call
 this method directly if you're managing the registration flow manually.

 @param devToken The device token received from APNs

 Example:

 ```swift
 func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
     Pushwoosh.configure.handlePushRegistration(deviceToken)
 }
 ```

 @note The SDK handles token registration automatically after calling registerForPushNotifications().
 @see registerForPushNotifications() for automatic registration
 @see handlePushRegistrationFailure: for handling registration errors
 */
- (void)handlePushRegistration:(NSData * _Nonnull)devToken;

/**
 Handles push notification registration failures.

 Call this method from your AppDelegate's `application:didFailToRegisterForRemoteNotificationsWithError:`
 to notify Pushwoosh of registration failures. This helps with debugging and analytics.

 @param error The error received from APNs during registration

 Example:

 ```swift
 func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
     Pushwoosh.configure.handlePushRegistrationFailure(error as NSError)
 }
 ```

 @see handlePushRegistration: for successful registration handling
 */
- (void)handlePushRegistrationFailure:(NSError * _Nonnull)error;

/**
 Handle received push notification.
*/
- (BOOL)handlePushReceived:(NSDictionary * _Nonnull)userInfo;

/**
 * Change default base url to reverse proxy url
 * @param url - reverse proxy url
 * @deprecated Use Pushwoosh.configure.setReverseProxy(_:headers:) instead.
*/
- (void)setReverseProxy:(NSString * _Nonnull)url __attribute__((deprecated("Use Pushwoosh.configure.setReverseProxy(_:headers:) instead")));

/**
 Sets user tags for device segmentation.

 Tags are key-value pairs that enable targeted push notifications based on user attributes and behavior.
 Use tags to segment your audience and send personalized messages to specific user groups.

 Supported tag types:
 - **String**: Text values (e.g., username, city)
 - **Integer**: Numeric values (e.g., age, score)
 - **Boolean**: True/false values (e.g., isPremium, hasSubscription)
 - **List**: Arrays of strings (e.g., interests, categories)
 - **Incremental**: Integer counters that can be incremented/decremented
 - **Date**: NSDate objects for time-based segmentation

 @param tags Dictionary of tag names and values to set for the current device

 Example:

 ```swift
 func updateUserProfile(_ user: User) {
     let tags: [AnyHashable: Any] = [
         "username": user.name,
         "age": user.age,
         "isPremium": user.hasSubscription,
         "interests": user.interests,
         "city": user.city
     ]
     Pushwoosh.configure.setTags(tags)
 }
 ```

 ## Incremental Tags

 Use PWTagsBuilder.incrementalTag(withInteger:) to increment or decrement numeric tags:

 ```swift
 func addPointsToUser(points: Int) {
     let tags: [AnyHashable: Any] = [
         "score": PWTagsBuilder.incrementalTag(withInteger: points)
     ]
     Pushwoosh.configure.setTags(tags)
 }
 ```

 @note Tag names must be created in the Pushwoosh Control Panel before use. Tags are set asynchronously and do not block the calling thread.
 @see setTags:completion: to receive notification when tags are successfully set
 @see getTags:onFailure: to retrieve current tag values
 @see PWTagsBuilder for creating special tag types
 */
- (void)setTags:(NSDictionary * _Nonnull)tags;

/**
 Sets user tags with a completion handler.

 Identical to setTags: but provides a callback to confirm the tags were successfully sent to the server.
 Use this method when you need to know whether the tag operation succeeded or failed.

 @param tags Dictionary of tag names and values to set for the current device
 @param completion Block called when the operation completes, with nil for success or an error object for failure

 Example:

 ```swift
 func updateSubscription(tier: String) {
     let tags: [AnyHashable: Any] = [
         "subscription_tier": tier,
         "subscription_updated": Date()
     ]
     Pushwoosh.configure.setTags(tags) { error in
         if let error = error {
             Analytics.log("tags_update_failed", error: error)
         } else {
             Analytics.log("subscription_updated", tier: tier)
         }
     }
 }
 ```

 @see setTags: for setting tags without a completion handler
 */
- (void)setTags:(NSDictionary * _Nonnull)tags completion:(void (^_Nullable)(NSError * _Nullable error))completion;

/**
 Sets tags for a specific email address.

 @param tags Dictionary of tag names and values
 @param email The email address to associate tags with
 */
- (void)setEmailTags:(NSDictionary * _Nonnull)tags forEmail:(NSString * _Nonnull)email;

/**
 Sets tags for a specific email address with a completion handler.

 @param tags Dictionary of tag names and values
 @param email The email address to associate tags with
 @param completion Block called when the operation completes
 */
- (void)setEmailTags:(NSDictionary * _Nonnull)tags forEmail:(NSString * _Nonnull)email completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Retrieves the current device's tags from the Pushwoosh server.

 Fetches all tags currently set for this device. Tags are returned as a dictionary where keys are tag names
 and values are the corresponding tag values.

 @param successHandler Block called when tags are successfully retrieved. Receives a dictionary containing all device tags.
 @param errorHandler Block called if the request fails. Receives an error describing the failure.

 Example:

 ```swift
 func syncUserProfile() {
     Pushwoosh.configure.getTags({ tags in
         if let tags = tags {
             self.userProfile.isPremium = tags["isPremium"] as? Bool ?? false
             self.userProfile.country = tags["Country"] as? String
         }
     }, onFailure: { error in
         Analytics.log("tags_sync_failed", error: error)
     })
 }
 ```

 @note The operation is performed asynchronously and does not block the calling thread.
 @see setTags: for setting device tags
 @see setTags:completion: for setting tags with completion confirmation
 */
- (void)getTags:(PushwooshGetTagsHandler _Nullable)successHandler onFailure:(PushwooshErrorHandler _Nullable)errorHandler;

/**
 Synchronizes the application badge number with Pushwoosh servers.

 Sends the current badge value to the server to enable auto-incrementing badge functionality.
 The SDK automatically calls this method when the application badge is modified, but you can call it
 manually if needed for custom badge management.

 @param badge The current application badge number

 Example:

 ```swift
 func updateBadgeForUnreadMessages(count: Int) {
     UIApplication.shared.applicationIconBadgeNumber = count
     Pushwoosh.configure.sendBadges(count)
 }
 ```

 @note The SDK automatically intercepts `UIApplication.applicationIconBadgeNumber` changes, so manual calls are rarely needed.
 @see setBadgeNumber: for a convenience method to set and sync the badge in one call
 */
- (void)sendBadges:(NSInteger)badge __API_AVAILABLE(macos(10.10), ios(8.0));

/**
 Pushwoosh SDK version.
*/
+ (NSString * _Nonnull)version;

#if TARGET_OS_IOS
/**
 Sends in-app purchases to Pushwoosh. Use in paymentQueue:updatedTransactions: payment queue method (see example).
 
 Example:

 ```swift
 func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
     Pushwoosh.configure.sendSKPaymentTransactions(transactions)
 }
 ```
 
 @param transactions Array of SKPaymentTransaction items as received in the payment queue.
 */
- (void)sendSKPaymentTransactions:(NSArray * _Nonnull)transactions;

/**
 Tracks individual in-app purchase. See recommended `sendSKPaymentTransactions:` method.
 
 @param productIdentifier purchased product ID
 @param price price for the product
 @param currencyCode currency of the price (ex: @"USD")
 @param date time of the purchase (ex: [NSDate now])
 */
- (void)sendPurchase:(NSString * _Nonnull)productIdentifier withPrice:(NSDecimalNumber * _Nonnull)price currencyCode:(NSString * _Nonnull)currencyCode andDate:(NSDate * _Nonnull)date;

#endif
/**
 Retrieves the current device push token.

 Returns the APNs device token string that was received during push notification registration.
 The token is used to send push notifications to this specific device.

 @return The device push token as a hexadecimal string, or `nil` if the device hasn't registered for push notifications yet

 Example:

 ```swift
 func sendTokenToBackend() {
     guard let token = Pushwoosh.configure.getPushToken() else {
         return
     }
     apiClient.registerDevice(pushToken: token)
 }
 ```

 @note The push token becomes available after successful registration with registerForPushNotifications().
 @see getHWID() for the Pushwoosh Hardware ID
 @see registerForPushNotifications() to initiate registration
 */
- (NSString * _Nullable)getPushToken;

/**
 Returns the Pushwoosh Hardware ID (HWID) for this device.

 The HWID is a unique device identifier used in all Pushwoosh API calls and for device tracking in the
 Pushwoosh Control Panel. On iOS, this corresponds to `UIDevice.identifierForVendor`.

 @return The unique Pushwoosh device identifier

 Example:

 ```swift
 let hwid = Pushwoosh.configure.getHWID()
 sendToBackend(["hwid": hwid, "userId": currentUserId])
 ```

 @note The HWID is generated on first SDK initialization and persists across app launches. Use this identifier to reference the device in Pushwoosh API calls.
 @see getPushToken() for the APNs device token
 */
- (NSString * _Nonnull)getHWID;

/**
 Returns the current user identifier.

 Retrieves the user ID that was previously set using setUserId:. If no user ID has been set,
 this method returns the Hardware ID (HWID) as the default identifier.

 @return The current user identifier, or the HWID if no user ID has been set

 Example:

 ```swift
 func syncWithAnalytics() {
     let userId = Pushwoosh.configure.getUserId()
     Analytics.setUserId(userId)
 }
 ```

 @note The user ID defaults to the HWID until explicitly set with setUserId:.
 @see setUserId: for setting a custom user identifier
 @see getHWID() for the device's Hardware ID
 */
- (NSString * _Nonnull)getUserId;

/**
 Returns dictionary with enabled remove notificaton types.
 
 Example enabled push:

 ```
 {
    enabled = 1;
    pushAlert = 1;
    pushBadge = 1;
    pushSound = 1;
    type = 7;
 }
 ```

 where "type" field is UIUserNotificationType

 Disabled push:

 ```
 {
    enabled = 1;
    pushAlert = 0;
    pushBadge = 0;
    pushSound = 0;
    type = 0;
 }
 ```
 
 Note: In the latter example "enabled" field means that device can receive push notification but could not display alerts (ex: silent push)
 */
+ (NSMutableDictionary * _Nullable)getRemoteNotificationStatus;

/**
 Clears the notifications from the notification center.
 */
+ (void)clearNotificationCenter;

/**
 Register emails list associated to the current user.
 If setEmails succeeds competion is called with nil argument. If setEmails fails completion is called with error.

 @param emails user's emails array
 */
- (void)setEmails:(NSArray * _Nonnull)emails completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Register emails list associated to the current user.

 @param emails user's emails array
 */
- (void)setEmails:(NSArray * _Nonnull)emails;

/**
 Register email associated to the current user. Email should be a string and could not be null or empty.
 If setEmail succeeds competion is called with nil argument. If setEmail fails completion is called with error.

 @param email user's email string
 */
- (void)setEmail:(NSString * _Nonnull)email completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Associates an email address with the current device.

 Register an email for the current user to enable email-based campaigns and user identification.
 The email address must be a valid, non-empty string.

 @param email The user's email address

 Example:

 ```swift
 func handleUserEmailUpdate(_ email: String) {
     Pushwoosh.configure.setEmail(email)
 }
 ```

 @note The email is sent to Pushwoosh servers during the next network sync.
 @see setUserId: for setting a unique user identifier
 */
- (void)setEmail:(NSString * _Nonnull)email;

/**
 Associates a unique identifier with the current device.

 Set a user identifier to track the same user across multiple devices. This can be any unique string
 such as a Facebook ID, username, email, or your own internal user ID. User identification enables
 cross-device data matching and provides better analytics.

 @param userId The unique user identifier
 @param completion Completion handler called when the operation finishes. Receives `nil` on success or an `NSError` on failure.

 Example:

 ```swift
 func handleLogin(userId: String) {
     Pushwoosh.configure.setUserId(userId) { error in
         if let error = error {
             Analytics.log("pushwoosh_user_id_failed", error: error)
         }
     }
 }
 ```

 @note The user ID is synchronized with Pushwoosh servers asynchronously.
 @see setEmail: for setting a user email address
 */
- (void)setUserId:(NSString * _Nonnull)userId completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Associates a unique identifier with the current device.

 Set a user identifier to track the same user across multiple devices. This can be any unique string
 such as a Facebook ID, username, email, or your own internal user ID. User identification enables
 cross-device data matching and provides better analytics.

 @param userId The unique user identifier

 Example:

 ```swift
 func handleLogin(userId: String) {
     Pushwoosh.configure.setUserId(userId)
 }
 ```

 @note The user ID is synchronized with Pushwoosh servers asynchronously. For completion notification, use setUserId:completion:.
 @see setEmail: for setting a user email address
 @see setUserId:completion: for a version with completion handler
 */
- (void)setUserId:(NSString * _Nonnull)userId;

/**
 Set User indentifier. This could be Facebook ID, username or email, or any other user ID.
 This allows data and events to be matched across multiple user devices.
 If setUser succeeds competion is called with nil argument. If setUser fails completion is called with error.

 @param userId user identifier
 @param emails user's emails array
 */
- (void)setUser:(NSString * _Nonnull)userId emails:(NSArray * _Nonnull)emails completion:(void(^ _Nullable)(NSError * _Nullable error))completion;


/**
 Set User indentifier. This could be Facebook ID, username or email, or any other user ID.
 This allows data and events to be matched across multiple user devices.

 @param userId user identifier
 @param emails user's emails array
 */
- (void)setUser:(NSString * _Nonnull)userId emails:(NSArray * _Nonnull)emails;

/**
 Set User indentifier. This could be Facebook ID, username or email, or any other user ID.
 This allows data and events to be matched across multiple user devices.
 If setUser succeeds competion is called with nil argument. If setUser fails completion is called with error.

 @param userId user identifier
 @param email user's email string
 */
- (void)setUser:(NSString * _Nonnull)userId email:(NSString * _Nonnull)email completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Move all events from oldUserId to newUserId if doMerge is true. If doMerge is false all events for oldUserId are removed.

 @param oldUserId source user
 @param newUserId destination user
 @param doMerge if false all events for oldUserId are removed, if true all events for oldUserId are moved to newUserId
 @param completion callback
 */
- (void)mergeUserId:(NSString * _Nonnull)oldUserId to:(NSString * _Nonnull)newUserId doMerge:(BOOL)doMerge completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

/**
 Starts communication with Pushwoosh server.
 */
- (void)startServerCommunication;

/**
 Stops communication with Pushwoosh server.
*/
- (void)stopServerCommunication;

/**
 Process URL of some deep link. Primarly used for register test devices.

 @param url Deep Link URL
*/
#if TARGET_OS_IOS || TARGET_OS_WATCH
- (BOOL)handleOpenURL:(NSURL * _Nonnull)url;
#endif

/**
 Sends push to start live activity token to the server.
 Call this method when you want to initiate live activity via push notification
 
 Example:

 ```swift
 if #available(iOS 17.2, *) {
     Task {
         for await data in Activity<LiveActivityAttributes>.pushToStartTokenUpdates {
             let token = data.map { String(format: "%02x", $0) }.joined()
             try? await Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: token)
         }
     }
 }
 ```
 */

- (void)sendPushToStartLiveActivityToken:(NSString *_Nullable)token
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: ) instead.")));
- (void)sendPushToStartLiveActivityToken:(NSString *_Nullable)token completion:(void (^ _Nullable)(NSError * _Nullable))completion
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.sendPushToStartLiveActivity(token: , completion: ) instead.")));;

/**
 Sends live activity token to the server.
 Call this method when you create a live activity.
 
 Example:

 ```swift
 func startDeliveryActivity(attributes: DeliveryAttributes, state: DeliveryState) async throws -> String? {
     let activity = try Activity<DeliveryAttributes>.request(
         attributes: attributes,
         contentState: state,
         pushType: .token)

     for await data in activity.pushTokenUpdates {
         let token = data.map { String(format: "%02x", $0) }.joined()
         try await Pushwoosh.LiveActivities.startLiveActivity(token: token, activityId: "delivery_\(attributes.orderId)")
         return token
     }
     return nil
 }
 ```
 
 @param token Activity token
 @param activityId Activity ID for updating Live Activities by segments
 */
- (void)startLiveActivityWithToken:(NSString * _Nonnull)token
                        activityId:(NSString * _Nullable)activityId 
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.startLiveActivity(token: , activityId: ) instead.")));
;
- (void)startLiveActivityWithToken:(NSString * _Nonnull)token 
                        activityId:(NSString * _Nullable)activityId
                        completion:(void (^ _Nullable)(NSError * _Nullable error))completion
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use startLiveActivity(token: , activityId: , completion: ) instead.")));
;

/**
 Call this method when you finish working with the live activity.
 
 Example:

 ```swift
 func endDeliveryActivity(_ activity: Activity<DeliveryAttributes>) {
     Task {
         await activity.end(dismissalPolicy: .immediate)
         try? await Pushwoosh.LiveActivities.stopLiveActivity()
     }
 }
 ```
 */
- (void)stopLiveActivity
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.stopLiveActivity() instead.")));

- (void)stopLiveActivityWithCompletion:(void (^ _Nullable)(NSError * _Nullable error))completion
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.stopLiveActivity(completion: ) instead.")));

- (void)stopLiveActivityWith:(NSString *_Nullable)activityId
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.stopLiveActivity(activityId: ) instead.")));
- (void)stopLiveActivityWith:(NSString *_Nullable)activityId completion:(void (^ _Nullable)(NSError * _Nullable error))completion
__attribute__((deprecated("Since 6.8.0: This method is deprecated and will be removed in a future release. Use Pushwoosh.LiveActivities.stopLiveActivity(activityId: , completion: ) instead.")));

@end

/**
`PWNotificationCenterDelegateProxy` class handles notifications on iOS 10 and forwards methods of UNUserNotificationCenterDelegate to all added delegates.
*/
#if TARGET_OS_IOS || TARGET_OS_WATCH
@interface PWNotificationCenterDelegateProxy : NSObject <UNUserNotificationCenterDelegate>
/**
 Returns UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10
*/
@property (nonatomic, strong, readonly) id<UNUserNotificationCenterDelegate> _Nonnull defaultNotificationCenterDelegate;

/**
 Adds extra UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10.
*/
- (void)addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate> _Nonnull)delegate;
@end
#elif TARGET_OS_OSX
@interface PWNotificationCenterDelegateProxy : NSObject <NSUserNotificationCenterDelegate>
/**
 Returns UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10
*/
@property (nonatomic, strong, readonly) id<NSUserNotificationCenterDelegate> defaultNotificationCenterDelegate;
@end
#elif TARGET_OS_TV
@interface PWNotificationCenterDelegateProxy : NSObject <UNUserNotificationCenterDelegate>
/**
 Returns UNUserNotificationCenterDelegate that handles foreground push notifications on tvOS
*/
@property (nonatomic, strong, readonly) id<UNUserNotificationCenterDelegate> _Nonnull defaultNotificationCenterDelegate;

/**
 Adds extra UNUserNotificationCenterDelegate that handles foreground push notifications on tvOS.
*/
- (void)addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate> _Nonnull)delegate;
@end
#endif


/**
`PWTagsBuilder` class encapsulates the methods for creating tags parameters for sending them to the server.
*/
@interface PWTagsBuilder : NSObject
/**
 Creates a dictionary for incrementing/decrementing a numeric tag on the server.
 
 Example:

 ```swift
 func addPointsToScore(_ points: Int) {
     let tags: [AnyHashable: Any] = [
         "score": PWTagsBuilder.incrementalTag(withInteger: points)
     ]
     Pushwoosh.configure.setTags(tags)
 }
 ```

 @param delta Difference that needs to be applied to the tag's counter.
 
 @return Dictionary, that needs to be sent as the value for the tag
 */
+ (NSDictionary * _Nullable)incrementalTagWithInteger:(NSInteger)delta;

/**
 Creates a dictionary for extending Tag’s values list with additional values
 
 Example:

 ```swift
 func addInterest(_ interest: String) {
     let tags: [AnyHashable: Any] = [
         "interests": PWTagsBuilder.appendValues(toListTag: [interest])
     ]
     Pushwoosh.configure.setTags(tags)
 }
 ```

 @param array Array of values to be added to the tag.
 
 @return Dictionary to be sent as the value for the tag
 */
+ (NSDictionary * _Nullable)appendValuesToListTag:(NSArray<NSString *> * _Nonnull)array;

/**
 Creates a dictionary for removing Tag’s values from existing values list
 
 Example:

 ```swift
 func removeInterest(_ interest: String) {
     let tags: [AnyHashable: Any] = [
         "interests": PWTagsBuilder.removeValues(fromListTag: [interest])
     ]
     Pushwoosh.configure.setTags(tags)
 }
 ```

 @param array Array of values to be removed from the tag.
 
 @return Dictionary to be sent as the value for the tag
 */
+ (NSDictionary * _Nullable)removeValuesFromListTag:(NSArray<NSString *> * _Nonnull)array;

@end
