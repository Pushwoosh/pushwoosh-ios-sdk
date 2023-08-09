//
//  Pushwoosh.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2020
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS || TARGET_OS_WATCH

#import <UserNotifications/UserNotifications.h>

#endif

#if TARGET_OS_IOS

#import <StoreKit/StoreKit.h>

#endif

#define PUSHWOOSH_VERSION @"6.5.1"


@class Pushwoosh, PWMessage, PWNotificationCenterDelegateProxy;


typedef void (^PushwooshRegistrationHandler)(NSString * _Nullable token, NSError * _Nullable error);
typedef void (^PushwooshGetTagsHandler)(NSDictionary * _Nullable tags);
typedef void (^PushwooshErrorHandler)(NSError * _Nullable error);


/**
 `PWMessagingDelegate` protocol defines the methods that can be implemented in the delegate of the `Pushwoosh` class' singleton object.
 These methods provide information about the key events for push notification manager such as, receiving push notifications and opening the received notification.
 These methods implementation allows to react on these events properly.
 */
@protocol PWMessagingDelegate <NSObject>

@optional
/**
 Tells the delegate that the application has received a remote notification.
 
 @param pushwoosh The push manager that received the remote notification.
 @param message A PWMessage object that contains information referring to the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
*/
- (void)pushwoosh:(Pushwoosh * _Nonnull)pushwoosh onMessageReceived:(PWMessage * _Nonnull)message;

/**
Tells the delegate that the user has pressed on the push notification banner.

@param pushwoosh The push manager that received the remote notification.
@param message A PWMessage object that contains information about the remote notification, potentially including a badge number for the application icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
*/
- (void)pushwoosh:(Pushwoosh * _Nonnull)pushwoosh onMessageOpened:(PWMessage * _Nonnull)message;

@end

/**
 `PWPurchaseDelegate` protocol defines the methods that can be implemented in the delegate of the `Pushwoosh` class' singleton object.
 These methods provide callbacks for events related to purchasing In-App products from rich medias, such as successful purchase event, failed payment, etc.
 These methods implementation allows to react on such events properly.
 */

@protocol PWPurchaseDelegate <NSObject>

@optional
/**
 Tells the delegate that the application received  the array of products
 
 @param products Array of SKProduct instances.
 */
- (void)onPWInAppPurchaseHelperProducts:(NSArray<SKProduct *>* _Nullable)products;

/**
 Tells the delegate that the transaction is in queue, user has been charged.
 
 @param identifier Identifier agreed upon with the store.
 */
- (void)onPWInAppPurchaseHelperPaymentComplete:(NSString* _Nullable)identifier;

/**
 Tells the delegate that the transaction was cancelled or failed before being added to the server queue.
 
 @param identifier The unique server-provided identifier.
 @param error The transaction failed.
 */
- (void)onPWInAppPurchaseHelperPaymentFailedProductIdentifier:(NSString* _Nullable)identifier error:(NSError* _Nullable)error;

/**
 Tells the delegate that a user initiates an IAP buy from the App Store
 
 @param identifier Product identifier
 */
- (void)onPWInAppPurchaseHelperCallPromotedPurchase:(NSString* _Nullable)identifier;

/**
 Tells the delegate that an error occurred while restoring transactions.
 
 @param error Error transaction.
 */
- (void)onPWInAppPurchaseHelperRestoreCompletedTransactionsFailed:(NSError * _Nullable)error;

@end


/**
 Message from Pushwoosh.
*/
@interface PWMessage : NSObject

/**
 Title of the push message.
*/
@property (nonatomic, readonly) NSString * _Nullable title;

/**
 Subtitle of the push message.
*/
@property (nonatomic, readonly) NSString * _Nullable subTitle;

/**
 Body of the push message.
*/
@property (nonatomic, readonly) NSString * _Nullable message;

/**
 Badge number of the push message.
*/
@property (nonatomic, readonly) NSUInteger badge;

/**
 Extension badge number of the push message.
*/
@property (nonatomic, readonly) NSUInteger badgeExtension;

/**
 Remote URL or deeplink from the push message.
*/
@property (nonatomic, readonly) NSString * _Nullable link;

/**
 Returns YES if this message received/opened then the app is in foreground state.
*/
@property (nonatomic, readonly, getter=isForegroundMessage) BOOL foregroundMessage;

/**
 Returns YES if this message contains 'content-available' key (silent or newsstand push).
*/
@property (nonatomic, readonly, getter=isContentAvailable) BOOL contentAvailable;

/**
 Returns YES if this is inbox message.
*/
@property (nonatomic, readonly, getter=isInboxMessage) BOOL inboxMessage;

/**
 Gets custom JSON data from push notifications dictionary as specified in Pushwoosh Control Panel.
*/
@property (nonatomic, readonly) NSDictionary * _Nullable customData;

/**
 Original payload of the message.
*/
@property (nonatomic, readonly) NSDictionary * _Nullable payload;

/**
 Returns YES if this message is recieved from Pushwoosh.
*/
+ (BOOL)isPushwooshMessage:(NSDictionary *_Nonnull)userInfo;

@end


/**
 `Pushwoosh` class offers access to the singleton-instance of the push manager responsible for registering the device with the APS servers, receiving and processing push notifications.
 */
@interface Pushwoosh : NSObject

/**
 Pushwoosh Application ID. Usually retrieved automatically from Info.plist parameter `Pushwoosh_APPID`
 */
@property (nonatomic, copy, readonly) NSString * _Nonnull applicationCode;

/**
 `PushNotificationDelegate` protocol delegate that would receive the information about events for push notification manager such as registering with APS services, receiving push notifications or working with the received notification.
 Pushwoosh Runtime sets it to ApplicationDelegate by default
 */
@property (nonatomic, weak) NSObject<PWMessagingDelegate> * _Nullable delegate;

/**
 `PushPurchaseDelegate` protocol delegate that would receive the information about events related to purchasing InApp products from rich medias
 */
@property (nonatomic, weak) NSObject<PWPurchaseDelegate> * _Nullable purchaseDelegate;

#if TARGET_OS_IOS || TARGET_OS_WATCH

/**
 Show push notifications alert when push notification is received while the app is running, default is `YES`
 */
@property (nonatomic, assign) BOOL showPushnotificationAlert;

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
 Initializes Pushwoosh.
 @param appCode Pushwoosh App ID.
 */
+ (void)initializeWithAppCode:(NSString *_Nonnull)appCode;

/**
 Returns an object representing the current push manager.
 
 @return A singleton object that represents the push manager.
 */
+ (instancetype _Nonnull )sharedInstance;

/**
 Registers for push notifications. By default registeres for "UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert" flags.
 Automatically detects if you have "newsstand-content" in "UIBackgroundModes" and adds "UIRemoteNotificationTypeNewsstandContentAvailability" flag.
 */
- (void)registerForPushNotifications;
- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler _Nullable )completion;

/**
Unregisters from push notifications.
*/
- (void)unregisterForPushNotifications;
- (void)unregisterForPushNotificationsWithCompletion:(void (^_Nullable)(NSError * _Nullable error))completion;

/**
 Handle registration to remote notifications.
*/
- (void)handlePushRegistration:(NSData * _Nonnull)devToken;
- (void)handlePushRegistrationFailure:(NSError * _Nonnull)error;

/**
 Handle received push notification.
*/
- (BOOL)handlePushReceived:(NSDictionary * _Nonnull)userInfo;

/**
 * Change default base url to reverse proxy url
 * @param url - reverse proxy url
*/
- (void)setReverseProxy:(NSString * _Nonnull)url;

/**
 * Disables reverse proxy
*/
- (void)disableReverseProxy;

/**
 Send tags to server. Tag names have to be created in the Pushwoosh Control Panel. Possible tag types: Integer, String, Incremental (integer only), List tags (array of values).
 
 Example:
 @code
 NSDictionary *tags =  @{ @"Alias" : aliasField.text,
                      @"FavNumber" : @([favNumField.text intValue]),
                          @"price" : [PWTags incrementalTagWithInteger:5],
                           @"List" : @[ @"Item1", @"Item2", @"Item3" ]
 };
    
 [[PushNotificationManager pushManager] setTags:tags];
 @endcode
 
 @param tags Dictionary representation of tags to send.
 */
- (void)setTags:(NSDictionary * _Nonnull)tags;

/**
 Send tags to server with completion block. If setTags succeeds competion is called with nil argument. If setTags fails completion is called with error.
 */
- (void)setTags:(NSDictionary * _Nonnull)tags completion:(void (^_Nullable)(NSError * _Nullable error))completion;

- (void)setEmailTags:(NSDictionary * _Nonnull)tags forEmail:(NSString * _Nonnull)email;

- (void)setEmailTags:(NSDictionary * _Nonnull)tags forEmail:(NSString * _Nonnull)email completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Get tags from server. Calls delegate method if exists and handler (block).
 
 @param successHandler The block is executed on the successful completion of the request. This block has no return value and takes one argument: the dictionary representation of the recieved tags.
 Example of the dictionary representation of the received tags:
 {
     Country = ru;
     Language = ru;
 }
 @param errorHandler The block is executed on the unsuccessful completion of the request. This block has no return value and takes one argument: the error that occurred during the request.
 */
- (void)getTags:(PushwooshGetTagsHandler _Nullable)successHandler onFailure:(PushwooshErrorHandler _Nullable)errorHandler;

/**
 Sends current badge value to server. Called internally by SDK Runtime when `UIApplication` `setApplicationBadgeNumber:` is set. This function is used for "auto-incremeting" badges to work.
 This way Pushwoosh server can know what current badge value is set for the application.
 
 @param badge Current badge value.
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
 @code
 - (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
     [[PushNotificationManager pushManager] sendSKPaymentTransactions:transactions];
 }
 @endcode
 
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
 Gets current push token.
 
 @return Current push token. May be nil if no push token is available yet.
 */
- (NSString * _Nullable)getPushToken;

/**
 Gets HWID. Unique device identifier that used in all API calls with Pushwoosh.
 This is identifierForVendor for iOS >= 7.
 
 @return Unique device identifier.
 */
- (NSString * _Nonnull)getHWID;

/**
 Returns dictionary with enabled remove notificaton types.
 
 Example enabled push:
 @code
 {
    enabled = 1;
    pushAlert = 1;
    pushBadge = 1;
    pushSound = 1;
    type = 7;
 }
 @endcode
 where "type" field is UIUserNotificationType
 
 Disabled push:
 @code
 {
    enabled = 1;
    pushAlert = 0;
    pushBadge = 0;
    pushSound = 0;
    type = 0;
 }
 @endcode
 
 Note: In the latter example "enabled" field means that device can receive push notification but could not display alerts (ex: silent push)
 */
+ (NSMutableDictionary * _Nullable)getRemoteNotificationStatus;

/**
 Clears the notifications from the notification center.
 */
+ (void)clearNotificationCenter;

/**
 Set User indentifier. This could be Facebook ID, username or email, or any other user ID.
 This allows data and events to be matched across multiple user devices.
 If setUserId succeeds competion is called with nil argument. If setUserId fails completion is called with error.
 
 @param userId user identifier
 */
- (void)setUserId:(NSString * _Nonnull)userId completion:(void(^ _Nullable)(NSError * _Nullable error))completion;

/**
 Set User indentifier. This could be Facebook ID, username or email, or any other user ID.
 This allows data and events to be matched across multiple user devices.
 
 @param userId user identifier
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
 Register email associated to the current user. Email should be a string and could not be null or empty.
 
 @param email user's email string
 */
- (void)setEmail:(NSString * _Nonnull)email;

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
 Sends live activity token to the server.
 Call this method when you create a live activity.
 
 Example:
 @code
 do {
     let activity = try Activity<PushwooshAppAttributes>.request(
         attributes: attributes,
         contentState: contentState,
         pushType: .token)
     for await data in activity.pushTokenUpdates {
         let token = data.map {String(format: "%02x", $0)}.joined()
         try await Pushwoosh.sharedInstance().startLiveActivity(withToken: token)
         return token
     }
 } catch (let error) {
     print(error.localizedDescription)
     return nil
 }
 @endcode
 */
- (void)startLiveActivityWithToken:(NSString * _Nonnull)token;
- (void)startLiveActivityWithToken:(NSString * _Nonnull)token completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

/**
 Call this method when you finish working with the live activity.
 
 Example:
 @code
 func end(activity: Activity<PushwooshAppAttributes>) {
     Task {
         await activity.end(dismissalPolicy: .immediate)
         try await Pushwoosh.sharedInstance().stopLiveActivity()
     }
 }
 @endcode
 */
- (void)stopLiveActivity;
- (void)stopLiveActivityWithCompletion:(void (^ _Nullable)(NSError * _Nullable error))completion;

@end

/**
`PWNotificationCenterDelegateProxy` class handles notifications on iOS 10 and forwards methods of UNUserNotificationCenterDelegate to all added delegates.
*/
#if TARGET_OS_IOS || TARGET_OS_WATCH
@interface PWNotificationCenterDelegateProxy : NSObject <UNUserNotificationCenterDelegate>
#elif TARGET_OS_OSX
@interface PWNotificationCenterDelegateProxy : NSObject <NSUserNotificationCenterDelegate>
#endif
/**
 Returns UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10
*/
#if TARGET_OS_IOS || TARGET_OS_WATCH
@property (nonatomic, strong, readonly) id<UNUserNotificationCenterDelegate> _Nonnull defaultNotificationCenterDelegate;
#elif TARGET_OS_OSX
@property (nonatomic, strong, readonly) id<NSUserNotificationCenterDelegate> defaultNotificationCenterDelegate;
#endif

/**
 Adds extra UNUserNotificationCenterDelegate that handles foreground push notifications on iOS10.
*/
#if TARGET_OS_IOS || TARGET_OS_WATCH
- (void)addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate> _Nonnull)delegate;
#endif
@end


/**
`PWTagsBuilder` class encapsulates the methods for creating tags parameters for sending them to the server.
*/
@interface PWTagsBuilder : NSObject
/**
 Creates a dictionary for incrementing/decrementing a numeric tag on the server.
 
 Example:
 @code
 NSDictionary *tags = @{
     @"Alias" : aliasField.text,
     @"FavNumber" : @([favNumField.text intValue]),
     @"price": [PWTags incrementalTagWithInteger:5],
 };
 
 [[PushNotificationManager pushManager] setTags:tags];
 @endcode
 
 @param delta Difference that needs to be applied to the tag's counter.
 
 @return Dictionary, that needs to be sent as the value for the tag
 */
+ (NSDictionary * _Nullable)incrementalTagWithInteger:(NSInteger)delta;

/**
 Creates a dictionary for extending Tag’s values list with additional values
 
 Example:
 
 @code
 NSDictionary *tags = @{
     @"Alias" : aliasField.text,
     @"FavNumber" : @([favNumField.text intValue]),
     @"List" : [PWTags appendValuesToListTag:@[ @"Item1" ]]
 };
 
 [[PushNotificationManager pushManager] setTags:tags];
 @endcode
 
 @param array Array of values to be added to the tag.
 
 @return Dictionary to be sent as the value for the tag
 */
+ (NSDictionary * _Nullable)appendValuesToListTag:(NSArray<NSString *> * _Nonnull)array;

@end
