//
//  Pushwoosh.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2020
//

#import "Pushwoosh+Internal.h"
#import "PWUtils.h"
#import "PWPreferences.h"
#import "PWUserNotificationCenterDelegate.h"
#import "PWNotificationCenterDelegateProxy+Internal.h"
#import "PWPreferences.h"
#import "PWInAppStorage.h"
#import "PWServerCommunicationManager.h"
#import "PushNotificationManager.h"
#import "PWHashDecoder.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWVersionTracking.h"
#import "PWRequestsCacheManager.h"
#endif

@implementation Pushwoosh

static Pushwoosh *pushwooshInstance = nil;
static dispatch_once_t pushwooshOncePredicate;

#pragma mark - Setup

+ (instancetype)sharedInstance {
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
        NSString *apiToken = [PWConfig config].apiToken ?: [PWConfig config].pushwooshApiToken;
        if (apiToken) {
            NSLog(@"[PW] API TOKEN: %@", [PWUtils stringWithVisibleFirstAndLastFourCharacters:apiToken]);
        } else {
            NSLog(@"[PW] API TOKEN: (null)");
        }
        NSLog(@"[PW] HWID: %@", [PWPreferences preferences].hwid);
        NSLog(@"[PW] PUSH TOKEN: %@", [PWPreferences preferences].pushToken);
        
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
        PWLogDebug(@"Will show foreground notifications: %d", self.showPushnotificationAlert);
#endif
        
        self.inAppManager = [PWInAppManager sharedManager];
        
        self.pushNotificationManager = [[PWPushNotificationsManager alloc] initWithConfig:[PWConfig config]];
        
        self.dataManager = [PWDataManager new];
        
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
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        NSString *error = @"Communication with Pushwoosh is disabled. You have to enable the server communication to register for push notifications. To enable the server communication use startServerCommunication method.";
        if (completion) {
            completion(nil, [PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:error]);
        } else {
            PWLogError(error);
        }
        return;
    }
#if TARGET_OS_IOS
    static BOOL isSubscriptionSegmentsCasePresented = NO;
    
    [[PWPreferences preferences] setCustomTags:tags];
    
    if (!isSubscriptionSegmentsCasePresented) {
        isSubscriptionSegmentsCasePresented = YES;
        
        [[PWBusinessCaseManager sharedManager] startBusinessCase:kPWIncreaseRateBusinessCase completion:^(PWBusinessCaseResult result) {
            isSubscriptionSegmentsCasePresented = NO;
            
            if (result != PWBusinessCaseResultSuccess && result != PWBusinessCaseResultIntervalFail) {
                [self.pushNotificationManager registerForPushNotificationsWithCompletion:completion];
                
                [[PWBusinessCaseManager sharedManager] startBusinessCase:kPWRecoveryBusinessCase completion:^(PWBusinessCaseResult result) {
                    
                }];
            }
        }];
    } else {
        [self.pushNotificationManager registerForPushNotificationsWithCompletion:completion];
    }
#else
    [_pushNotificationManager registerForPushNotificationsWithCompletion:completion];
#endif
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
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        NSString *error = @"Communication with Pushwoosh is disabled. You have to enable the server communication to unregister from push notifications. To enable the server communication use startServerCommunication method.";
        if (completion) {
            completion([PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:error]);
        } else {
            PWLogError(error);
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
    [self.pushNotificationManager setReverseProxy:url];
}

- (void)disableReverseProxy {
    [self.pushNotificationManager disableReverseProxy];
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
}

- (BOOL)showPushnotificationAlert {
    return [PWPreferences preferences].showForegroundNotifications;
}

- (void)setLanguage:(NSString *)language {
    [PWPreferences preferences].language = language;
    PWLogInfo(@"Language has been set to: %@", language);
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

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    [self.inAppManager setUser:userId emails:emails completion:completion];
}

- (void)setUser:(NSString *)userId email:(NSString *)email completion:(void(^)(NSError * error))completion {
    NSMutableArray *emails = [[NSMutableArray alloc] init];
    [emails addObject:email];
    
    [self.inAppManager setUser:userId emails:emails completion:completion];
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails {
    [self.inAppManager setUser:userId emails:emails completion:nil];
}

- (void)setEmails:(NSArray *)emails completion:(void(^)(NSError * error))completion {
    [self.inAppManager setEmails:emails completion:completion];
}

- (void)setEmails:(NSArray *)emails {
    [self.inAppManager setEmails:emails completion:nil];
}

- (void)setEmail:(NSString *)email  completion:(void(^)(NSError * error))completion{
    NSMutableArray *emails = [[NSMutableArray alloc] init];
    [emails addObject:email];
    
    [self.inAppManager setEmails:emails completion:completion];
}

- (void)setEmail:(NSString *)email {
    NSMutableArray *emails = [[NSMutableArray alloc] init];
    [emails addObject:email];
    
    [self.inAppManager setEmails:emails completion:nil];
}



- (void)startServerCommunication {
    [[PWServerCommunicationManager sharedInstance] startServerCommunication];
}

- (void)stopServerCommunication {
    [[PWServerCommunicationManager sharedInstance] stopServerCommunication];
}

#pragma mark - Teardown

+ (void)destroy {
    pushwooshOncePredicate = 0;
    pushwooshInstance = nil;
}

@end

@implementation PWMessage

- (instancetype)initWithPayload:(NSDictionary *)payload foreground:(BOOL)foreground {
    if (self = [super init]) {
        NSDictionary *apsDict = [payload pw_dictionaryForKey:@"aps"];
        NSString *alertString = [apsDict pw_stringForKey:@"alert"];
        NSString *hash = [payload pw_stringForKey:@"p"];
        
        [[PWHashDecoder sharedInstance] parseMessageHash:hash];

        _messageCode = [PWHashDecoder sharedInstance].messageCode;
        _messageId = [PWHashDecoder sharedInstance].messageId;
        _campaignId = [PWHashDecoder sharedInstance].campaignId;

        if (alertString) {
            _message = alertString;
        } else {
            NSDictionary *alertDict = [apsDict pw_dictionaryForKey:@"alert"];
            
            if (alertDict) {
                _message = [alertDict pw_stringForKey:@"body"];
                _title = [alertDict pw_stringForKey:@"title"];
                _subTitle = [alertDict pw_stringForKey:@"subtitle"];
            }
        }
        
        _link = [payload pw_stringForKey:@"l"];
        _badge = [[apsDict pw_numberForKey:@"badge"] unsignedIntValue];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:[[PWConfig config] appGroupsName]];
        _badgeExtension = [defaults integerForKey:@"badge_count"];
        
        NSString *customDataString = [payload pw_stringForKey:@"u"];
        
        if (customDataString) {
            NSDictionary *customData = [NSJSONSerialization JSONObjectWithData:[customDataString dataUsingEncoding:NSUTF8StringEncoding]
                                                                       options:0
                                                                         error:nil];
            
            if ([customData isKindOfClass:[NSDictionary class]]) {
                _customData = customData;
            }
        }
        
        _payload = payload;
        _actionIdentifier = [payload pw_stringForKey:@"actionIdentifier"];
        _contentAvailable = apsDict[@"content-available"] != nil;
        _foregroundMessage = foreground;
        _inboxMessage = apsDict[@"pw_inbox"] != nil;
    }
    
    return self;
}

- (NSString *)description {
    return _payload.description;
}

+ (BOOL)isContentAvailablePush:(NSDictionary *)userInfo {
    NSDictionary *apsDict = [userInfo pw_dictionaryForKey:@"aps"];
    return apsDict[@"content-available"] != nil;
}

+ (BOOL)isPushwooshMessage:(NSDictionary *)userInfo {
    return userInfo[@"pw_msg"] != nil;
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
