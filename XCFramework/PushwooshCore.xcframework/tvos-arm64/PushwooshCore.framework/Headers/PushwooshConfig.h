//
//  PushwooshConfig.h
//  PushwooshCore
//
//  Created by André Kis on 16.04.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWPreferences.h>

@protocol PWMessagingDelegate;
#if TARGET_OS_IOS
@protocol PWPurchaseDelegate;
#endif

/**
 Protocol defining all SDK configuration methods.

 @discussion
 PWConfiguration is the primary interface for configuring and interacting with the Pushwoosh SDK.
 All methods are class methods accessed through `Pushwoosh.configure`.

 The protocol provides functionality for:
 - App identification and API authentication
 - Device registration for push notifications
 - User identification and segmentation via tags
 - Server communication control for GDPR compliance
 - Push notification handling and delegate management

 ## Quick Start

 ```swift
 // In AppDelegate.swift
 func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

     // Set delegate to receive notification events
     Pushwoosh.configure.setDelegate(self)

     // Register for push notifications
     Pushwoosh.configure.registerForPushNotifications()

     return true
 }
 ```

 @see PushwooshConfig
 */

// Handler type definitions
typedef void (^PushwooshRegistrationHandler)(NSString * _Nullable token, NSError * _Nullable error);
typedef void (^PushwooshGetTagsHandler)(NSDictionary * _Nullable tags);
typedef void (^PushwooshErrorHandler)(NSError * _Nullable error);

@protocol PWConfiguration <NSObject>

#pragma mark - App Configuration

/**
 Sets the Pushwoosh Application Code programmatically.

 @discussion
 The Application Code uniquely identifies your app in the Pushwoosh system.
 You can find it in the Pushwoosh Control Panel under your application settings.

 While you can set the code programmatically, the recommended approach is to configure
 it in your Info.plist file using the `Pushwoosh_APPID` key.

 @param appCode Your Pushwoosh Application Code (e.g., "XXXXX-XXXXX")

 ## Example

 Configure app code during white-label app initialization:

 ```swift
 class WhiteLabelConfigurator {

     func configure(with config: AppConfiguration) {
         // Set Pushwoosh app code based on client configuration
         Pushwoosh.configure.setAppCode(config.pushwooshAppCode)

         // Continue with other SDK setup
         Pushwoosh.configure.setDelegate(notificationHandler)
         Pushwoosh.configure.registerForPushNotifications()
     }
 }
 ```

 @note Prefer configuring via Info.plist with key `Pushwoosh_APPID` for most use cases.

 @see getAppCode
 */
+ (void)setAppCode:(NSString *_Nonnull)appCode;

/**
 Retrieves the current Pushwoosh Application Code.

 @discussion
 Returns the Application Code that was previously set via `setAppCode:` or configured in Info.plist.
 Use this to verify SDK configuration or for debugging purposes.

 @return The Pushwoosh Application Code, or nil if not configured

 ## Example

 Validate SDK configuration before proceeding:

 ```swift
 class PushwooshValidator {

     func validateConfiguration() throws {
         guard let appCode = Pushwoosh.configure.getAppCode(), !appCode.isEmpty else {
             throw ConfigurationError.missingAppCode
         }

         guard let pushToken = Pushwoosh.configure.getPushToken() else {
             Logger.warning("Push token not yet available - user may not have granted permission")
             return
         }

         Logger.info("Pushwoosh configured: appCode=\(appCode), token=\(pushToken.prefix(10))...")
     }
 }
 ```

 @see setAppCode:
 */
+ (NSString *_Nullable)getAppCode;

/**
 Retrieves the current Pushwoosh Application Code.

 @discussion
 Alias for `getAppCode`. Returns the Application Code that was previously set via `setAppCode:`
 or configured in Info.plist.

 @return The Pushwoosh Application Code, or nil if not configured

 ## Example

 Log configuration for debugging:

 ```swift
 func logPushwooshConfiguration() {
     let appCode = Pushwoosh.configure.getApplicationCode() ?? "Not configured"
     let hwid = Pushwoosh.configure.getHWID()
     let pushToken = Pushwoosh.configure.getPushToken() ?? "Not registered"

     Logger.debug("""
         Pushwoosh Configuration:
         - App Code: \(appCode)
         - HWID: \(hwid)
         - Push Token: \(pushToken.prefix(20))...
         """)
 }
 ```

 @see getAppCode
 @see setAppCode:
 */
+ (NSString *_Nullable)getApplicationCode;

/**
 Sets the Pushwoosh API Token for server-to-server communication.

 @discussion
 The API Token enables secure server-to-server communication with the Pushwoosh API.
 This is required when your backend needs to send push notifications or perform
 other API operations on behalf of the app.

 @warning Keep the API Token secure. Never expose it in client-side code that could
 be decompiled or intercepted.

 @param apiToken Your Pushwoosh API Token from the Control Panel

 ## Example

 Configure API token for server-side operations:

 ```swift
 class ServerIntegration {

     func configureForServerSidePush(apiToken: String) {
         // Set API token for server communication
         Pushwoosh.configure.setApiToken(apiToken)

         // Now the app can make authenticated API calls
         sendTestNotification()
     }

     private func sendTestNotification() {
         // Server-side push sending using the API token
         let hwid = Pushwoosh.configure.getHWID()
         PushwooshAPI.sendPush(to: hwid, message: "Test notification")
     }
 }
 ```

 @note The API Token is different from the Application Code. The Application Code identifies
 your app, while the API Token authenticates API requests.

 @see getApiToken
 */
+ (void)setApiToken:(NSString *_Nonnull)apiToken;

/**
 Retrieves the current Pushwoosh API Token.

 @return The Pushwoosh API Token, or nil if not configured

 ## Example

 Check if API access is configured:

 ```swift
 func canSendServerSidePush() -> Bool {
     guard Pushwoosh.configure.getApiToken() != nil else {
         Logger.warning("API token not configured - server-side push unavailable")
         return false
     }
     return true
 }
 ```

 @see setApiToken:
 */
+ (NSString *_Nullable)getApiToken;

#pragma mark - Device Identification

/**
 Returns the Pushwoosh Hardware ID (HWID) for this device.

 @discussion
 The HWID is a unique device identifier used in all Pushwoosh API calls and for device tracking
 in the Pushwoosh Control Panel. On iOS, this is derived from `UIDevice.identifierForVendor`.

 The HWID remains consistent across app launches and is used to:
 - Identify the device in the Pushwoosh Control Panel
 - Track user behavior and engagement
 - Target specific devices for push notifications
 - Link devices to user accounts in your backend

 @return The unique Pushwoosh device identifier (never nil)

 ## Example

 Sync device with your backend for cross-platform user tracking:

 ```swift
 class DeviceRegistrationService {

     func registerDeviceWithBackend(userId: String) {
         let hwid = Pushwoosh.configure.getHWID()
         let pushToken = Pushwoosh.configure.getPushToken()

         let deviceInfo: [String: Any] = [
             "hwid": hwid,
             "userId": userId,
             "pushToken": pushToken ?? "",
             "platform": "ios",
             "appVersion": Bundle.main.appVersion,
             "osVersion": UIDevice.current.systemVersion
         ]

         APIClient.shared.post("/api/devices/register", body: deviceInfo) { result in
             switch result {
             case .success:
                 Logger.info("Device registered with backend: \(hwid)")
             case .failure(let error):
                 Logger.error("Device registration failed: \(error)")
             }
         }
     }
 }
 ```

 @note The HWID is generated on first SDK initialization and persists across app launches.
 It may change if the user reinstalls all apps from the same vendor.

 @see getPushToken
 @see getUserId
 */
+ (NSString *_Nonnull)getHWID;

/**
 Retrieves the current device push token.

 @discussion
 Returns the APNs device token as a hexadecimal string. The token is used by Apple's
 Push Notification service to deliver notifications to this specific device.

 The push token becomes available after:
 1. Calling `registerForPushNotifications`
 2. User granting notification permission
 3. Successful registration with APNs

 @return The device push token as a hexadecimal string, or nil if not yet registered

 ## Example

 Send push token to your backend for server-side notifications:

 ```swift
 class PushTokenManager {

     func syncPushTokenIfNeeded() {
         guard let pushToken = Pushwoosh.configure.getPushToken() else {
             Logger.debug("Push token not available yet")
             return
         }

         // Check if token has changed since last sync
         let lastSyncedToken = UserDefaults.standard.string(forKey: "lastSyncedPushToken")
         guard pushToken != lastSyncedToken else {
             return // Token unchanged, no need to sync
         }

         let hwid = Pushwoosh.configure.getHWID()

         APIClient.shared.post("/api/push-tokens", body: [
             "hwid": hwid,
             "pushToken": pushToken,
             "platform": "ios"
         ]) { result in
             if case .success = result {
                 UserDefaults.standard.set(pushToken, forKey: "lastSyncedPushToken")
                 Logger.info("Push token synced successfully")
             }
         }
     }
 }
 ```

 @note The push token may change over time. Apple recommends re-registering on each app launch.

 @see registerForPushNotifications
 @see getHWID
 */
+ (NSString *_Nullable)getPushToken;

#pragma mark - Server Communication Control

/**
 Checks whether communication with Pushwoosh servers is currently allowed.

 @discussion
 Returns the current server communication status. When communication is disabled,
 the SDK will not send any data to Pushwoosh servers, including:
 - Device registration
 - Tag updates
 - Analytics events
 - Push token updates

 This is useful for GDPR compliance where users can opt out of data collection.

 @return YES if server communication is allowed, NO otherwise

 ## Example

 Check status before performing operations:

 ```swift
 class AnalyticsManager {

     func trackEvent(_ event: String, properties: [String: Any]) {
         // Check if Pushwoosh communication is allowed
         guard Pushwoosh.configure.isServerCommunicationAllowed() else {
             Logger.debug("Pushwoosh communication disabled - skipping event tracking")
             return
         }

         // Track event with Pushwoosh
         Pushwoosh.configure.setTags([
             "last_event": event,
             "last_event_date": Date()
         ])
     }
 }
 ```

 @see startServerCommunication
 @see stopServerCommunication
 */
+ (BOOL)isServerCommunicationAllowed;

/**
 Enables communication with Pushwoosh servers.

 @discussion
 Starts or resumes communication with Pushwoosh servers. This allows the SDK to send and receive
 data including device registration, tags, push tokens, and analytics.

 Call this method after the user has consented to data collection, or to re-enable
 communication after it was previously stopped.

 ## Example

 Enable communication after GDPR consent:

 ```swift
 class ConsentManager {

     func handleUserConsent(accepted: Bool) {
         if accepted {
             // User accepted data collection
             Pushwoosh.configure.startServerCommunication()

             // Register for push after consent
             Pushwoosh.configure.registerForPushNotifications()

             // Sync any pending user data
             syncPendingUserData()

             Logger.info("User consented - Pushwoosh communication enabled")
         } else {
             // User declined - disable communication
             Pushwoosh.configure.stopServerCommunication()
             Logger.info("User declined - Pushwoosh communication disabled")
         }

         UserDefaults.standard.set(accepted, forKey: "gdprConsent")
     }
 }
 ```

 @note Server communication is enabled by default. Only use this method if you previously
 called `stopServerCommunication`.

 @see stopServerCommunication
 @see isServerCommunicationAllowed
 */
+ (void)startServerCommunication;

/**
 Disables communication with Pushwoosh servers.

 @discussion
 Stops all communication with Pushwoosh servers. The SDK will not send or receive any data
 including device registration, tags, push tokens, and analytics.

 Use this method to comply with privacy regulations (GDPR, CCPA) or honor user preferences
 for data transmission. Push notifications will still be delivered to the device by APNs,
 but no tracking or analytics data will be sent to Pushwoosh.

 ## Example

 Handle GDPR opt-out in settings:

 ```swift
 class PrivacySettingsViewController: UIViewController {

     @IBOutlet weak var dataCollectionSwitch: UISwitch!

     @IBAction func dataCollectionToggled(_ sender: UISwitch) {
         if sender.isOn {
             showConsentDialog { accepted in
                 if accepted {
                     Pushwoosh.configure.startServerCommunication()
                     self.showToast("Data collection enabled")
                 } else {
                     sender.isOn = false
                 }
             }
         } else {
             Pushwoosh.configure.stopServerCommunication()

             // Also unregister from push if required by your privacy policy
             Pushwoosh.configure.unregisterForPushNotifications { error in
                 if error == nil {
                     self.showToast("Data collection disabled")
                 }
             }
         }
     }

     private func showConsentDialog(completion: @escaping (Bool) -> Void) {
         let alert = UIAlertController(
             title: "Data Collection",
             message: "We collect data to personalize your experience and send relevant notifications.",
             preferredStyle: .alert
         )
         alert.addAction(UIAlertAction(title: "Accept", style: .default) { _ in
             completion(true)
         })
         alert.addAction(UIAlertAction(title: "Decline", style: .cancel) { _ in
             completion(false)
         })
         present(alert, animated: true)
     }
 }
 ```

 @note Push notifications will still be received by the device but won't be tracked by Pushwoosh.

 @see startServerCommunication
 @see isServerCommunicationAllowed
 */
+ (void)stopServerCommunication;

#pragma mark - Tags and Segmentation

/**
 Sets user tags for device segmentation.

 @discussion
 Tags are key-value pairs that enable targeted push notifications based on user attributes
 and behavior. Use tags to segment your audience and send personalized messages to specific
 user groups.

 ## Supported Tag Types

 | Type | Example | Description |
 |------|---------|-------------|
 | String | `"city": "New York"` | Text values |
 | Integer | `"age": 25` | Numeric values |
 | Boolean | `"isPremium": true` | True/false values |
 | List | `"interests": ["sports", "music"]` | Arrays of strings |
 | Date | `"lastPurchase": Date()` | NSDate objects |

 @param tags Dictionary of tag names and values to set for the current device

 ## Example

 Update user profile tags after account changes:

 ```swift
 class UserProfileManager {

     func updateUserTags(for user: User) {
         var tags: [String: Any] = [
             "user_id": user.id,
             "email_verified": user.isEmailVerified,
             "account_type": user.accountType.rawValue,
             "signup_date": user.createdAt,
             "app_version": Bundle.main.appVersion
         ]

         // Add subscription info if premium
         if let subscription = user.subscription {
             tags["subscription_tier"] = subscription.tier.rawValue
             tags["subscription_expiry"] = subscription.expiryDate
             tags["is_premium"] = true
         } else {
             tags["is_premium"] = false
         }

         // Add user preferences
         if !user.interests.isEmpty {
             tags["interests"] = user.interests
         }

         // Add location if available
         if let location = user.location {
             tags["country"] = location.country
             tags["city"] = location.city
             tags["timezone"] = location.timezone
         }

         Pushwoosh.configure.setTags(tags)
         Logger.debug("User tags updated: \(tags.keys.joined(separator: ", "))")
     }

     func trackPurchase(product: Product, amount: Decimal) {
         Pushwoosh.configure.setTags([
             "last_purchase_date": Date(),
             "last_purchase_amount": NSDecimalNumber(decimal: amount),
             "last_purchase_category": product.category,
             "total_purchases": incrementTag("total_purchases")
         ])
     }
 }
 ```

 @note Tags are sent asynchronously and do not block the calling thread.
 @note Tag names must be created in the Pushwoosh Control Panel before use.
 @note Calling setTags multiple times will merge tags, not replace them entirely.

 @see loadTags:error:
 */
+ (void)setTags:(NSDictionary *_Nonnull)tags;

/**
 Sets user tags with a completion handler for confirmation.

 @discussion
 Similar to `setTags:` but provides feedback when the operation completes.
 Use this when you need to:

 - Confirm tags were successfully set before proceeding
 - Implement retry logic on failure
 - Update UI based on tag update status
 - Chain multiple operations that depend on tag updates

 @param tags Dictionary of tag names and values to set for the current device.
             Supported value types: NSString, NSNumber, NSArray (for list tags), NSNull (to delete).
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError describing the failure.

 ## Example

 Update subscription status with confirmation and retry:

 ```swift
 class SubscriptionManager {

     private let maxRetries = 3

     func updateSubscriptionStatus(_ subscription: Subscription,
                                   completion: @escaping (Result<Void, Error>) -> Void) {
         updateWithRetry(subscription: subscription, attempt: 1, completion: completion)
     }

     private func updateWithRetry(subscription: Subscription, attempt: Int,
                                  completion: @escaping (Result<Void, Error>) -> Void) {

         let tags: [String: Any] = [
             "subscription_tier": subscription.tier.rawValue,
             "subscription_status": subscription.isActive ? "active" : "expired",
             "subscription_expiry": ISO8601DateFormatter().string(from: subscription.expiryDate),
             "is_premium": subscription.tier != .free,
             "features_enabled": subscription.enabledFeatures.map { $0.rawValue }
         ]

         Pushwoosh.configure.setTags(tags) { [weak self] error in
             if let error = error {
                 if attempt < (self?.maxRetries ?? 3) {
                     let delay = Double(attempt) * 2.0
                     DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                         self?.updateWithRetry(subscription: subscription,
                                              attempt: attempt + 1,
                                              completion: completion)
                     }
                 } else {
                     completion(.failure(error))
                 }
                 return
             }

             Analytics.track("subscription_tags_updated", properties: [
                 "tier": subscription.tier.rawValue
             ])
             completion(.success(()))
         }
     }
 }
 ```

 @note The completion block is called on an arbitrary queue.
 @note Failed tag updates are not automatically retried by the SDK.

 @see setTags:
 @see loadTags:error:
 */
+ (void)setTags:(NSDictionary *_Nonnull)tags completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Sets tags for a specific email address in email campaigns.

 @discussion
 Associates tags with an email address independently of the current device.
 This is used for email-specific segmentation in Pushwoosh Email campaigns.

 Email tags are separate from device tags:
 - Device tags: Associated with push token, used for push segmentation
 - Email tags: Associated with email address, used for email segmentation

 Use this for email-specific attributes like email preferences, engagement metrics,
 or email-only campaign targeting.

 @param tags Dictionary of tag names and values to associate with the email.
             Supported value types: NSString, NSNumber, NSArray, NSNull (to delete).
 @param email The email address to associate tags with. Must be a valid email format.

 ## Example

 Update email campaign preferences:

 ```swift
 class EmailPreferencesManager {

     func updateEmailPreferences(for email: String, preferences: EmailPreferences) {
         let tags: [String: Any] = [
             "email_frequency": preferences.frequency.rawValue,
             "email_categories": preferences.subscribedCategories.map { $0.rawValue },
             "email_format": preferences.preferHTML ? "html" : "plain",
             "unsubscribed_categories": preferences.unsubscribedCategories.map { $0.rawValue },
             "last_preference_update": ISO8601DateFormatter().string(from: Date())
         ]

         Pushwoosh.configure.setEmailTags(tags, forEmail: email)
     }

     func trackEmailEngagement(email: String, campaignId: String, action: EmailAction) {
         let engagementTags: [String: Any] = [
             "last_email_open": ISO8601DateFormatter().string(from: Date()),
             "email_engagement_score": calculateEngagementScore(for: email),
             "last_clicked_campaign": action == .clicked ? campaignId : NSNull()
         ]

         Pushwoosh.configure.setEmailTags(engagementTags, forEmail: email)
     }
 }
 ```

 @note Email tags require Email channel to be enabled in your Pushwoosh plan.
 @note The email address must be previously registered via `setEmail:` or `setEmails:`.

 @see setEmailTags:forEmail:completion:
 @see setEmail:
 */
+ (void)setEmailTags:(NSDictionary *_Nonnull)tags forEmail:(NSString *_Nonnull)email;

/**
 Sets tags for a specific email address with a completion handler.

 @discussion
 Same as `setEmailTags:forEmail:` but provides confirmation when the operation completes.
 Use this when you need to verify tags were set before proceeding with other operations.

 @param tags Dictionary of tag names and values to associate with the email.
 @param email The email address to associate tags with.
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Verify email and update tags with confirmation:

 ```swift
 class EmailVerificationService {

     func completeEmailVerification(email: String, verificationCode: String,
                                    completion: @escaping (Result<Void, Error>) -> Void) {

         APIClient.shared.verifyEmail(email, code: verificationCode) { result in
             switch result {
             case .success:
                 let verificationTags: [String: Any] = [
                     "email_verified": true,
                     "verification_date": ISO8601DateFormatter().string(from: Date()),
                     "verification_method": "code"
                 ]

                 Pushwoosh.configure.setEmailTags(verificationTags, forEmail: email) { error in
                     if let error = error {
                         Logger.warning("Email tags update failed: \(error.localizedDescription)")
                         // Continue anyway - email is verified on backend
                     }

                     // Also update device tags
                     Pushwoosh.configure.setTags(["has_verified_email": true])

                     completion(.success(()))
                 }

             case .failure(let error):
                 completion(.failure(error))
             }
         }
     }
 }
 ```

 @see setEmailTags:forEmail:
 @see setEmail:completion:
 */
+ (void)setEmailTags:(NSDictionary *_Nonnull)tags forEmail:(NSString *_Nonnull)email completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Retrieves the current device's tags from the Pushwoosh server.

 @discussion
 Alternative method name for `loadTags:error:` following common SDK naming conventions.
 Fetches all tags currently associated with this device from the Pushwoosh server.

 @param successHandler Block called when tags are successfully retrieved.
                       Receives a dictionary containing all device tags, or nil if no tags are set.
 @param errorHandler Block called if the request fails.
                     Receives an NSError describing the failure.

 ## Example

 Verify tag updates were applied:

 ```swift
 class TagVerificationService {

     func verifyTagsApplied(expectedTags: [String: Any],
                           completion: @escaping (Bool) -> Void) {

         Pushwoosh.configure.getTags({ tags in
             guard let serverTags = tags else {
                 completion(false)
                 return
             }

             let allMatch = expectedTags.allSatisfy { key, expectedValue in
                 guard let serverValue = serverTags[key] else { return false }

                 if let expected = expectedValue as? String,
                    let server = serverValue as? String {
                     return expected == server
                 }
                 if let expected = expectedValue as? NSNumber,
                    let server = serverValue as? NSNumber {
                     return expected == server
                 }
                 return false
             }

             completion(allMatch)

         }, onFailure: { error in
             Logger.error("Tag verification failed: \(error?.localizedDescription ?? "Unknown")")
             completion(false)
         })
     }
 }
 ```

 @see loadTags:error:
 @see setTags:
 */
+ (void)getTags:(PushwooshGetTagsHandler _Nullable)successHandler onFailure:(PushwooshErrorHandler _Nullable)errorHandler;

/**
 Retrieves the current device's tags from the Pushwoosh server.

 @discussion
 Fetches all tags currently set for this device. Tags are returned as a dictionary where keys
 are tag names and values are the corresponding tag values.

 Use this to sync local app state with server-side tags, or to verify tag values.

 @param successBlock Block called when tags are successfully retrieved.
                     Receives a dictionary containing all device tags.
 @param errorBlock Block called if the request fails.
                   Receives an error describing the failure.

 ## Example

 Sync user preferences from Pushwoosh tags on app launch:

 ```swift
 class UserPreferencesSync {

     func syncPreferencesFromServer(completion: @escaping (Result<UserPreferences, Error>) -> Void) {
         Pushwoosh.configure.loadTags({ [weak self] tags in
             guard let tags = tags else {
                 completion(.success(UserPreferences.default))
                 return
             }

             let preferences = UserPreferences(
                 isPremium: tags["is_premium"] as? Bool ?? false,
                 subscriptionTier: tags["subscription_tier"] as? String,
                 favoriteCategories: tags["favorite_categories"] as? [String] ?? [],
                 notificationPreferences: self?.parseNotificationPrefs(from: tags) ?? .default,
                 lastSyncDate: Date()
             )

             // Cache locally
             self?.cachePreferences(preferences)

             completion(.success(preferences))
             Logger.info("User preferences synced from server")

         }, error: { error in
             Logger.error("Failed to load tags: \(error?.localizedDescription ?? "Unknown error")")

             // Fall back to cached preferences
             if let cached = self.loadCachedPreferences() {
                 completion(.success(cached))
             } else {
                 completion(.failure(error ?? PushwooshError.unknown))
             }
         })
     }

     private func parseNotificationPrefs(from tags: [AnyHashable: Any]) -> NotificationPreferences {
         return NotificationPreferences(
             marketingEnabled: tags["marketing_notifications"] as? Bool ?? true,
             transactionalEnabled: tags["transactional_notifications"] as? Bool ?? true,
             frequencyCap: tags["notification_frequency"] as? String ?? "normal"
         )
     }
 }
 ```

 @note The operation is performed asynchronously.

 @see setTags:
 */
+ (void)loadTags:(void (^_Nullable)(NSDictionary *_Nullable tags))successBlock error:(void (^_Nullable)(NSError *_Nullable error))errorBlock;

#pragma mark - Push Registration

/**
 Registers the device for push notifications.

 @discussion
 This method initiates the push notification registration process:

 1. Requests user permission to display notifications (alert, badge, sound)
 2. Registers the device with Apple Push Notification service (APNs)
 3. Sends the device token to Pushwoosh servers

 The permission dialog is shown only once per app installation. If the user denies permission,
 subsequent calls will not show the dialog. Users must manually enable notifications in Settings.

 ## Example

 Standard registration in AppDelegate:

 ```swift
 class AppDelegate: UIResponder, UIApplicationDelegate, PWMessagingDelegate {

     func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

         // Configure delegate first to receive callbacks
         Pushwoosh.configure.setDelegate(self)

         // Enable foreground notification display
         Pushwoosh.configure.setShowPushnotificationAlert(true)

         // Register for push notifications
         Pushwoosh.configure.registerForPushNotifications()

         return true
     }

     // MARK: - PWMessagingDelegate

     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
         Logger.info("Push received: \(message.title ?? "No title")")

         // Handle silent push or update UI
         if message.isContentAvailable {
             performBackgroundFetch()
         }
     }

     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
         Logger.info("Push opened: \(message.title ?? "No title")")

         // Handle deep link if present
         if let link = message.link, let url = URL(string: link) {
             DeepLinkHandler.shared.handle(url)
         }

         // Track notification open in analytics
         Analytics.track("notification_opened", properties: [
             "message_id": message.messageCode ?? "",
             "campaign_id": message.campaignId
         ])
     }
 }
 ```

 Deferred registration after onboarding:

 ```swift
 class OnboardingViewController: UIViewController {

     @IBAction func enableNotificationsTapped(_ sender: UIButton) {
         // Show explanation before system prompt
         showNotificationBenefits { [weak self] in
             Pushwoosh.configure.registerForPushNotifications()
             self?.proceedToNextStep()
         }
     }

     private func showNotificationBenefits(completion: @escaping () -> Void) {
         let alert = UIAlertController(
             title: "Stay Updated",
             message: "Enable notifications to receive order updates, exclusive offers, and important alerts.",
             preferredStyle: .alert
         )
         alert.addAction(UIAlertAction(title: "Enable", style: .default) { _ in
             completion()
         })
         alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
             self.proceedToNextStep()
         })
         present(alert, animated: true)
     }
 }
 ```

 @note For iOS 10+, the SDK uses UNUserNotificationCenter for registration.

 @see handlePushRegistration:
 @see unregisterForPushNotifications:
 @see setDelegate:
 */
+ (void)registerForPushNotifications;

/**
 Registers the device for push notifications with a completion handler.

 @discussion
 This method combines system permission request with Pushwoosh server registration.
 The completion handler provides feedback on both operations, allowing you to:

 - Update UI based on registration status
 - Track registration analytics
 - Handle errors gracefully with retry logic
 - Sync push token with your backend server

 @param completion Block called when registration completes, providing the push token or an error.
                   Token is nil if registration failed or user denied permission.

 ## Example

 Handle registration in onboarding flow with analytics tracking:

 ```swift
 class OnboardingViewController: UIViewController {

     func enableNotificationsTapped() {
         showLoadingState()

         Pushwoosh.configure.registerForPushNotifications { [weak self] token, error in
             DispatchQueue.main.async {
                 self?.hideLoadingState()

                 if let error = error {
                     Analytics.track("push_registration_failed", properties: [
                         "error": error.localizedDescription
                     ])
                     self?.showRetryOption()
                     return
                 }

                 if let token = token {
                     Analytics.track("push_registration_success")
                     self?.syncTokenWithBackend(token)
                     self?.proceedToNextStep()
                 } else {
                     Analytics.track("push_permission_denied")
                     self?.showPermissionDeniedInfo()
                 }
             }
         }
     }

     private func syncTokenWithBackend(_ token: String) {
         APIClient.shared.updatePushToken(token) { result in
             if case .failure(let error) = result {
                 Logger.error("Backend sync failed: \(error)")
             }
         }
     }
 }
 ```

 @note The completion block is called on an arbitrary queue. Dispatch to main queue for UI updates.

 @see registerForPushNotifications
 @see handlePushRegistration:
 */
+ (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler _Nullable)completion;

/**
 Registers the device for push notifications with initial tags.

 @discussion
 Combines push notification registration with tag assignment in a single operation.
 This is more efficient than calling registerForPushNotifications and setTags separately,
 as tags are sent to the server along with the registration request.

 Use this method when you have user attributes available at the time of registration,
 such as during onboarding or after user authentication.

 @param tags Dictionary of tag names and values to set during registration.
             Supported value types: NSString, NSNumber, NSArray (for list tags).

 ## Example

 Register with user attributes after sign-up:

 ```swift
 class SignUpCoordinator {

     func completeSignUp(user: User, source: SignUpSource) {
         let registrationTags: [String: Any] = [
             "user_type": user.accountType.rawValue,
             "signup_source": source.analyticsValue,
             "signup_date": ISO8601DateFormatter().string(from: Date()),
             "interests": user.selectedInterests,
             "language": Locale.current.languageCode ?? "en",
             "app_version": Bundle.main.appVersion
         ]

         Pushwoosh.configure.registerForPushNotifications(with: registrationTags)

         Pushwoosh.configure.setUserId(user.id)
         Pushwoosh.configure.setEmail(user.email)
     }
 }

 extension Bundle {
     var appVersion: String {
         infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
     }
 }
 ```

 @note Tags must be pre-created in the Pushwoosh Control Panel.
 @note If registration fails, tags will not be set.

 @see registerForPushNotifications
 @see registerForPushNotificationsWith:completion:
 @see setTags:
 */
+ (void)registerForPushNotificationsWith:(NSDictionary * _Nonnull)tags;

/**
 Registers the device for push notifications with initial tags and a completion handler.

 @discussion
 The most comprehensive registration method that combines:
 - System push permission request
 - Pushwoosh server registration
 - Initial tag assignment
 - Completion callback for status handling

 This is ideal for onboarding flows where you need to track registration success
 and have user data available to set as tags.

 @param tags Dictionary of tag names and values to set during registration.
             Supported value types: NSString, NSNumber, NSArray (for list tags).
 @param completion Block called when registration completes.
                   Provides the push token on success, or an error on failure.

 ## Example

 Complete onboarding registration with error handling and analytics:

 ```swift
 class OnboardingManager {

     func completeOnboarding(preferences: UserPreferences,
                            completion: @escaping (Result<Void, Error>) -> Void) {

         let onboardingTags: [String: Any] = [
             "onboarding_completed": true,
             "notification_preferences": preferences.categories.map { $0.rawValue },
             "preferred_time": preferences.preferredNotificationTime,
             "timezone": TimeZone.current.identifier,
             "device_language": Locale.current.languageCode ?? "en"
         ]

         Pushwoosh.configure.registerForPushNotifications(with: onboardingTags) { token, error in
             if let error = error {
                 Analytics.track("onboarding_push_failed", properties: [
                     "error_code": (error as NSError).code,
                     "error_domain": (error as NSError).domain
                 ])
                 completion(.failure(error))
                 return
             }

             let pushEnabled = token != nil
             Analytics.track("onboarding_completed", properties: [
                 "push_enabled": pushEnabled,
                 "categories_count": preferences.categories.count
             ])

             UserDefaults.standard.set(true, forKey: "onboarding_completed")
             completion(.success(()))
         }
     }
 }
 ```

 @note The completion block is called on an arbitrary queue.
 @note Tags are only set if registration succeeds.

 @see registerForPushNotifications
 @see registerForPushNotificationsWith:
 */
+ (void)registerForPushNotificationsWith:(NSDictionary * _Nonnull)tags completion:(PushwooshRegistrationHandler _Nullable)completion;

/**
 Registers an SMS number for SMS messaging campaigns.

 @discussion
 Associates a phone number with the current device for SMS marketing campaigns.
 This enables omnichannel messaging where users can receive communications via
 both push notifications and SMS.

 The phone number must be in E.164 international format:
 - Start with '+' followed by country code
 - No spaces, dashes, or parentheses
 - Examples: "+14155551234" (US), "+447911123456" (UK), "+491711234567" (Germany)

 @param number The phone number in E.164 international format.

 ## Example

 Register SMS during phone verification flow:

 ```swift
 class PhoneVerificationController {

     func verifyPhoneNumber(_ phoneNumber: String, code: String,
                           completion: @escaping (Result<Void, Error>) -> Void) {

         APIClient.shared.verifyCode(phone: phoneNumber, code: code) { [weak self] result in
             switch result {
             case .success:
                 let normalizedNumber = self?.normalizeToE164(phoneNumber) ?? phoneNumber
                 Pushwoosh.configure.registerSmsNumber(normalizedNumber)

                 Pushwoosh.configure.setTags([
                     "phone_verified": true,
                     "sms_opted_in": true,
                     "phone_country": self?.extractCountryCode(from: normalizedNumber) ?? ""
                 ])

                 completion(.success(()))

             case .failure(let error):
                 completion(.failure(error))
             }
         }
     }

     private func normalizeToE164(_ phone: String) -> String {
         let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
         return phone.hasPrefix("+") ? "+\(digits)" : "+1\(digits)"
     }

     private func extractCountryCode(from e164: String) -> String {
         // Extract country code from E.164 format
         guard e164.hasPrefix("+") else { return "" }
         let countryCodeLength = e164.count > 12 ? 2 : (e164.count > 11 ? 1 : 1)
         return String(e164.dropFirst().prefix(countryCodeLength))
     }
 }
 ```

 @note SMS messaging requires SMS channel to be enabled in your Pushwoosh plan.
 @note Ensure compliance with local SMS marketing regulations (TCPA, GDPR, etc.).

 @see registerWhatsappNumber:
 @see setTags:
 */
+ (void)registerSmsNumber:(NSString * _Nonnull)number;

/**
 Registers a WhatsApp number for WhatsApp Business messaging.

 @discussion
 Associates a WhatsApp number with the current device for WhatsApp Business API
 messaging campaigns. This enables rich messaging with images, documents, and
 interactive buttons through WhatsApp.

 The phone number must be in E.164 international format:
 - Start with '+' followed by country code
 - No spaces, dashes, or parentheses
 - Must be a valid WhatsApp-enabled number

 @param number The phone number in E.164 international format.

 ## Example

 Register WhatsApp during communication preferences setup:

 ```swift
 class CommunicationPreferencesManager {

     struct Preferences {
         var pushEnabled: Bool
         var smsEnabled: Bool
         var whatsappEnabled: Bool
         var whatsappNumber: String?
     }

     func savePreferences(_ preferences: Preferences) {
         // Register WhatsApp if user opted in and provided number
         if preferences.whatsappEnabled, let number = preferences.whatsappNumber {
             let normalizedNumber = normalizePhoneNumber(number)
             Pushwoosh.configure.registerWhatsappNumber(normalizedNumber)
         }

         // Update channel preferences tags
         Pushwoosh.configure.setTags([
             "channel_push": preferences.pushEnabled,
             "channel_sms": preferences.smsEnabled,
             "channel_whatsapp": preferences.whatsappEnabled
         ])
     }

     private func normalizePhoneNumber(_ phone: String) -> String {
         let digits = phone.filter { $0.isNumber }
         return phone.hasPrefix("+") ? "+\(digits)" : "+\(digits)"
     }
 }
 ```

 @note WhatsApp messaging requires WhatsApp Business API integration.
 @note Users must have WhatsApp installed and the number must be registered with WhatsApp.

 @see registerSmsNumber:
 @see setTags:
 */
+ (void)registerWhatsappNumber:(NSString * _Nonnull)number;

/**
 Unregisters the device from push notifications.

 @discussion
 Removes the device from receiving push notifications:

 1. Notifies Pushwoosh servers to stop sending notifications to this device
 2. Removes the device token from Pushwoosh

 Use this when the user logs out, deletes their account, or explicitly disables notifications.

 @param completion Block called when unregistration completes.
                   Receives nil on success or an NSError on failure.

 ## Example

 Unregister during user logout:

 ```swift
 class AuthenticationManager {

     func logout(completion: @escaping (Result<Void, Error>) -> Void) {
         // Show loading indicator
         LoadingIndicator.show()

         // First, unregister from push to stop receiving notifications for this user
         Pushwoosh.configure.unregisterForPushNotifications { [weak self] error in
             if let error = error {
                 Logger.warning("Push unregistration failed: \(error.localizedDescription)")
                 // Continue with logout even if unregistration fails
             }

             // Clear user session
             self?.clearUserSession()

             // Clear user tags
             Pushwoosh.configure.setTags([
                 "logged_in": false,
                 "user_id": NSNull(),
                 "email": NSNull()
             ])

             // Stop server communication if required by privacy policy
             if UserDefaults.standard.bool(forKey: "clearDataOnLogout") {
                 Pushwoosh.configure.stopServerCommunication()
             }

             LoadingIndicator.hide()
             completion(.success(()))
         }
     }

     private func clearUserSession() {
         KeychainManager.shared.clearCredentials()
         UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
         CoreDataManager.shared.clearUserData()
     }
 }
 ```

 @note Unregistration is permanent until `registerForPushNotifications` is called again.
 @note The device may still receive notifications that were already in transit.

 @see registerForPushNotifications
 */
+ (void)unregisterForPushNotifications:(void (^_Nullable)(NSError *_Nullable error))completion;

#pragma mark - User Identity

/**
 Associates an email address with the current device.

 @discussion
 Register an email for the current user to enable:
 - Email-based campaigns and targeting
 - Cross-device user identification
 - Email channel for multi-channel messaging

 @param email The user's email address (must be valid and non-empty)

 ## Example

 Set email after user verification:

 ```swift
 class UserAccountManager {

     func handleEmailVerification(email: String, verificationCode: String) async throws {
         // Verify email with backend
         try await APIClient.shared.verifyEmail(email: email, code: verificationCode)

         // Update Pushwoosh with verified email
         Pushwoosh.configure.setEmail(email)

         // Update tags to reflect verified status
         Pushwoosh.configure.setTags([
             "email_verified": true,
             "email_verified_date": Date()
         ])

         Logger.info("Email verified and synced with Pushwoosh: \(email)")
     }

     func handleProfileUpdate(email: String?, phone: String?) {
         if let email = email, !email.isEmpty {
             Pushwoosh.configure.setEmail(email)
         }

         // Update other contact methods via tags
         var tags: [String: Any] = [:]
         if let phone = phone {
             tags["phone_number"] = phone
         }
         if !tags.isEmpty {
             Pushwoosh.configure.setTags(tags)
         }
     }
 }
 ```

 @note The email is sent to Pushwoosh servers asynchronously.
 @note For multi-channel email messaging, use the Email module separately.

 @see setUserId:
 @see setTags:
 */
+ (void)setEmail:(NSString *_Nonnull)email;

/**
 Associates an email address with the current device with completion confirmation.

 @discussion
 Same as `setEmail:` but provides callback when the server registration completes.
 Use this when you need to:

 - Verify email was registered before showing confirmation UI
 - Chain operations that depend on email registration
 - Implement error handling and retry logic

 @param email The user's email address. Must be a valid email format.
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Register email during account setup with verification:

 ```swift
 class AccountSetupController {

     func submitEmail(_ email: String) {
         guard isValidEmail(email) else {
             showError("Please enter a valid email address")
             return
         }

         showLoadingState()

         Pushwoosh.configure.setEmail(email) { [weak self] error in
             DispatchQueue.main.async {
                 self?.hideLoadingState()

                 if let error = error {
                     Logger.error("Email registration failed: \(error.localizedDescription)")
                     self?.showRetryOption(for: email)
                     return
                 }

                 // Email registered successfully - update tags
                 let domain = email.components(separatedBy: "@").last ?? ""
                 Pushwoosh.configure.setTags([
                     "has_email": true,
                     "email_domain": domain,
                     "email_type": self?.classifyEmailDomain(domain) ?? "personal"
                 ])

                 self?.proceedToNextStep()
             }
         }
     }

     private func classifyEmailDomain(_ domain: String) -> String {
         let businessDomains = ["company.com", "enterprise.org"]
         let educationDomains = ["edu", "ac.uk", "edu.au"]

         if businessDomains.contains(domain) { return "business" }
         if educationDomains.contains(where: { domain.hasSuffix($0) }) { return "education" }
         return "personal"
     }
 }
 ```

 @note The completion block is called on an arbitrary queue.

 @see setEmail:
 @see setEmails:completion:
 */
+ (void)setEmail:(NSString *_Nonnull)email completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Registers multiple email addresses associated with the current user.

 @discussion
 Associates multiple email addresses with the current device for omnichannel
 email campaigns. This is useful when users have multiple email addresses
 (work, personal, etc.) and want to receive communications on all of them.

 All provided emails will be linked to the same device and user ID,
 enabling unified targeting across all addresses.

 @param emails Array of email address strings. Each must be a valid email format.

 ## Example

 Register multiple emails from user profile:

 ```swift
 class UserProfileManager {

     func syncEmailsFromProfile(_ profile: UserProfile) {
         var emails: [String] = []

         if let primary = profile.primaryEmail {
             emails.append(primary)
         }
         if let secondary = profile.secondaryEmail {
             emails.append(secondary)
         }
         if let work = profile.workEmail {
             emails.append(work)
         }

         guard !emails.isEmpty else { return }

         Pushwoosh.configure.setEmails(emails)

         // Update tags with email count
         Pushwoosh.configure.setTags([
             "email_count": emails.count,
             "has_work_email": profile.workEmail != nil,
             "has_multiple_emails": emails.count > 1
         ])
     }
 }
 ```

 @note Previous emails are replaced, not appended.
 @note All emails must be valid format or the entire operation may fail.

 @see setEmails:completion:
 @see setEmail:
 */
+ (void)setEmails:(NSArray *_Nonnull)emails;

/**
 Registers multiple email addresses with completion handler.

 @discussion
 Same as `setEmails:` but provides callback when the server registration completes.
 Use this for confirmation UI or to chain dependent operations.

 @param emails Array of email address strings.
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Import emails from third-party login with confirmation:

 ```swift
 class SocialLoginHandler {

     func handleGoogleSignIn(_ user: GIDGoogleUser) {
         var emails: [String] = []

         // Primary email from Google
         if let email = user.profile?.email {
             emails.append(email)
         }

         // Additional emails from Google profile if available
         if let additionalEmails = user.profile?.additionalEmails {
             emails.append(contentsOf: additionalEmails)
         }

         Pushwoosh.configure.setEmails(emails) { error in
             if let error = error {
                 Analytics.track("email_sync_failed", properties: [
                     "provider": "google",
                     "email_count": emails.count,
                     "error": error.localizedDescription
                 ])
                 return
             }

             Analytics.track("email_sync_success", properties: [
                 "provider": "google",
                 "email_count": emails.count
             ])

             // Set user ID from Google
             Pushwoosh.configure.setUserId(user.userID ?? "")
         }
     }
 }
 ```

 @see setEmails:
 @see setEmail:completion:
 */
+ (void)setEmails:(NSArray *_Nonnull)emails completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Sets a custom user identifier for the current device.

 @discussion
 Associates a unique user ID with the device to:
 - Track users across multiple devices
 - Enable user-based targeting in campaigns
 - Link push engagement to user accounts in your analytics
 - Support user migration between devices

 @param userId The custom user identifier (e.g., database ID, UUID)

 ## Example

 Set user ID after successful login:

 ```swift
 class AuthenticationService {

     func handleSuccessfulLogin(user: User) {
         // Set user ID for cross-device tracking
         Pushwoosh.configure.setUserId(user.id)

         // Set email if available
         if let email = user.email {
             Pushwoosh.configure.setEmail(email)
         }

         // Update user profile tags
         Pushwoosh.configure.setTags([
             "logged_in": true,
             "login_date": Date(),
             "login_count": incrementLoginCount(),
             "account_type": user.accountType.rawValue,
             "subscription_status": user.subscription?.status.rawValue ?? "none"
         ])

         // Sync with analytics platforms
         Analytics.identify(user.id, traits: [
             "email": user.email ?? "",
             "pushwoosh_hwid": Pushwoosh.configure.getHWID()
         ])

         Logger.info("User logged in: \(user.id)")
     }

     func handleAccountDeletion() {
         // Clear user identity
         Pushwoosh.configure.setUserId("")

         // Clear all user data tags
         Pushwoosh.configure.setTags([
             "logged_in": false,
             "user_id": NSNull(),
             "email": NSNull(),
             "account_deleted": true,
             "deletion_date": Date()
         ])

         // Unregister from push
         Pushwoosh.configure.unregisterForPushNotifications { _ in }
     }
 }
 ```

 @note The user ID is sent to Pushwoosh servers asynchronously.
 @note Setting nil or empty string will reset to using HWID as the user identifier.

 @see getUserId
 @see setEmail:
 @see getHWID
 */
+ (void)setUserId:(NSString *_Nonnull)userId;

/**
 Sets a custom user identifier with completion confirmation.

 @discussion
 Same as `setUserId:` but provides callback when the server operation completes.
 Use this when you need to ensure the user ID is set before performing
 dependent operations like merging user data or tracking critical events.

 @param userId The custom user identifier (e.g., database ID, UUID, username).
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Handle login with guaranteed user ID synchronization:

 ```swift
 class LoginCoordinator {

     func performLogin(credentials: Credentials,
                       completion: @escaping (Result<User, Error>) -> Void) {

         APIClient.shared.login(credentials) { result in
             switch result {
             case .success(let user):
                 // Set user ID with confirmation before proceeding
                 Pushwoosh.configure.setUserId(user.id) { error in
                     if let error = error {
                         Logger.warning("User ID sync failed: \(error.localizedDescription)")
                         // Continue anyway - local state is still valid
                     }

                     // Now safe to track login event with correct user attribution
                     Pushwoosh.configure.setTags([
                         "logged_in": true,
                         "last_login": ISO8601DateFormatter().string(from: Date()),
                         "login_method": credentials.method.rawValue
                     ])

                     // Set email if available
                     if let email = user.email {
                         Pushwoosh.configure.setEmail(email)
                     }

                     completion(.success(user))
                 }

             case .failure(let error):
                 completion(.failure(error))
             }
         }
     }
 }
 ```

 @note The completion block is called on an arbitrary queue.

 @see setUserId:
 @see setUser:emails:completion:
 */
+ (void)setUserId:(NSString *_Nonnull)userId completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Sets user identifier and emails together in a single operation.

 @discussion
 Convenience method that combines `setUserId:` and `setEmails:` into a single
 server request. This is more efficient than calling both methods separately
 and ensures atomic association of user ID with emails.

 Use this during login or registration flows when you have both user ID
 and email available simultaneously.

 @param userId The custom user identifier.
 @param emails Array of email address strings to associate with the user.

 ## Example

 Complete registration with user ID and emails:

 ```swift
 class RegistrationManager {

     func completeRegistration(_ registration: RegistrationData) {
         // Create user on backend
         APIClient.shared.createUser(registration) { result in
             guard case .success(let user) = result else { return }

             // Set both user ID and emails in single operation
             var emails = [user.email]
             if let secondaryEmail = registration.secondaryEmail {
                 emails.append(secondaryEmail)
             }

             Pushwoosh.configure.setUser(user.id, emails: emails)

             // Set initial user tags
             Pushwoosh.configure.setTags([
                 "registration_date": ISO8601DateFormatter().string(from: Date()),
                 "registration_source": registration.source.rawValue,
                 "account_type": user.accountType.rawValue,
                 "has_completed_onboarding": false
             ])
         }
     }
 }
 ```

 @note This method does not provide completion callback. Use `setUser:emails:completion:`
       when you need confirmation.

 @see setUser:emails:completion:
 @see setUserId:
 @see setEmails:
 */
+ (void)setUser:(NSString *_Nonnull)userId emails:(NSArray *_Nonnull)emails;

/**
 Sets user identifier and emails with completion handler.

 @discussion
 Atomically associates a user ID with multiple email addresses and provides
 confirmation when the operation completes. This is the recommended method
 for user identification during authentication flows.

 @param userId The custom user identifier.
 @param emails Array of email address strings.
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Handle OAuth login with full user setup:

 ```swift
 class OAuthLoginHandler {

     func handleOAuthCallback(_ authResult: OAuthResult,
                             completion: @escaping (Result<Void, Error>) -> Void) {

         // Extract user info from OAuth result
         let userId = authResult.userId
         var emails: [String] = []

         if let primaryEmail = authResult.email {
             emails.append(primaryEmail)
         }
         if let verifiedEmails = authResult.verifiedEmails {
             emails.append(contentsOf: verifiedEmails.filter { $0 != authResult.email })
         }

         // Set user and emails with confirmation
         Pushwoosh.configure.setUser(userId, emails: emails) { error in
             if let error = error {
                 Logger.error("User setup failed: \(error.localizedDescription)")
                 completion(.failure(error))
                 return
             }

             // User is now fully identified - set profile tags
             Pushwoosh.configure.setTags([
                 "oauth_provider": authResult.provider.rawValue,
                 "has_profile_picture": authResult.profilePictureURL != nil,
                 "locale": authResult.locale ?? Locale.current.identifier,
                 "first_login": !self.hasExistingSession(for: userId)
             ])

             Analytics.track("oauth_login_complete", properties: [
                 "provider": authResult.provider.rawValue,
                 "email_count": emails.count
             ])

             completion(.success(()))
         }
     }
 }
 ```

 @see setUser:emails:
 @see setUser:email:completion:
 */
+ (void)setUser:(NSString *_Nonnull)userId emails:(NSArray *_Nonnull)emails completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Sets user identifier and single email with completion handler.

 @discussion
 Convenience method for the common case of associating a user ID with a single
 email address. Equivalent to calling `setUser:emails:completion:` with a
 single-element array.

 @param userId The custom user identifier.
 @param email The user's email address.
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Simple login flow with single email:

 ```swift
 class SimpleAuthManager {

     func loginWithEmail(_ email: String, password: String,
                        completion: @escaping (Result<Void, Error>) -> Void) {

         APIClient.shared.authenticate(email: email, password: password) { result in
             switch result {
             case .success(let authResponse):
                 Pushwoosh.configure.setUser(authResponse.userId, email: email) { error in
                     if let error = error {
                         Logger.warning("Pushwoosh sync failed: \(error)")
                         // Don't fail login for Pushwoosh errors
                     }

                     self.saveSession(authResponse)
                     completion(.success(()))
                 }

             case .failure(let error):
                 completion(.failure(error))
             }
         }
     }
 }
 ```

 @see setUser:emails:completion:
 @see setUserId:completion:
 @see setEmail:completion:
 */
+ (void)setUser:(NSString *_Nonnull)userId email:(NSString *_Nonnull)email completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Merges engagement data from one user to another.

 @discussion
 Transfers or removes push engagement history when user identity changes.
 Common scenarios include:

 - **Anonymous to authenticated**: Merge anonymous browsing data to logged-in user
 - **Account linking**: Combine data when user links multiple accounts
 - **Account recovery**: Transfer data to recovered account
 - **Data cleanup**: Remove data for deleted/merged accounts

 When `doMerge` is YES, all events (push opens, in-app interactions, etc.)
 from `oldUserId` are moved to `newUserId`. When NO, events for `oldUserId`
 are simply deleted.

 @param oldUserId The source user identifier whose data will be transferred/deleted.
 @param newUserId The destination user identifier to receive the merged data.
 @param doMerge If YES, transfers all events to newUserId. If NO, deletes events for oldUserId.
 @param completion Block called when the operation completes.
                   Receives nil on success, or an NSError on failure.

 ## Example

 Merge anonymous user data after sign-up:

 ```swift
 class UserIdentityManager {

     private var anonymousUserId: String?

     func startAnonymousSession() {
         // Generate anonymous ID for tracking before login
         anonymousUserId = "anon_\(UUID().uuidString)"
         Pushwoosh.configure.setUserId(anonymousUserId!)

         Pushwoosh.configure.setTags([
             "is_anonymous": true,
             "session_start": ISO8601DateFormatter().string(from: Date())
         ])
     }

     func convertToAuthenticatedUser(_ authenticatedUser: User,
                                     completion: @escaping (Result<Void, Error>) -> Void) {

         guard let anonId = anonymousUserId else {
             // No anonymous session to merge
             setupAuthenticatedUser(authenticatedUser, completion: completion)
             return
         }

         // First set the new authenticated user ID
         Pushwoosh.configure.setUser(authenticatedUser.id, email: authenticatedUser.email) { [weak self] error in
             if let error = error {
                 completion(.failure(error))
                 return
             }

             // Merge anonymous engagement data to authenticated user
             Pushwoosh.configure.mergeUserId(anonId, to: authenticatedUser.id, doMerge: true) { mergeError in
                 if let mergeError = mergeError {
                     Logger.warning("Merge failed: \(mergeError.localizedDescription)")
                     // Continue anyway - user is authenticated
                 }

                 // Update tags for authenticated state
                 Pushwoosh.configure.setTags([
                     "is_anonymous": false,
                     "conversion_date": ISO8601DateFormatter().string(from: Date()),
                     "had_anonymous_session": true
                 ])

                 self?.anonymousUserId = nil
                 completion(.success(()))
             }
         }
     }

     func handleAccountDeletion(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
         // Remove user data without merging (doMerge: false)
         Pushwoosh.configure.mergeUserId(userId, to: "", doMerge: false) { error in
             if let error = error {
                 completion(.failure(error))
                 return
             }

             Pushwoosh.configure.setUserId("")
             Pushwoosh.configure.stopServerCommunication()
             completion(.success(()))
         }
     }
 }
 ```

 @note Merge operations are irreversible. Ensure correct user IDs before calling.
 @note This method is typically called once during identity transition.

 @see setUserId:
 @see setUser:emails:completion:
 */
+ (void)mergeUserId:(NSString *_Nonnull)oldUserId to:(NSString *_Nonnull)newUserId doMerge:(BOOL)doMerge completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Retrieves the current user identifier.

 @discussion
 Returns the user ID that was previously set via `setUserId:`, or the HWID if no custom
 user ID has been set.

 @return The current user identifier (custom user ID or HWID)

 ## Example

 Sync user ID with analytics platforms:

 ```swift
 class AnalyticsCoordinator {

     func syncIdentifiers() {
         let userId = Pushwoosh.configure.getUserId()
         let hwid = Pushwoosh.configure.getHWID()

         // Sync with various analytics platforms
         Analytics.identify(userId)
         Crashlytics.setUserID(userId)
         MixpanelInstance.identify(distinctId: userId)

         // Log device mapping for debugging
         Logger.debug("User identity: userId=\(userId), hwid=\(hwid)")
     }

     func trackEventWithUserContext(_ event: String, properties: [String: Any]) {
         var enrichedProperties = properties
         enrichedProperties["pushwoosh_user_id"] = Pushwoosh.configure.getUserId()
         enrichedProperties["pushwoosh_hwid"] = Pushwoosh.configure.getHWID()

         Analytics.track(event, properties: enrichedProperties)
     }
 }
 ```

 @note The user ID defaults to the HWID until explicitly set with `setUserId:`.

 @see setUserId:
 @see getHWID
 */
+ (NSString *_Nonnull)getUserId;

#pragma mark - Localization

/**
 Sets custom application language for localized notifications.

 @discussion
 Override the device language for Pushwoosh to enable:
 - Sending notifications in a specific language
 - Language-based segmentation
 - Supporting in-app language switching

 Must be a lowercase two-letter code according to ISO-639-1 standard.

 @param language The language code (e.g., "en", "de", "fr", "es") or nil to reset to device language

 ## Example

 Support in-app language selection:

 ```swift
 class LanguageManager {

     static let shared = LanguageManager()

     var currentLanguage: String {
         didSet {
             applyLanguageChange()
         }
     }

     func applyLanguageChange() {
         // Update Pushwoosh language for targeted notifications
         Pushwoosh.configure.setLanguage(currentLanguage)

         // Update user tags
         Pushwoosh.configure.setTags([
             "language": currentLanguage,
             "language_changed_date": Date()
         ])

         // Update app UI
         Bundle.setLanguage(currentLanguage)
         NotificationCenter.default.post(name: .languageDidChange, object: nil)

         Logger.info("App language changed to: \(currentLanguage)")
     }

     func resetToDeviceLanguage() {
         Pushwoosh.configure.setLanguage(nil)
         currentLanguage = Locale.current.languageCode ?? "en"
     }
 }
 ```

 @note Common language codes: "en" (English), "de" (German), "fr" (French), "es" (Spanish),
 "zh" (Chinese), "ja" (Japanese), "ko" (Korean), "ru" (Russian)

 @see getLanguage
 */
+ (void)setLanguage:(NSString *_Nullable)language;

/**
 Retrieves the current application language setting.

 @return The current language code, or device language if not set

 ## Example

 Check current language for localized content:

 ```swift
 func getLocalizedContent() -> LocalizedContent {
     let language = Pushwoosh.configure.getLanguage()
     return ContentManager.shared.content(for: language)
 }
 ```

 @see setLanguage:
 */
+ (NSString *_Nonnull)getLanguage;

#pragma mark - Foreground Notification Display

/**
 Sets whether to show alert for push notifications when app is in foreground.

 @discussion
 By default, iOS does not display notification banners when the app is in the foreground.
 Enable this to show system notification alerts even when the app is active.

 @param show YES to show alerts in foreground, NO to suppress them (default)

 ## Example

 Configure based on app type:

 ```swift
 class NotificationConfigManager {

     func configureForAppType(_ appType: AppType) {
         switch appType {
         case .messaging:
             // Messaging apps typically handle notifications in-app
             Pushwoosh.configure.setShowPushnotificationAlert(false)

         case .ecommerce, .news:
             // E-commerce and news apps benefit from showing all notifications
             Pushwoosh.configure.setShowPushnotificationAlert(true)

         case .game:
             // Games might want to suppress during gameplay
             Pushwoosh.configure.setShowPushnotificationAlert(false)
         }
     }

     func temporarilyDisableForegroundAlerts(during action: () -> Void) {
         let wasEnabled = Pushwoosh.configure.getShowPushnotificationAlert()
         Pushwoosh.configure.setShowPushnotificationAlert(false)

         action()

         Pushwoosh.configure.setShowPushnotificationAlert(wasEnabled)
     }
 }
 ```

 @note For more granular control over foreground presentation, implement
 `UNUserNotificationCenterDelegate` and use `Pushwoosh.ForegroundPush`.

 @see getShowPushnotificationAlert
 */
+ (void)setShowPushnotificationAlert:(BOOL)show;

/**
 Retrieves the current setting for showing push notification alerts in foreground.

 @return YES if foreground alerts are enabled, NO otherwise

 ## Example

 ```swift
 func logNotificationSettings() {
     let showInForeground = Pushwoosh.configure.getShowPushnotificationAlert()
     Logger.debug("Foreground notifications: \(showInForeground ? "enabled" : "disabled")")
 }
 ```

 @see setShowPushnotificationAlert:
 */
+ (BOOL)getShowPushnotificationAlert;

#pragma mark - Manual Push Handling

/**
 Manually handles the device push token registration.

 @discussion
 Call this method from your AppDelegate's `application:didRegisterForRemoteNotificationsWithDeviceToken:`
 to forward the device token to Pushwoosh.

 The SDK normally handles this automatically via method swizzling, but you may need to call
 this directly if:
 - You've disabled swizzling
 - You're managing multiple push providers
 - You need custom token processing

 @param deviceToken The device token Data received from APNs

 ## Example

 Manual token handling with multiple push providers:

 ```swift
 class AppDelegate: UIResponder, UIApplicationDelegate {

     func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

         // Convert token to string for logging
         let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
         Logger.info("Received APNs token: \(tokenString.prefix(20))...")

         // Send to Pushwoosh
         Pushwoosh.configure.handlePushRegistration(deviceToken)

         // Send to other push providers if needed
         FirebaseMessaging.messaging().apnsToken = deviceToken

         // Sync with backend
         BackendAPI.shared.updatePushToken(tokenString)
     }
 }
 ```

 @note The SDK handles token registration automatically after calling `registerForPushNotifications`.
 Only use this method if you need manual control.

 @see registerForPushNotifications
 @see handlePushRegistrationFailure:
 */
+ (void)handlePushRegistration:(NSData *_Nonnull)deviceToken;

/**
 Handles push notification registration failure.

 @discussion
 Call this method from your AppDelegate's `application:didFailToRegisterForRemoteNotificationsWithError:`
 to notify Pushwoosh about registration failures.

 This allows Pushwoosh to:
 - Log the error for debugging
 - Retry registration if appropriate
 - Update device status in the Control Panel

 @param error The NSError received from APNs registration failure

 ## Example

 Handle registration failure with user feedback:

 ```swift
 class AppDelegate: UIResponder, UIApplicationDelegate {

     func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {

         // Forward to Pushwoosh
         Pushwoosh.configure.handlePushRegistrationFailure(error as NSError)

         // Log for debugging
         Logger.error("Push registration failed: \(error.localizedDescription)")

         // Handle specific error cases
         let nsError = error as NSError
         switch nsError.code {
         case 3010:
             // Simulator or push not supported
             Logger.warning("Push notifications not supported on this device")

         default:
             // Track error in analytics
             Analytics.track("push_registration_failed", properties: [
                 "error_code": nsError.code,
                 "error_message": nsError.localizedDescription
             ])

             // Optionally notify user
             if shouldShowPushError {
                 showPushRegistrationError()
             }
         }
     }
 }
 ```

 @see handlePushRegistration:
 @see registerForPushNotifications
 */
+ (void)handlePushRegistrationFailure:(NSError *_Nonnull)error;

/**
 Handles a received push notification.

 @discussion
 Call this method to process push notification payloads. The SDK will:
 - Parse the notification payload
 - Track delivery statistics
 - Trigger appropriate delegate callbacks
 - Handle rich media and deep links

 @param userInfo The notification payload dictionary received from APNs

 @return YES if the notification was handled by Pushwoosh, NO if it's not a Pushwoosh notification

 ## Example

 Handle notifications in various AppDelegate methods:

 ```swift
 class AppDelegate: UIResponder, UIApplicationDelegate {

     // Legacy method for iOS < 10
     func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
         handleNotification(userInfo)
     }

     // Modern method with background fetch
     func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

         let handled = handleNotification(userInfo)

         // Perform background work if needed
         if let contentAvailable = userInfo["aps"] as? [String: Any],
            contentAvailable["content-available"] as? Int == 1 {

             performBackgroundSync { newData in
                 completionHandler(newData ? .newData : .noData)
             }
         } else {
             completionHandler(handled ? .newData : .noData)
         }
     }

     private func handleNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
         // Check if it's a Pushwoosh notification
         guard Pushwoosh.configure.handlePushReceived(userInfo) else {
             Logger.debug("Non-Pushwoosh notification received")
             return false
         }

         // Additional custom handling
         if let customData = userInfo["custom_data"] as? [String: Any] {
             processCustomPayload(customData)
         }

         return true
     }
 }
 ```

 @note This method should be called from your AppDelegate's notification handling methods.
 @note For iOS 10+, prefer using `UNUserNotificationCenterDelegate` methods.

 @see setDelegate:
 @see PWMessagingDelegate
 */
+ (BOOL)handlePushReceived:(NSDictionary *_Nonnull)userInfo;

#pragma mark - Notification Status

/**
 Returns dictionary with enabled remote notification types.

 @discussion
 Provides detailed information about the current notification settings for the app:
 - Whether notifications are enabled overall
 - Which notification types are allowed (alert, badge, sound)
 - The authorization status

 @return Dictionary containing notification status information, or nil if unavailable

 ## Dictionary Keys

 | Key | Type | Description |
 |-----|------|-------------|
 | `enabled` | Bool | Whether notifications are enabled |
 | `pushAlert` | Bool | Whether alert banners are allowed |
 | `pushBadge` | Bool | Whether badge updates are allowed |
 | `pushSound` | Bool | Whether notification sounds are allowed |
 | `type` | Int | Combined notification type bitmask |

 ## Example

 Check notification status and prompt user if disabled:

 ```swift
 class NotificationStatusManager {

     func checkAndPromptForNotifications() {
         guard let status = Pushwoosh.configure.getRemoteNotificationStatus() else {
             Logger.warning("Could not retrieve notification status")
             return
         }

         let isEnabled = status["enabled"] as? Bool ?? false
         let hasAlert = status["pushAlert"] as? Bool ?? false
         let hasBadge = status["pushBadge"] as? Bool ?? false
         let hasSound = status["pushSound"] as? Bool ?? false

         Logger.debug("""
             Notification Status:
             - Enabled: \(isEnabled)
             - Alert: \(hasAlert)
             - Badge: \(hasBadge)
             - Sound: \(hasSound)
             """)

         if !isEnabled {
             promptToEnableNotifications()
         } else if !hasAlert {
             promptToEnableAlerts()
         }
     }

     private func promptToEnableNotifications() {
         let alert = UIAlertController(
             title: "Enable Notifications",
             message: "You're missing out on important updates. Enable notifications in Settings.",
             preferredStyle: .alert
         )

         alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
             if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                 UIApplication.shared.open(settingsURL)
             }
         })

         alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))

         UIApplication.topViewController()?.present(alert, animated: true)
     }
 }
 ```

 @note For iOS 10+, consider using `UNUserNotificationCenter.current().getNotificationSettings()`
 for more detailed status information.
 */
+ (NSDictionary *_Nullable)getRemoteNotificationStatus;

#pragma mark - Delegates

/**
 Sets the delegate for receiving push notification events.

 @discussion
 The delegate will receive callbacks when:
 - A push notification is received (foreground or background)
 - The user taps on a push notification
 - Rich media is about to be displayed

 Set the delegate before calling `registerForPushNotifications` to ensure you receive
 all notification events, including those that launched the app.

 @param delegate Object implementing PWMessagingDelegate protocol, or nil to remove the delegate

 ## Example

 Implement comprehensive notification handling:

 ```swift
 class NotificationCoordinator: NSObject, PWMessagingDelegate {

     static let shared = NotificationCoordinator()

     func setup() {
         Pushwoosh.configure.setDelegate(self)
     }

     // MARK: - PWMessagingDelegate

     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
         Logger.info("Push received: \(message.title ?? "No title")")

         // Handle silent push
         if message.isContentAvailable {
             handleSilentPush(message)
             return
         }

         // Handle foreground notification
         if message.isForegroundMessage {
             handleForegroundNotification(message)
         }

         // Update badge count
         updateBadgeCount(message.badge)

         // Track in analytics
         Analytics.track("push_received", properties: buildAnalyticsProperties(from: message))
     }

     func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
         Logger.info("Push opened: \(message.title ?? "No title")")

         // Track open in analytics
         Analytics.track("push_opened", properties: buildAnalyticsProperties(from: message))

         // Handle deep link
         if let link = message.link, let url = URL(string: link) {
             DeepLinkRouter.shared.route(to: url)
             return
         }

         // Handle custom data actions
         if let customData = message.customData {
             handleCustomAction(customData)
         }
     }

     private func buildAnalyticsProperties(from message: PWMessage) -> [String: Any] {
         return [
             "message_id": message.messageCode ?? "",
             "campaign_id": message.campaignId,
             "title": message.title ?? "",
             "has_deep_link": message.link != nil,
             "is_inbox": message.isInboxMessage
         ]
     }

     private func handleCustomAction(_ data: [AnyHashable: Any]) {
         if let action = data["action"] as? String {
             switch action {
             case "open_product":
                 if let productId = data["product_id"] as? String {
                     NavigationCoordinator.shared.showProduct(id: productId)
                 }
             case "open_promo":
                 if let promoCode = data["promo_code"] as? String {
                     NavigationCoordinator.shared.showPromo(code: promoCode)
                 }
             default:
                 Logger.warning("Unknown custom action: \(action)")
             }
         }
     }
 }
 ```

 @see PWMessagingDelegate
 @see getDelegate
 */
+ (void)setDelegate:(id<PWMessagingDelegate> _Nullable)delegate;

/**
 Retrieves the current messaging delegate.

 @return The current PWMessagingDelegate object, or nil if not set

 ## Example

 ```swift
 func verifyDelegateSetup() -> Bool {
     guard Pushwoosh.configure.getDelegate() != nil else {
         Logger.error("PWMessagingDelegate not set - notifications won't be handled properly")
         return false
     }
     return true
 }
 ```

 @see setDelegate:
 */
+ (id<PWMessagingDelegate> _Nullable)getDelegate;

#if TARGET_OS_IOS
/**
 Sets the delegate for in-app purchase events from rich media.

 @discussion
 The delegate will receive callbacks for in-app purchase events triggered from
 Pushwoosh rich media content (HTML pages, in-app messages).

 This enables:
 - Handling promoted purchases from the App Store
 - Processing purchases initiated from rich media
 - Tracking purchase completions and failures
 - Restoring previous purchases

 @param delegate Object implementing PWPurchaseDelegate protocol, or nil to remove the delegate

 ## Example

 Handle in-app purchases from rich media:

 ```swift
 class PurchaseCoordinator: NSObject, PWPurchaseDelegate {

     static let shared = PurchaseCoordinator()

     func setup() {
         Pushwoosh.configure.setPurchaseDelegate(self)
     }

     // MARK: - PWPurchaseDelegate

     func onPW(inAppPurchaseHelperCallPromotedPurchase identifier: String) {
         Logger.info("Promoted purchase initiated: \(identifier)")

         // Verify user is ready to purchase
         guard UserSession.shared.isLoggedIn else {
             // Save for later and prompt login
             PendingPurchaseManager.shared.save(identifier)
             NavigationCoordinator.shared.showLogin(reason: .purchase)
             return
         }

         // Process the purchase
         IAPManager.shared.purchase(productIdentifier: identifier)
     }

     func onPWInAppPurchaseHelperPaymentComplete(_ identifier: String) {
         Logger.info("Purchase completed: \(identifier)")

         // Update user status
         Pushwoosh.configure.setTags([
             "last_purchase": identifier,
             "last_purchase_date": Date(),
             "has_purchased": true
         ])

         // Unlock content
         ContentUnlocker.shared.unlock(identifier)

         // Track in analytics
         Analytics.track("purchase_completed", properties: [
             "product_id": identifier,
             "source": "rich_media"
         ])
     }

     func onPWInAppPurchaseHelperPaymentFailedProductIdentifier(_ identifier: String, error: Error) {
         Logger.error("Purchase failed: \(identifier) - \(error.localizedDescription)")

         Analytics.track("purchase_failed", properties: [
             "product_id": identifier,
             "error": error.localizedDescription
         ])
     }
 }
 ```

 @note This method is only available on iOS.

 @see PWPurchaseDelegate
 @see getPurchaseDelegate
 */
+ (void)setPurchaseDelegate:(id<PWPurchaseDelegate> _Nullable)delegate;

/**
 Retrieves the current purchase delegate.

 @return The current PWPurchaseDelegate object, or nil if not set

 ## Example

 ```swift
 func canHandleRichMediaPurchases() -> Bool {
     return Pushwoosh.configure.getPurchaseDelegate() != nil
 }
 ```

 @note This method is only available on iOS.

 @see setPurchaseDelegate:
 */
+ (id<PWPurchaseDelegate> _Nullable)getPurchaseDelegate;
#endif

#pragma mark - Reverse Proxy

/**
 Sets a reverse proxy URL for all Pushwoosh API communications.

 @discussion
 Routes all Pushwoosh SDK network requests through your own proxy server.
 This is useful for:

 - **Enterprise security**: Route traffic through corporate proxies
 - **Regional compliance**: Ensure data flows through specific regions
 - **Network monitoring**: Inspect and log SDK traffic
 - **Firewall restrictions**: Work around corporate firewall rules

 The proxy must forward requests to the appropriate Pushwoosh API endpoints
 while preserving all headers and request body content.

 @param url The full URL of your reverse proxy endpoint (e.g., "https://proxy.company.com/pushwoosh").

 ## Example

 Configure proxy for enterprise deployment:

 ```swift
 class NetworkConfiguration {

     func configureForEnterprise() {
         // Check if enterprise proxy is required
         guard let proxyURL = Configuration.shared.pushwooshProxyURL else {
             return
         }

         Pushwoosh.configure.setReverseProxy(proxyURL)

         Logger.info("Pushwoosh configured to use proxy: \(proxyURL)")

         // Track proxy configuration
         Pushwoosh.configure.setTags([
             "uses_proxy": true,
             "proxy_region": extractRegion(from: proxyURL)
         ])
     }

     func configureForRegion(_ region: Region) {
         switch region {
         case .eu:
             Pushwoosh.configure.setReverseProxy("https://eu-proxy.company.com/pushwoosh")
         case .asia:
             Pushwoosh.configure.setReverseProxy("https://asia-proxy.company.com/pushwoosh")
         case .us:
             Pushwoosh.configure.disableReverseProxy()
         }
     }
 }
 ```

 @note The proxy server must be configured to forward requests to Pushwoosh APIs.
 @note SSL certificate validation is performed against the proxy URL.
 @note Call this method before any other Pushwoosh API calls.

 @see disableReverseProxy
 */
+ (void)setReverseProxy:(NSString *_Nonnull)url;

/**
 Disables the reverse proxy and restores default Pushwoosh API endpoints.

 @discussion
 Removes any previously configured reverse proxy and returns to using
 Pushwoosh's default API endpoints directly.

 Use this when:
 - Switching from enterprise to standard mode
 - Proxy server becomes unavailable
 - User changes network configuration

 ## Example

 Toggle proxy based on network type:

 ```swift
 class NetworkMonitor {

     func handleNetworkChange(_ network: NetworkType) {
         switch network {
         case .corporate:
             Pushwoosh.configure.setReverseProxy(enterpriseProxyURL)
         case .public, .home:
             Pushwoosh.configure.disableReverseProxy()
         }
     }
 }
 ```

 @see setReverseProxy:
 */
+ (void)disableReverseProxy;

#pragma mark - Badge Management

/**
 Synchronizes the application badge number with Pushwoosh servers.

 @discussion
 Reports the current badge count to Pushwoosh for analytics and to enable
 badge-based segmentation. This is useful for:

 - **Analytics**: Track user engagement through unread counts
 - **Segmentation**: Target users with high/low badge counts
 - **Badge management**: Allow server-side badge manipulation

 Call this method whenever you update the app badge to keep Pushwoosh in sync.

 @param badge The current application badge number (0 to clear badge).

 ## Example

 Sync badge with Pushwoosh when updating unread counts:

 ```swift
 class NotificationBadgeManager {

     private(set) var unreadCount: Int = 0 {
         didSet {
             updateBadge()
         }
     }

     func markAsRead(_ notificationIds: [String]) {
         unreadCount = max(0, unreadCount - notificationIds.count)
     }

     func handleNewNotification() {
         unreadCount += 1
     }

     func clearAll() {
         unreadCount = 0
     }

     private func updateBadge() {
         // Update system badge
         if #available(iOS 16.0, *) {
             UNUserNotificationCenter.current().setBadgeCount(unreadCount)
         } else {
             UIApplication.shared.applicationIconBadgeNumber = unreadCount
         }

         // Sync with Pushwoosh
         Pushwoosh.configure.sendBadges(unreadCount)
     }
 }

 // Usage in AppDelegate
 class AppDelegate: UIApplicationDelegate {

     func applicationDidBecomeActive(_ application: UIApplication) {
         // Sync current badge state when app becomes active
         let currentBadge = application.applicationIconBadgeNumber
         Pushwoosh.configure.sendBadges(currentBadge)
     }
 }
 ```

 @note Badge sync is performed asynchronously.
 @note On iOS 16+, use UNUserNotificationCenter.setBadgeCount() for badge updates.

 @see clearNotificationCenter
 */
+ (void)sendBadges:(NSInteger)badge;

#pragma mark - URL Handling

#if TARGET_OS_IOS || TARGET_OS_WATCH
/**
 Processes deep link URLs for Pushwoosh SDK functionality.

 @discussion
 Handles special Pushwoosh URLs, primarily used for:

 - **Test device registration**: Register device for push testing via QR code
 - **Deep link tracking**: Process tracked deep links from push notifications

 Should be called from your app's URL handling methods. Returns YES if the URL
 was a Pushwoosh URL and was handled, NO if it should be processed by your app.

 @param url The URL to process.
 @return YES if the URL was handled by Pushwoosh, NO otherwise.

 ## Example

 Handle URLs in SceneDelegate (iOS 13+):

 ```swift
 class SceneDelegate: UIResponder, UIWindowSceneDelegate {

     func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
         guard let url = URLContexts.first?.url else { return }

         // First, check if Pushwoosh handles this URL
         if Pushwoosh.configure.handleOpenURL(url) {
             Logger.info("URL handled by Pushwoosh")
             return
         }

         // Handle other deep links
         DeepLinkRouter.shared.handle(url)
     }

     func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
         guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
               let url = userActivity.webpageURL else { return }

         if Pushwoosh.configure.handleOpenURL(url) {
             return
         }

         UniversalLinkRouter.shared.handle(url)
     }
 }

 // Legacy AppDelegate support
 class AppDelegate: UIApplicationDelegate {

     func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

         if Pushwoosh.configure.handleOpenURL(url) {
             return true
         }

         return DeepLinkRouter.shared.handle(url)
     }
 }
 ```

 @note Call this early in your URL handling chain.
 @note Test device registration URLs follow the pattern: `yourscheme://pushwoosh?...`

 @see setDelegate:
 */
+ (BOOL)handleOpenURL:(NSURL *_Nonnull)url;
#endif

#pragma mark - In-App Purchases (iOS only)

#if TARGET_OS_IOS
/**
 Sends StoreKit payment transactions to Pushwoosh for purchase tracking.

 @discussion
 Automatically tracks in-app purchases from StoreKit transactions.
 This enables:

 - **Revenue tracking**: Monitor purchase revenue in Pushwoosh dashboard
 - **Purchase-based segmentation**: Target paying users, high-value customers
 - **LTV analysis**: Calculate customer lifetime value
 - **Purchase events**: Trigger automations based on purchases

 Call this method from your `SKPaymentTransactionObserver` for all
 completed transactions.

 @param transactions Array of `SKPaymentTransaction` objects from StoreKit.

 ## Example

 Integrate with StoreKit payment observer:

 ```swift
 class StoreKitManager: NSObject, SKPaymentTransactionObserver {

     func paymentQueue(_ queue: SKPaymentQueue,
                      updatedTransactions transactions: [SKPaymentTransaction]) {

         let completedTransactions = transactions.filter {
             $0.transactionState == .purchased || $0.transactionState == .restored
         }

         // Send completed transactions to Pushwoosh
         if !completedTransactions.isEmpty {
             Pushwoosh.configure.sendSKPaymentTransactions(completedTransactions)
         }

         // Process each transaction
         for transaction in transactions {
             switch transaction.transactionState {
             case .purchased:
                 handlePurchase(transaction)
                 queue.finishTransaction(transaction)

             case .restored:
                 handleRestore(transaction)
                 queue.finishTransaction(transaction)

             case .failed:
                 handleFailure(transaction)
                 queue.finishTransaction(transaction)

             case .deferred, .purchasing:
                 break

             @unknown default:
                 break
             }
         }
     }

     private func handlePurchase(_ transaction: SKPaymentTransaction) {
         let productId = transaction.payment.productIdentifier

         // Update user tags for purchase segmentation
         Pushwoosh.configure.setTags([
             "has_purchased": true,
             "last_purchase_date": ISO8601DateFormatter().string(from: Date()),
             "last_purchased_product": productId
         ])
     }
 }
 ```

 @note Only send completed (purchased/restored) transactions.
 @note Transaction data is sent to Pushwoosh servers asynchronously.

 @see sendPurchase:withPrice:currencyCode:andDate:
 @see setPurchaseDelegate:
 */
+ (void)sendSKPaymentTransactions:(NSArray *_Nonnull)transactions;

/**
 Tracks an individual in-app purchase with custom price information.

 @discussion
 Manually track a purchase when you need more control than automatic
 StoreKit tracking, or when processing purchases from other sources
 (web purchases, promotional codes, etc.).

 Use this for:
 - Non-StoreKit purchases (web, third-party payment processors)
 - Custom price tracking (discounts, promotions)
 - Server-verified purchases
 - Cross-platform purchase sync

 @param productIdentifier The product identifier (SKU).
 @param price The purchase price as NSDecimalNumber for precision.
 @param currencyCode ISO 4217 currency code (e.g., "USD", "EUR", "GBP").
 @param date The date when the purchase occurred.

 ## Example

 Track purchases from different sources:

 ```swift
 class PurchaseTracker {

     func trackStoreKitPurchase(_ transaction: SKPaymentTransaction, product: SKProduct) {
         Pushwoosh.configure.sendPurchase(
             product.productIdentifier,
             withPrice: product.price,
             currencyCode: product.priceLocale.currencyCode ?? "USD",
             andDate: transaction.transactionDate ?? Date()
         )

         updatePurchaseTags(productId: product.productIdentifier, price: product.price)
     }

     func trackWebPurchase(_ purchase: WebPurchase) {
         // Track purchase made through web checkout
         Pushwoosh.configure.sendPurchase(
             purchase.productId,
             withPrice: NSDecimalNumber(value: purchase.amount),
             currencyCode: purchase.currency,
             andDate: purchase.timestamp
         )

         updatePurchaseTags(productId: purchase.productId,
                           price: NSDecimalNumber(value: purchase.amount))
     }

     func trackPromotionalPurchase(productId: String, originalPrice: Decimal, discountedPrice: Decimal) {
         // Track discounted purchase
         Pushwoosh.configure.sendPurchase(
             productId,
             withPrice: NSDecimalNumber(decimal: discountedPrice),
             currencyCode: Locale.current.currencyCode ?? "USD",
             andDate: Date()
         )

         Pushwoosh.configure.setTags([
             "used_promotion": true,
             "discount_amount": NSDecimalNumber(decimal: originalPrice - discountedPrice)
         ])
     }

     private func updatePurchaseTags(productId: String, price: NSDecimalNumber) {
         Pushwoosh.configure.setTags([
             "total_purchases": incrementPurchaseCount(),
             "total_spent": calculateTotalSpent(adding: price),
             "customer_tier": determineCustomerTier()
         ])
     }
 }
 ```

 @note Use NSDecimalNumber for precise currency calculations.
 @note Currency code should be a valid ISO 4217 code.

 @see sendSKPaymentTransactions:
 */
+ (void)sendPurchase:(NSString *_Nonnull)productIdentifier withPrice:(NSDecimalNumber *_Nonnull)price currencyCode:(NSString *_Nonnull)currencyCode andDate:(NSDate *_Nonnull)date;
#endif

#pragma mark - Utility

/**
 Clears all delivered notifications from the notification center.

 @discussion
 Removes all notifications delivered by your app from the iOS Notification Center.
 This is commonly used when:

 - User opens the app (clear notifications since they're viewing content)
 - User logs out (clear notifications for privacy)
 - Content is marked as read in-app
 - Performing a "mark all as read" action

 Only removes notifications from your app; other apps' notifications are unaffected.

 ## Example

 Clear notifications on app activation and logout:

 ```swift
 class NotificationManager {

     func applicationDidBecomeActive() {
         // Clear notifications when user opens app
         Pushwoosh.configure.clearNotificationCenter()

         // Also reset badge
         UIApplication.shared.applicationIconBadgeNumber = 0
         Pushwoosh.configure.sendBadges(0)
     }

     func handleUserLogout() {
         // Clear notifications for privacy
         Pushwoosh.configure.clearNotificationCenter()

         // Unregister from push
         Pushwoosh.configure.unregisterForPushNotifications { _ in }

         // Clear user identity
         Pushwoosh.configure.setUserId("")
     }

     func markAllAsRead() {
         // Clear from notification center
         Pushwoosh.configure.clearNotificationCenter()

         // Update backend
         APIClient.shared.markAllNotificationsRead { _ in }

         // Clear badge
         Pushwoosh.configure.sendBadges(0)
     }
 }
 ```

 @note This removes delivered notifications only, not pending scheduled notifications.
 @note On iOS 10+, uses UNUserNotificationCenter.removeAllDeliveredNotifications().

 @see sendBadges:
 */
+ (void)clearNotificationCenter;

/**
 Returns the Pushwoosh SDK version string.

 @discussion
 Provides the current SDK version for debugging, logging, and compatibility checks.
 Useful for:

 - Debug logging and crash reports
 - Feature availability checks
 - Support ticket information
 - Analytics tracking

 @return The SDK version string in semantic versioning format (e.g., "7.0.6").

 ## Example

 Include SDK version in debug info:

 ```swift
 class DiagnosticsManager {

     func generateDiagnosticReport() -> DiagnosticReport {
         return DiagnosticReport(
             appVersion: Bundle.main.appVersion,
             buildNumber: Bundle.main.buildNumber,
             pushwooshVersion: Pushwoosh.configure.version(),
             hwid: Pushwoosh.configure.getHWID(),
             pushToken: Pushwoosh.configure.getPushToken(),
             userId: Pushwoosh.configure.getUserId(),
             pushEnabled: isPushEnabled(),
             deviceInfo: collectDeviceInfo()
         )
     }

     func logSDKInfo() {
         Logger.info("""
             Pushwoosh SDK Info:
             - Version: \(Pushwoosh.configure.version())
             - HWID: \(Pushwoosh.configure.getHWID())
             - Push Token: \(Pushwoosh.configure.getPushToken() ?? "Not registered")
             """)
     }

     func checkMinimumVersion(_ required: String) -> Bool {
         let current = Pushwoosh.configure.version()
         return current.compare(required, options: .numeric) != .orderedAscending
     }
 }
 ```

 @see getHWID
 @see getPushToken
 */
+ (NSString *_Nonnull)version;

/**
 Extracts custom data from a push notification payload.

 @discussion
 Retrieves the custom JSON data that was sent with a push notification.
 Custom data is set in Pushwoosh when creating the push and can contain
 any JSON-serializable content for app-specific handling.

 The returned string is JSON-formatted and must be parsed by your app.
 Returns nil if no custom data was included in the notification.

 @param pushNotification The notification payload dictionary (userInfo from push).
 @return The custom data as a JSON string, or nil if no custom data present.

 ## Example

 Handle push notifications with custom data:

 ```swift
 class PushNotificationHandler: PWMessagingDelegate {

     func pushwoosh(_ pushwoosh: Pushwoosh!,
                   onMessageReceived message: [AnyHashable: Any]!) {

         // Extract and parse custom data
         guard let customDataString = Pushwoosh.configure.getCustomPushData(message),
               let customData = parseJSON(customDataString) else {
             handleStandardNotification(message)
             return
         }

         // Route based on custom data
         if let deepLink = customData["deep_link"] as? String {
             DeepLinkRouter.shared.navigate(to: deepLink)
         }

         if let action = customData["action"] as? String {
             handleCustomAction(action, data: customData)
         }

         if let productId = customData["product_id"] as? String {
             showProductDetail(productId)
         }

         // Track custom data receipt
         Analytics.track("push_with_custom_data", properties: [
             "data_keys": Array(customData.keys)
         ])
     }

     private func parseJSON(_ jsonString: String) -> [String: Any]? {
         guard let data = jsonString.data(using: .utf8) else { return nil }
         return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
     }

     private func handleCustomAction(_ action: String, data: [String: Any]) {
         switch action {
         case "show_promo":
             if let promoCode = data["promo_code"] as? String {
                 PromoManager.shared.showPromo(code: promoCode)
             }
         case "update_content":
             ContentManager.shared.refreshContent()
         case "show_survey":
             if let surveyId = data["survey_id"] as? String {
                 SurveyManager.shared.presentSurvey(id: surveyId)
             }
         default:
             Logger.warning("Unknown custom action: \(action)")
         }
     }
 }
 ```

 @note Custom data is set in Pushwoosh dashboard or via API when sending push.
 @note The JSON string may contain nested objects and arrays.

 @see setDelegate:
 @see handlePushReceived:
 */
+ (NSString *_Nullable)getCustomPushData:(NSDictionary *_Nonnull)pushNotification;

@end

/**
 Configuration interface for Pushwoosh SDK.

 @discussion
 PushwooshConfig provides access to all SDK configuration methods through class methods.
 All configuration operations should be performed through `Pushwoosh.configure`.

 ## Quick Start

 ```swift
 // Basic setup in AppDelegate
 func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

     Pushwoosh.configure.setDelegate(self)
     Pushwoosh.configure.registerForPushNotifications()

     return true
 }
 ```

 ## Complete Integration Example

 ```swift
 class PushwooshIntegration {

     static func configure(delegate: PWMessagingDelegate) {
         // Set delegates
         Pushwoosh.configure.setDelegate(delegate)

         // Configure foreground display
         Pushwoosh.configure.setShowPushnotificationAlert(true)

         // Register for push
         Pushwoosh.configure.registerForPushNotifications()
     }

     static func handleUserLogin(user: User) {
         // Set user identity
         Pushwoosh.configure.setUserId(user.id)

         if let email = user.email {
             Pushwoosh.configure.setEmail(email)
         }

         // Set user tags
         Pushwoosh.configure.setTags([
             "logged_in": true,
             "user_type": user.type.rawValue,
             "signup_date": user.createdAt
         ])
     }

     static func handleUserLogout() {
         Pushwoosh.configure.unregisterForPushNotifications { _ in
             Pushwoosh.configure.setTags([
                 "logged_in": false,
                 "user_id": NSNull()
             ])
         }
     }
 }
 ```

 @see PWConfiguration
 */
@interface PushwooshConfig : NSObject<PWConfiguration>

/**
 Returns the configuration interface.

 @discussion
 Access this property to perform SDK configuration operations.
 All methods defined in PWConfiguration protocol are available.

 @return The PWConfiguration interface (Class type)

 ## Example

 ```swift
 // Access via Pushwoosh.configure
 Pushwoosh.configure.registerForPushNotifications()
 Pushwoosh.configure.setUserId("user123")
 Pushwoosh.configure.setTags(["premium": true])
 ```
 */
+ (Class _Nonnull)configure;

@end
