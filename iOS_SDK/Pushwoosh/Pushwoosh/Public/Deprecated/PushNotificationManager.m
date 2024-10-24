//
//  PushNotificationManager.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PushNotificationManager.h"
#import "Pushwoosh+Internal.h"
#import "PWPreferences.h"
#import "PWUtils.h"

#import "PWUserNotificationCenterDelegate.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@implementation PWTags

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

@implementation PushNotificationManager

#pragma mark - Init/Teardown

static PushNotificationManager *pushManagerInstance = nil;
static dispatch_once_t pushManagerOncePredicate;

+ (instancetype)pushManager {
    dispatch_once(&pushManagerOncePredicate, ^{
        pushManagerInstance = [PushNotificationManager new];
    });

    return pushManagerInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        [Pushwoosh sharedInstance];
        
        if (![PWConfig config].isUsingPluginForPushHandling) {
            _notificationCenterDelegate = [[PWUserNotificationCenterDelegate alloc] initWithNotificationManager:[Pushwoosh sharedInstance].pushNotificationManager];
        } 
    }
    return self;
}

- (instancetype)initWithApplicationCode:(NSString *)appCode appName:(NSString *)appName {
    [self.class initializeWithAppCode:appCode appName:appName];
    return [self.class pushManager];
}

+ (void)initializeWithAppCode:(NSString *)appCode appName:(NSString *)appName {
    [[PWPreferences preferences] setAppCode:appCode];
    [Pushwoosh sharedInstance];
}

#if TARGET_OS_IOS

- (id)initWithApplicationCode:(NSString *)appCode navController:(UIViewController *)navController appName:(NSString *)appName {
    if (self = [super init]) {
         [self.class initializeWithAppCode:appCode appName:appName];
    }
    return self;
}

- (void)dealloc {
	self.delegate = nil;
}

#endif

#pragma mark - Language

- (void)setLanguage:(NSString *)language {
    [PWPreferences preferences].language = language;
}

- (NSString *)language {
    return [PWPreferences preferences].language;
}

#pragma push notifications

- (void)registerForPushNotifications {
    [[Pushwoosh sharedInstance] registerForPushNotifications];
}

- (void)handlePushRegistrationFailure:(NSError *)error {
	[[Pushwoosh sharedInstance] handlePushRegistrationFailure:error];
}

+ (void)clearNotificationCenter {
	[Pushwoosh clearNotificationCenter];
}

+ (NSMutableDictionary *)getRemoteNotificationStatus {
	return [Pushwoosh getRemoteNotificationStatus];
}

- (void)handlePushRegistrationString:(NSString *)deviceID {
	[[Pushwoosh sharedInstance].pushNotificationManager handlePushRegistrationString:deviceID];
}

- (void)handlePushAccepted:(NSDictionary *)userInfo onStart:(BOOL)onStart {
    [[Pushwoosh sharedInstance].pushNotificationManager handlePushAccepted:userInfo onStart:onStart];
}

- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification {
    return [[Pushwoosh sharedInstance].pushNotificationManager getCustomPushDataAsNSDict:pushNotification];
}

- (NSString *)getCustomPushData:(NSDictionary *)pushNotification {
    return [[Pushwoosh sharedInstance].pushNotificationManager getCustomPushData:pushNotification];
}

- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification {
	return [[Pushwoosh sharedInstance].pushNotificationManager getApnPayload:pushNotification];
}

- (BOOL)handlePushReceived:(NSDictionary *)userInfo {
    return [[Pushwoosh sharedInstance] handlePushReceived:userInfo];
}

- (void)handlePushRegistration:(NSData *)devToken {
	[[Pushwoosh sharedInstance] handlePushRegistration:devToken];
}

- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *))completion {
    [[Pushwoosh sharedInstance] unregisterForPushNotificationsWithCompletion:completion];
}

- (void)unregisterForPushNotifications {
	[[Pushwoosh sharedInstance] unregisterForPushNotificationsWithCompletion:nil];
}

#pragma mark - Getters

- (NSString *)getHWID {
	return [PWPreferences preferences].hwid;
}

- (NSString *)appCode {
	return [PWPreferences preferences].appCode;
}

- (NSString *)appName {
	return [PWPreferences preferences].appName;
}

- (NSString *)getPushToken {
	return [PWPreferences preferences].pushToken;
}

+ (NSString *)pushwooshVersion {
    return [Pushwoosh version];
}

#pragma mark - Location

#if TARGET_OS_IOS

- (void)startLocationTracking {
    [self informUserAboutGeozones];
}

- (void)stopLocationTracking {
    [self informUserAboutGeozones];
}

- (void)sendLocation:(CLLocation *)location {
    [self informUserAboutGeozones];
}

- (void)informUserAboutGeozones {
    NSString *message = @"This Geozones API is deprecated. Please use PushwooshGeozones Framework";
    
    if ([PWUtils getAPSProductionStatus:NO]) {
        PWLogError(message);
    } else {
        [NSException raise:@"PWGeozonesException" format:@"%@", message];
    }
}

#pragma mark - In-App Messages

- (void)setUserId:(NSString *)userId completion:(void(^)(NSError * error))completion {
	[[Pushwoosh sharedInstance] setUserId:userId completion:completion];
}

- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
	[[Pushwoosh sharedInstance] mergeUserId:oldUserId to:newUserId doMerge:doMerge completion:completion];
}

#pragma mark - Posting Events

- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes completion:(void (^)(NSError *error))completion {
	[[Pushwoosh sharedInstance].inAppManager postEvent:event withAttributes:attributes completion:completion];
}

- (void)postEvent:(NSString *)event withAttributes:(NSDictionary *)attributes {
	[[Pushwoosh sharedInstance].inAppManager postEvent:event withAttributes:attributes];
}

#pragma mark - purchase

- (void)sendSKPaymentTransactions:(NSArray *)transactions {
	[[Pushwoosh sharedInstance] sendSKPaymentTransactions:transactions];
}

- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date {
	[[Pushwoosh sharedInstance] sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:date];
}

#endif

#pragma mark - Data

#if TARGET_OS_IOS || TARGET_OS_WATCH
- (void)setShowPushnotificationAlert:(BOOL)showPushnotificationAlert {
    [Pushwoosh sharedInstance].showPushnotificationAlert = showPushnotificationAlert;
}

- (BOOL)showPushnotificationAlert {
    return [Pushwoosh sharedInstance].showPushnotificationAlert;
}
#endif

- (void)setTags:(NSDictionary *)tags {
	[[Pushwoosh sharedInstance] setTags:tags];
}

- (void)setTags:(NSDictionary *)tags withCompletion:(void (^)(NSError *error))completion {
	[[Pushwoosh sharedInstance] setTags:tags completion:completion];
}

- (void)loadTags {
	[[Pushwoosh sharedInstance].dataManager loadTags];
}

- (void)loadTags:(PushwooshGetTagsHandler)successHandler error:(PushwooshErrorHandler)errorHandler {
    [[Pushwoosh sharedInstance] getTags:successHandler onFailure:errorHandler];
}

- (void)sendAppOpen {
    [[Pushwoosh sharedInstance].dataManager sendAppOpenWithCompletion:nil];
}

+ (BOOL)isPushwooshMessage:(NSDictionary *)userInfo {
    return [PWMessage isPushwooshMessage:userInfo];
}

#pragma mark - Internal

+ (void)destroy {
	pushManagerOncePredicate = 0;
	pushManagerInstance = nil;
}

@end
