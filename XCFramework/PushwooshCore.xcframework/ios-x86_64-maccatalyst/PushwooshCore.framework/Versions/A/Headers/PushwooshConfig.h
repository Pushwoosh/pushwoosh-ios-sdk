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

@protocol PWConfiguration <NSObject>

/**
 Sets the Pushwoosh Application Code.

 @param appCode Your Pushwoosh Application Code

 @note Configure the Application Code in Info.plist with key `Pushwoosh_APPID`.

 @see getAppCode to retrieve the current Application Code
 */
+ (void)setAppCode:(NSString *_Nonnull)appCode;

/**
 Retrieves the current Pushwoosh Application Code.

 Returns the Application Code that was previously set via `setAppCode:` or configured in Info.plist.

 @return The Pushwoosh Application Code, or nil if not configured

 Example usage:

 @code
 let appCode = Pushwoosh.configure.getAppCode()
 print("App Code: \(appCode ?? "Not set")")
 @endcode

 @see setAppCode: to configure the Application Code
 */
+ (NSString *_Nullable)getAppCode;

/**
 Sets the Pushwoosh API Token for server-to-server communication.

 The API Token is used for secure communication between your server and Pushwoosh API.
 This is required for server-side push notification sending and other API operations.

 @param apiToken Your Pushwoosh API Token from the Control Panel

 Example usage:

 @code
 Pushwoosh.configure.setApiToken("YOUR-API-TOKEN")
 @endcode

 @note The API Token is different from the Application Code and should be kept secure.

 @see getApiToken to retrieve the current API Token
 */
+ (void)setApiToken:(NSString *_Nonnull)apiToken;

/**
 Retrieves the current Pushwoosh API Token.

 @return The Pushwoosh API Token, or nil if not configured

 Example usage:

 @code
 let apiToken = Pushwoosh.configure.getApiToken()
 @endcode

 @see setApiToken: to configure the API Token
 */
+ (NSString *_Nullable)getApiToken;

/**
 Returns the Pushwoosh Hardware ID (HWID) for this device.

 The HWID is a unique device identifier used in all Pushwoosh API calls and for device tracking
 in the Pushwoosh Control Panel. On iOS, this corresponds to UIDevice.identifierForVendor.

 @return The unique Pushwoosh device identifier

 Example usage:

 @code
 let hwid = Pushwoosh.configure.getHWID()
 print("Device HWID: \(hwid)")
 @endcode

 @note The HWID is generated on first SDK initialization and persists across app launches.

 @see getPushToken for the APNs device token
 */
+ (NSString *_Nonnull)getHWID;

/**
 Retrieves the current device push token.

 Returns the APNs device token string that was received during push notification registration.
 The token is used to send push notifications to this specific device.

 @return The device push token as a hexadecimal string, or nil if not yet registered

 Example usage:

 @code
 if let token = Pushwoosh.configure.getPushToken() {
     print("Push token: \(token)")
 } else {
     print("Not registered for push notifications yet")
 }
 @endcode

 @note The push token becomes available after successful registration with APNs.

 @see registerForPushNotifications to initiate registration
 @see getHWID for the Pushwoosh Hardware ID
 */
+ (NSString *_Nullable)getPushToken;

/**
 Checks whether communication with Pushwoosh servers is currently allowed.

 @return YES if server communication is allowed, NO otherwise

 Example usage:

 @code
 if Pushwoosh.configure.isServerCommunicationAllowed() {
     print("Server communication is enabled")
 }
 @endcode

 @see startServerCommunication to enable communication
 @see stopServerCommunication to disable communication
 */
+ (BOOL)isServerCommunicationAllowed;

/**
 Enables communication with Pushwoosh servers.

 Starts or resumes communication with Pushwoosh servers. This allows the SDK to send and receive
 data including device registration, tags, push tokens, and analytics.

 Example usage:

 @code
 Pushwoosh.configure.startServerCommunication()
 @endcode

 @note Server communication is enabled by default. Only use this method if you previously called stopServerCommunication.

 @see stopServerCommunication to disable communication
 @see isServerCommunicationAllowed to check current status
 */
+ (void)startServerCommunication;

/**
 Disables communication with Pushwoosh servers.

 Stops all communication with Pushwoosh servers. The SDK will not send or receive any data
 including device registration, tags, push tokens, and analytics.

 Use this method to comply with privacy regulations or user preferences for data transmission.

 Example usage:

 @code
 Pushwoosh.configure.stopServerCommunication()
 @endcode

 @note Push notifications will still be received by the device but won't be tracked by Pushwoosh.

 @see startServerCommunication to re-enable communication
 @see isServerCommunicationAllowed to check current status
 */
+ (void)stopServerCommunication;

/**
 Sets user tags for device segmentation.

 Tags are key-value pairs that enable targeted push notifications based on user attributes and behavior.
 Use tags to segment your audience and send personalized messages to specific user groups.

 Supported tag types:
 - String: Text values (e.g., username, city)
 - Integer: Numeric values (e.g., age, score)
 - Boolean: True/false values (e.g., isPremium, hasSubscription)
 - List: Arrays of strings (e.g., interests, categories)
 - Date: NSDate objects for time-based segmentation

 @param tags Dictionary of tag names and values to set for the current device

 Example usage:

 @code
 let tags: [AnyHashable: Any] = [
     "username": "john_doe",
     "age": 25,
     "isPremium": true,
     "interests": ["sports", "tech"]
 ]
 Pushwoosh.configure.setTags(tags)
 @endcode

 @note Tags are set asynchronously and do not block the calling thread.
 @note Tag names must be created in the Pushwoosh Control Panel before use.

 @see loadTags:error: to retrieve current tag values
 */
+ (void)setTags:(NSDictionary *_Nonnull)tags;

/**
 Retrieves the current device's tags from the Pushwoosh server.

 Fetches all tags currently set for this device. Tags are returned as a dictionary where keys
 are tag names and values are the corresponding tag values.

 @param successBlock Block called when tags are successfully retrieved. Receives a dictionary containing all device tags.
 @param errorBlock Block called if the request fails. Receives an error describing the failure.

 Example usage:

 @code
 Pushwoosh.configure.loadTags({ tags in
     if let tags = tags {
         print("Current tags: \(tags)")
     }
 }, error: { error in
     print("Failed to load tags: \(error?.localizedDescription ?? "")")
 })
 @endcode

 @note The operation is performed asynchronously.

 @see setTags: for setting device tags
 */
+ (void)loadTags:(void (^_Nullable)(NSDictionary *_Nullable tags))successBlock error:(void (^_Nullable)(NSError *_Nullable error))errorBlock;

/**
 Registers the device for push notifications.

 This method initiates the push notification registration process by requesting user permission
 to display notifications and registering the device with Apple Push Notification service (APNs).

 When called, the system will display a permission dialog to the user asking them to allow notifications.
 Once the user grants permission, the device will receive a push token from APNs which will be
 automatically sent to Pushwoosh servers for future push notification delivery.

 The registration process is asynchronous. Use `handlePushRegistration:` to handle the device token
 once it's received from APNs.

 This method should be called after configuring the Pushwoosh App Code in Info.plist with key `Pushwoosh_APPID`.

 Example usage:

 @code
 Pushwoosh.configure.registerForPushNotifications()
 @endcode

 @note The permission dialog will only be shown once. If the user denies permission, subsequent calls
 will not show the dialog again. Users must manually enable notifications in Settings.

 @note This is a class method and can be called directly on PushwooshConfig without creating an instance.

 @see handlePushRegistration: for processing the received device token
 @see unregisterForPushNotifications: to disable push notifications
 */
+ (void)registerForPushNotifications;

/**
 Unregisters the device from push notifications.

 Removes the device from receiving push notifications. This method disables push notifications
 for the current device and notifies Pushwoosh servers to stop sending notifications to this device token.

 @param completion Block called when unregistration completes. Receives nil on success or an NSError on failure.

 Example usage:

 @code
 Pushwoosh.configure.unregisterForPushNotifications { error in
     if let error = error {
         print("Failed to unregister: \(error.localizedDescription)")
     } else {
         print("Successfully unregistered from push notifications")
     }
 }
 @endcode

 @note Unregistration is permanent until registerForPushNotifications is called again.

 @see registerForPushNotifications to re-enable push notifications
 */
+ (void)unregisterForPushNotifications:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 Associates an email address with the current device.

 Register an email for the current user to enable email-based campaigns and user identification.
 The email address must be a valid, non-empty string.

 @param email The user's email address

 Example usage:

 @code
 Pushwoosh.configure.setEmail("user@example.com")
 @endcode

 @note The email is sent to Pushwoosh servers during the next network sync.

 @see setTags: for setting additional user attributes
 */
+ (void)setEmail:(NSString *_Nonnull)email;

/**
 Manually handles the device push token registration.

 Call this method from your AppDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
 to forward the device token to Pushwoosh. The SDK normally handles this automatically, but you can call
 this method directly if you're managing the registration flow manually.

 @param deviceToken The device token received from APNs

 Example usage:

 @code
 func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
     Pushwoosh.configure.handlePushRegistration(deviceToken)
 }
 @endcode

 @note The SDK handles token registration automatically after calling registerForPushNotifications.

 @see registerForPushNotifications for automatic registration
 */
+ (void)handlePushRegistration:(NSData *_Nonnull)deviceToken;

/**
 Handles a received push notification.

 Call this method to process push notification payloads. The SDK will extract notification data
 and trigger appropriate delegate callbacks.

 @param userInfo The notification payload dictionary received from APNs

 @return YES if the notification was handled by Pushwoosh, NO otherwise

 Example usage:

 @code
 func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
     let handled = Pushwoosh.configure.handlePushReceived(userInfo)
     print("Push handled: \(handled)")
 }
 @endcode

 @note This method should be called from your AppDelegate's notification handling methods.

 @see setDelegate: to set a delegate for notification callbacks
 */
+ (BOOL)handlePushReceived:(NSDictionary *_Nonnull)userInfo;

/**
 Returns dictionary with enabled remote notification types.

 Provides information about the current notification settings for the app, including whether
 notifications are enabled and which types (badge, sound, alert) are allowed.

 @return Dictionary containing notification status information, or nil if unavailable

 Example usage:

 @code
 if let status = Pushwoosh.configure.getRemoteNotificationStatus() {
     print("Notification status: \(status)")
 }
 @endcode

 @note The returned dictionary includes keys like "enabled", "pushAlert", "pushBadge", "pushSound", and "type".
 */
+ (NSDictionary *_Nullable)getRemoteNotificationStatus;

/**
 Sets the delegate for receiving push notification events.

 The delegate will receive callbacks when push notifications are received or opened by the user.
 Implement PWMessagingDelegate protocol methods to handle these events.

 @param delegate Object implementing PWMessagingDelegate protocol, or nil to remove the delegate

 Example usage:

 @code
 Pushwoosh.configure.setDelegate(self)
 @endcode

 @see PWMessagingDelegate for available delegate methods
 @see getDelegate to retrieve the current delegate
 */
+ (void)setDelegate:(id<PWMessagingDelegate> _Nullable)delegate;

/**
 Retrieves the current messaging delegate.

 @return The current PWMessagingDelegate object, or nil if not set

 Example usage:

 @code
 let delegate = Pushwoosh.configure.getDelegate()
 @endcode

 @see setDelegate: to set the messaging delegate
 */
+ (id<PWMessagingDelegate> _Nullable)getDelegate;

#if TARGET_OS_IOS
/**
 Sets the delegate for in-app purchase events from rich media.

 The delegate will receive callbacks for in-app purchase events triggered from Pushwoosh rich media content.
 Implement PWPurchaseDelegate protocol methods to handle these events.

 @param delegate Object implementing PWPurchaseDelegate protocol, or nil to remove the delegate

 Example usage:

 @code
 Pushwoosh.configure.setPurchaseDelegate(self)
 @endcode

 @note This method is only available on iOS.

 @see PWPurchaseDelegate for available delegate methods
 @see getPurchaseDelegate to retrieve the current delegate
 */
+ (void)setPurchaseDelegate:(id<PWPurchaseDelegate> _Nullable)delegate;

/**
 Retrieves the current purchase delegate.

 @return The current PWPurchaseDelegate object, or nil if not set

 Example usage:

 @code
 let delegate = Pushwoosh.configure.getPurchaseDelegate()
 @endcode

 @note This method is only available on iOS.

 @see setPurchaseDelegate: to set the purchase delegate
 */
+ (id<PWPurchaseDelegate> _Nullable)getPurchaseDelegate;
#endif

@end

/**
 Configuration interface for Pushwoosh SDK.

 PushwooshConfig provides access to SDK configuration methods through the configure class method.
 All configuration operations should be performed through Pushwoosh.configure.

 Example usage:

 @code
 // Register for push notifications
 Pushwoosh.configure.registerForPushNotifications()

 // Set user tags
 Pushwoosh.configure.setTags(["user_type": "premium"])
 @endcode

 @see PWConfiguration for available configuration methods
 */
@interface PushwooshConfig : NSObject<PWConfiguration>

/**
 Returns the configuration interface.

 Access this property to perform SDK configuration operations.

 @return The PWConfiguration interface

 Example usage:

 @code
 let config = Pushwoosh.configure
 config.registerForPushNotifications()
 @endcode
 */
+ (Class _Nonnull)configure;

@end
