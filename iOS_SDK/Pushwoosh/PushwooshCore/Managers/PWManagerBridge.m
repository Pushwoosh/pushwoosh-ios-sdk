//
//  PWManagerBridge.m
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWManagerBridge.h"
#import "PWPreferences.h"
#import "PWDataManager.h"
#import "PWPushNotificationsManager.h"
#import "PWServerCommunicationManager.h"
#import "PWInAppManager.h"
#import "PWUtils.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWPurchaseManager.h"
#endif

NSString * const PWInboxMessagesDidUpdateNotification = @"PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox";

@implementation PWManagerBridge

+ (instancetype)shared {
    static PWManagerBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _showPushnotificationAlert = YES;
        _additionalAuthorizationOptions = 0;
    }
    return self;
}

- (void)sendSKPaymentTransactions:(NSArray *)transactions {
    if (self.sendTransactionsBlock) {
        self.sendTransactionsBlock(transactions);
    }
}

- (void)setEmail:(NSString *)email {
    if (self.setEmailBlock) {
        self.setEmailBlock(email);
    }
}

- (NSString *)getPushToken {
    return self.pushToken;
}

+ (NSDictionary *)getRemoteNotificationStatus {
    Class pushNotificationsManagerClass = NSClassFromString(@"PWPushNotificationsManager");
    if (pushNotificationsManagerClass && [pushNotificationsManagerClass respondsToSelector:@selector(getRemoteNotificationStatus)]) {
        return [pushNotificationsManagerClass performSelector:@selector(getRemoteNotificationStatus)];
    }
    return nil;
}

- (NSString *)getHWID {
    return [PWPreferences preferences].hwid;
}

- (NSString *)appCode {
    return [PWPreferences preferences].appCode;
}

- (NSString *)getCustomPushData:(NSDictionary *)pushNotification {
    if (self.pushNotificationManager) {
        return [self.pushNotificationManager getCustomPushData:pushNotification];
    }
    return nil;
}

- (void)handlePushReceived:(NSDictionary *)userInfo {
    [self handlePushReceived:userInfo autoAcceptAllowed:YES];
}

- (BOOL)handlePushReceived:(NSDictionary *)userInfo autoAcceptAllowed:(BOOL)autoAcceptAllowed {
    if (self.pushNotificationManager) {
        return [self.pushNotificationManager handlePushReceived:userInfo autoAcceptAllowed:autoAcceptAllowed];
    }
    return NO;
}

- (void)handlePushRegistration:(NSData *)deviceToken {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager handlePushRegistration:deviceToken];
    }
}

- (void)handlePushRegistrationFailure:(NSError *)error {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager handlePushRegistrationFailure:error];
    }
}

- (void)setTags:(NSDictionary *)tags {
    if (self.dataManager) {
        [self.dataManager setTags:tags];
    }
}

- (void)loadTags:(void (^)(NSDictionary *tags))successBlock error:(void (^)(NSError *error))errorBlock {
    if (self.dataManager) {
        [self.dataManager loadTags:successBlock error:errorBlock];
    }
}

- (void)registerForPushNotifications {
    [self registerForPushNotificationsWithCompletion:nil];
}

- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager registerForPushNotificationsWithCompletion:completion];
    }
}

- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *error))completion {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager unregisterForPushNotificationsWithCompletion:completion];
    }
}

- (BOOL)isServerCommunicationAllowed {
    return [[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed];
}

- (void)startServerCommunication {
    [[PWServerCommunicationManager sharedInstance] startServerCommunication];
}

- (void)stopServerCommunication {
    [[PWServerCommunicationManager sharedInstance] stopServerCommunication];
}

#pragma mark - Tags with Completion

- (void)setTags:(NSDictionary *)tags withCompletion:(void (^)(NSError *error))completion {
    if (self.dataManager) {
        [self.dataManager setTags:tags withCompletion:completion];
    }
}

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email {
    [self setEmailTags:tags forEmail:email withCompletion:nil];
}

- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email withCompletion:(void (^)(NSError *error))completion {
    if (self.dataManager) {
        [self.dataManager setEmailTags:tags forEmail:email withCompletion:completion];
    }
}

#pragma mark - Registration with Tags

- (void)registerForPushNotificationsWith:(NSDictionary *)tags {
    [self registerForPushNotificationsWith:tags completion:nil];
}

- (void)registerForPushNotificationsWith:(NSDictionary *)tags completion:(PushwooshRegistrationHandler)completion {
    [[PWPreferences preferences] setCustomTags:tags];
    [self registerForPushNotificationsWithCompletion:completion];
}

#pragma mark - SMS and WhatsApp

- (void)registerSmsNumber:(NSString *)number {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager registerSmsNumber:number];
    }
}

- (void)registerWhatsappNumber:(NSString *)number {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager registerWhatsappNumber:number];
    }
}

#pragma mark - Badge

- (void)sendBadges:(NSInteger)badge {
    if (self.dataManager) {
        // Badge sending is handled through data manager's server communication
        NSDictionary *tags = @{@"badge": @(badge)};
        [self.dataManager setTags:tags];
    }
}

#pragma mark - User Management

- (void)setUserId:(NSString *)userId {
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.inAppManager) {
        [self.inAppManager setUserId:userId];
    }
#endif
}

- (void)setUserId:(NSString *)userId completion:(void (^)(NSError *error))completion {
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.inAppManager) {
        [self.inAppManager setUserId:userId completion:completion];
    }
#endif
}

- (void)setEmails:(NSArray *)emails {
    [self setEmails:emails completion:nil];
}

- (void)setEmails:(NSArray *)emails completion:(void (^)(NSError *error))completion {
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.inAppManager) {
        [self.inAppManager setEmails:emails completion:completion];
    }
#endif
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails {
    [self setUser:userId emails:emails completion:nil];
}

- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void (^)(NSError *error))completion {
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.inAppManager) {
        [self.inAppManager setUser:userId emails:emails completion:completion];
    }
#endif
}

- (void)setUser:(NSString *)userId email:(NSString *)email completion:(void (^)(NSError *error))completion {
    [self setUser:userId emails:@[email] completion:completion];
}

- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.inAppManager) {
        [self.inAppManager mergeUserId:oldUserId to:newUserId doMerge:doMerge completion:completion];
    }
#endif
}

#pragma mark - Reverse Proxy

- (void)setReverseProxy:(NSString *)url {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager setReverseProxy:url];
    }
}

- (void)disableReverseProxy {
    if (self.pushNotificationManager) {
        [self.pushNotificationManager disableReverseProxy];
    }
}

#pragma mark - URL Handling

#if TARGET_OS_IOS || TARGET_OS_WATCH
- (BOOL)handleOpenURL:(NSURL *)url {
    return [PWUtils handleURL:url];
}
#endif

#pragma mark - Purchases (iOS only)

#if TARGET_OS_IOS
- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date {
    if (self.purchaseManager) {
        [self.purchaseManager sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:date];
    }
}
#endif

#pragma mark - Utility

+ (void)clearNotificationCenter {
    [PWPushNotificationsManager clearNotificationCenter];
}

+ (NSString *)version {
    return @"7.0.6";
}

@end
