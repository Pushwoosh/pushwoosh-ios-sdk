//
//  Pushwoosh.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2020
//

#import "Pushwoosh+Internal.h"
#import "PushwooshFramework.h"
#import <PushwooshCore/PWUtils.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PWUserNotificationCenterDelegate.h>
#import "PWNotificationCenterDelegateProxy+Internal.h"
#import <PushwooshCore/PWInAppStorage.h>
#import "PushNotificationManager.h"
#import "PWInAppManager+Internal.h"
#import <PushwooshCore/PWHashDecoder.h>
#import <PushwooshCore/NSDictionary+PWDictUtils.h>
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PushwooshConfig.h>
#import <PushwooshCore/PWConfig.h>

#if TARGET_OS_IOS || TARGET_OS_OSX
#import <PushwooshCore/PWVersionTracking.h>
#import <PushwooshCore/PWRequestsCacheManager.h>
#import <PushwooshCore/PWRichMediaManager.h>
#endif

#if TARGET_OS_IOS
#import <PushwooshCore/PWMedia.h>
#endif

#if defined(__cplusplus)
#define let auto const
#else
#define let const __auto_type
#endif

@implementation Pushwoosh

- (NSDictionary *)launchNotification {
    return [PWManagerBridge shared].launchNotification;
}

+ (Class<PWLiveActivities>)LiveActivities {
    [self ensureInitialized];
    let pushwooshLiveActivities = NSClassFromString(@"PushwooshLiveActivitiesImplementationSetup");
    if (pushwooshLiveActivities != nil) {
        return [pushwooshLiveActivities performSelector:@selector(liveActivities)];
    } else {
        return [PWStubLiveActivities liveActivities];
    }
}

+ (Class<PWDebug>)debug {
    return [PushwooshLog debug];
}

+ (Class<PWVoIP>)VoIP {
    [self ensureInitialized];
    let pushwooshVoIP = NSClassFromString(@"PushwooshVoIPImplementation");
    if (pushwooshVoIP != nil) {
        return [pushwooshVoIP performSelector:@selector(voip)];
    } else {
        return [PWVoIPStub voip];
    }
}

+ (Class<PWForegroundPush>)ForegroundPush {
    [self ensureInitialized];
    let pushwooshForeground = NSClassFromString(@"PushwooshForegroundPushImplementation");
    if (pushwooshForeground != nil) {
        return [pushwooshForeground performSelector:@selector(foregroundPush)];
    } else {
        return [PWForegroundPushStub foregroundPush];
    }
}

+ (Class<PWTVoS>)TVoS {
    [self ensureInitialized];
    let pushwooshTVOS = NSClassFromString(@"PushwooshTVOSImplementation");
    if (pushwooshTVOS != nil) {
        return [pushwooshTVOS performSelector:@selector(tvos)];
    } else {
        return [PWTVoSStub tvos];
    }
}

+ (Class<PWKeychain>)Keychain {
    [self ensureInitialized];
    let pushwooshKeychain = NSClassFromString(@"PushwooshKeychainImplementation");
    if (pushwooshKeychain != nil) {
        return [pushwooshKeychain performSelector:@selector(keychain)];
    } else {
        return [PWKeychainStub keychain];
    }
}

#if TARGET_OS_IOS
+ (Class<PWMedia>)media {
    return [PWMedia media];
}
#endif

+ (Class)configure {
    [self ensureInitialized];
    [self sharedInstance];
    return [PushwooshConfig configure];
}

static Pushwoosh *pushwooshInstance = nil;
static dispatch_once_t pushwooshOncePredicate;
static dispatch_once_t ensureInitializedOncePredicate;

#pragma mark - Setup

+ (void)ensureInitialized {
    dispatch_once(&ensureInitializedOncePredicate, ^{
        NSString *appCode = [PushwooshConfig getAppCode];

        if (!appCode || appCode.length == 0) {
            appCode = [[PWConfig config] appId];
        }

        if (appCode && appCode.length > 0) {
            [[PWPreferences preferences] setAppCode:appCode];
        }
    });
}

+ (instancetype)sharedInstance {
    [self ensureInitialized];

    dispatch_once(&pushwooshOncePredicate, ^{
        NSString *appCode = [PWPreferences preferences].appCode;
        pushwooshInstance = [[Pushwoosh alloc] initWithApplicationCode:appCode];
    });

    return pushwooshInstance;
}

+ (void)initializeWithAppCode:(NSString *)appCode {
    if ([PWPreferences checkAppCodeforChanges:appCode]) {
        [Pushwoosh initializeWithNewAppCode:appCode];
    }

    [Pushwoosh sharedInstance];
}

+ (void)initializeWithNewAppCode:(NSString *)appCode {
    [Pushwoosh destroy];

    [[PWPreferences preferences] setAppCode:appCode];
    [PWInAppManager updateInAppManagerInstance];
    [[Pushwoosh sharedInstance].dataManager sendAppOpenWithCompletion:nil];

}

- (instancetype)initWithApplicationCode:(NSString *)appCode {
    if (self = [super init]) {
        // Mandatory logs
        NSLog(@"[PW] BUNDLE ID: %@", [PWUtils bundleId]);
        NSLog(@"[PW] APP CODE: %@", [PWPreferences preferences].appCode);
        NSLog(@"[PW] PUSHWOOSH SDK VERSION: %@", PUSHWOOSH_VERSION);
        NSLog(@"[PW] HWID: %@", [PWPreferences preferences].hwid);
#if TARGET_OS_TV
        NSLog(@"[PW] PUSH TV TOKEN: %@", [PWPreferences preferences].pushTvToken);
#else
        NSLog(@"[PW] PUSH TOKEN: %@", [PWPreferences preferences].pushToken);
#endif
        
        [PWPreferences preferences].appCode = appCode;
        
#if TARGET_OS_IOS || TARGET_OS_OSX
        self.purchaseManager = [PWPurchaseManager new];
        self.richPushManager = [PWRichPushManager new];
        [PWRequestsCacheManager sharedInstance];
#endif
        
#if TARGET_OS_IOS
        //Create PWGeozonesManager instance (if linked) on application start. Otherwise after app relaunch geozones may not work.
        Class geozonesManagerClass = NSClassFromString(@"PWGeozonesManager");
        
        if (geozonesManagerClass) {
            [geozonesManagerClass sharedManager];
        }
#endif
        
#if TARGET_OS_IOS || TARGET_OS_WATCH
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Will show foreground notifications: %d", self.showPushnotificationAlert]];
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
        self.inAppManager = [PWInAppManager sharedManager];
#endif

        self.pushNotificationManager = [[PWPushNotificationsManager alloc] initWithConfig:[PWConfig config]];

        self.dataManager = [PWDataManager new];

        [PWManagerBridge shared].dataManager = self.dataManager;
        [PWManagerBridge shared].pushNotificationManager = self.pushNotificationManager;
        [PWManagerBridge shared].showPushnotificationAlert = self.showPushnotificationAlert;
#if TARGET_OS_IOS || TARGET_OS_TV
        [PWManagerBridge shared].inAppManager = self.inAppManager;
        [PWManagerBridge shared].inAppMessagesManager = self.inAppManager.inAppMessagesManager;
#endif
#if TARGET_OS_IOS || TARGET_OS_OSX
        [PWManagerBridge shared].purchaseManager = self.purchaseManager;
        [PWManagerBridge shared].richPushManager = self.richPushManager;
        [PWManagerBridge shared].richMediaManager = [PWRichMediaManager sharedManager];
#endif

        if (![PWConfig config].isUsingPluginForPushHandling) {
            _notificationCenterDelegateProxy = [[PWNotificationCenterDelegateProxy alloc] initWithNotificationManager:self.pushNotificationManager];
        }
        
    }
    
    return self;
}

#pragma mark - Register/Unregister

- (void)registerForPushNotifications {
    [self internalRegisterForPushNotificationWith:nil completion:nil];
}

- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion {
    [self internalRegisterForPushNotificationWith:nil completion:completion];
}

- (void)registerForPushNotificationsWith:(NSDictionary *)tags {
    [self internalRegisterForPushNotificationWith:tags completion:nil];
}

- (void)registerForPushNotificationsWith:(NSDictionary *)tags completion:(PushwooshRegistrationHandler)completion {
    [self internalRegisterForPushNotificationWith:tags completion:completion];
}

- (void)internalRegisterForPushNotificationWith:(NSDictionary *)tags completion:(PushwooshRegistrationHandler)completion {
    if (![[PWManagerBridge shared] isServerCommunicationAllowed]) {
        NSString *error = @"Communication with Pushwoosh is disabled. You have to enable the server communication to register for push notifications. To enable the server communication use startServerCommunication method.";
        if (completion) {
            completion(nil, [PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:error]);
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"%@", error]];
        }
        return;
    }
#if TARGET_OS_IOS
    [[PWPreferences preferences] setCustomTags:tags];
#endif
    [self.pushNotificationManager registerForPushNotificationsWithCompletion:completion];
}

- (void)handlePushRegistration:(NSData *)deviceToken {
    [self.pushNotificationManager handlePushRegistration:deviceToken];
}

- (void)handlePushRegistrationFailure:(NSError *)error {
    [self.pushNotificationManager handlePushRegistrationFailure:error];
}

- (void)unregisterForPushNotifications {
    [self unregisterForPushNotificationsWithCompletion:nil];
}

- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *error))completion {
    if (![[PWManagerBridge shared] isServerCommunicationAllowed]) {
        NSString *error = @"Communication with Pushwoosh is disabled. You have to enable the server communication to unregister from push notifications. To enable the server communication use startServerCommunication method.";
        if (completion) {
            completion([PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:error]);
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"%@", error]];
        }
        return;
    }
    [self.pushNotificationManager unregisterForPushNotificationsWithCompletion:completion];
}

#pragma mark - SMS and Whatsapp methods

- (void)registerSmsNumber:(NSString * _Nonnull) number {
    [self.pushNotificationManager registerSmsNumber:number];
}

- (void)registerWhatsappNumber:(NSString * _Nonnull) number {
    [self.pushNotificationManager registerWhatsappNumber:number];
}

#pragma mark - Proxy URL

- (void)setReverseProxy:(NSString *)url {
    [PushwooshConfig setReverseProxy:url headers:nil];
}

#pragma mark - Delegates

#if TARGET_OS_IOS
- (void)setPurchaseDelegate:(NSObject<PWPurchaseDelegate> *)purchaseDelegate {
    _purchaseDelegate = purchaseDelegate;
    [PWManagerBridge shared].purchaseDelegate = purchaseDelegate;
}
#endif

- (void)setDataManager:(PWDataManager *)dataManager {
    _dataManager = dataManager;
    [PWManagerBridge shared].dataManager = dataManager;
}

- (void)setDelegate:(NSObject<PWMessagingDelegate> *)delegate {
    _delegate = delegate;
    [PWManagerBridge shared].delegate = delegate;
}

#pragma mark - Receive Push

- (BOOL)handlePushReceived:(NSDictionary *)userInfo {
    return [self.pushNotificationManager handlePushReceived:userInfo autoAcceptAllowed:YES];
}

#pragma mark - Tags

- (void)setTags:(NSDictionary *)tags {
    [self setTags:tags completion:nil];
}

- (void)setTags:(NSDictionary *)tags completion:(void (^)(NSError *error))completion {
    [self.dataManager setTags:tags withCompletion:completion];
}

- (void)getTags:(PushwooshGetTagsHandler)successHandler onFailure:(PushwooshErrorHandler)errorHandler {
    [self.dataManager loadTags:successHandler error:errorHandler];
}

#pragma mark - Email Tags

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email {
    [self setEmailTags:tags forEmail:email completion:nil];
}

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email completion:(void(^)(NSError *error))completion {
    [self.dataManager setEmailTags:tags forEmail:email withCompletion:completion];
}

#pragma mark - Data

- (void)setShowPushnotificationAlert:(BOOL)showPushnotificationAlert {
    [PWPreferences preferences].showForegroundNotifications = showPushnotificationAlert;
    [PWManagerBridge shared].showPushnotificationAlert = showPushnotificationAlert;
}

- (BOOL)showPushnotificationAlert {
    return [PWPreferences preferences].showForegroundNotifications;
}

- (void)setLanguage:(NSString *)language {
    [PWPreferences preferences].language = language;
    [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"Language has been set to: %@", language]];
}

- (NSString *)language {
    return [PWPreferences preferences].language;
}

#pragma mark - Info

+ (NSString *)version {
    return PUSHWOOSH_VERSION;
}

- (NSString *)getHWID {
    return [PWPreferences preferences].hwid;
}

- (NSString *)getUserId {
    return [PWPreferences preferences].userId;
}

- (NSString *)applicationCode {
    return [PWPreferences preferences].appCode;
}

- (NSString *)getPushToken {
    return [PWPreferences preferences].pushToken;
}

+ (NSMutableDictionary *)getRemoteNotificationStatus {
    return [PWPushNotificationsManager getRemoteNotificationStatus];
}

- (void)sendPushToStartLiveActivityToken:(NSString *)token {
    [self sendPushToStartLiveActivityToken:token completion:nil];
}

- (void)sendPushToStartLiveActivityToken:(NSString *_Nullable)token completion:(void (^ _Nullable)(NSError * _Nullable))completion {
    [self.dataManager sendPushToStartLiveActivityToken:token completion:completion];
}

- (void)startLiveActivityWithToken:(NSString *)token activityId:(NSString * _Nullable)activityId {
    [self startLiveActivityWithToken:token activityId:activityId completion:nil];
}

- (void)startLiveActivityWithToken:(NSString *)token activityId:(NSString * _Nullable)activityId completion:(void (^)(NSError * _Nullable))completion {
    [self.dataManager startLiveActivityWithToken:token activityId:activityId completion:completion];
}

- (void)stopLiveActivity {
    [self stopLiveActivityWithCompletion:nil];
}

- (void)stopLiveActivityWithCompletion:(void (^)(NSError * _Nullable))completion {
    [self.dataManager stopLiveActivityWith:nil completion:completion];
}

- (void)stopLiveActivityWith:(NSString *)activityId {
    [self.dataManager stopLiveActivityWith:activityId completion:nil];
}

- (void)stopLiveActivityWith:(NSString *)activityId completion:(void (^)(NSError * _Nullable))completion {
    [self.dataManager stopLiveActivityWith:activityId completion:completion];
}

#if TARGET_OS_IOS

#pragma mark - Purchases

- (void)sendSKPaymentTransactions:(NSArray *)transactions {
    [self.purchaseManager sendSKPaymentTransactions:transactions];
}

- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date {
    [self.purchaseManager sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:date];
}

#endif

#pragma mark - Notification Center

+ (void)clearNotificationCenter {
    [PWPushNotificationsManager clearNotificationCenter];
}

#pragma mark - User

- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion {
    [self.inAppManager setUserId:userId completion:completion];
}

- (void)setUserId:(NSString *)userId {
    [self setUserId:userId completion:nil];
}

- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
    [self.inAppManager mergeUserId:oldUserId to:newUserId doMerge:doMerge completion:completion];
}

#if TARGET_OS_IOS || TARGET_OS_WATCH
- (BOOL)handleOpenURL:(NSURL *)url {
    return [PWUtils handleURL:url];
}
#endif

- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    [self.inAppManager setEmails:emails completion:completion];
}

- (void)setEmails:(NSArray *)emails {
    [self setEmails:emails completion:nil];
}

- (void)setEmail:(NSString *)email completion:(void(^)(NSError * error))completion {
    [self.inAppManager setEmails:@[email] completion:completion];
}

- (void)setEmail:(NSString *)email {
    [self.inAppManager setEmails:@[email] completion:nil];
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    [self.inAppManager setUser:userId emails:emails completion:completion];
}

- (void)setUser:(NSString *)userId email:(NSString *)email completion:(void(^)(NSError * error))completion {
    [self.inAppManager setUser:userId emails:@[email] completion:completion];
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails {
    [self.inAppManager setUser:userId emails:emails completion:nil];
}

- (void)startServerCommunication {
    [[PWManagerBridge shared] startServerCommunication];
}

- (void)stopServerCommunication {
    [[PWManagerBridge shared] stopServerCommunication];
}

#pragma mark - Teardown

+ (void)destroy {
    pushwooshOncePredicate = 0;
    pushwooshInstance = nil;
}

@end


@implementation PWTagsBuilder

+ (NSDictionary *)incrementalTagWithInteger:(NSInteger)delta {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"increment", @"operation", @(delta), @"value", nil];
}

+ (NSDictionary *)appendValuesToListTag:(NSArray<NSString *> *)array {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"append", @"operation", array, @"value", nil];
}

+ (NSDictionary *)removeValuesFromListTag:(NSArray<NSString *> *)array {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"remove", @"operation", array, @"value", nil];
}

@end
