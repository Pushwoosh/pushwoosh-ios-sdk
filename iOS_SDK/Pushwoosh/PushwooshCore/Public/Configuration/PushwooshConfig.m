//
//  PushwooshConfig.m
//  PushwooshCore
//
//  Created by André Kis on 16.04.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshConfig.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWInAppManager.h>

@implementation PushwooshConfig

+ (Class)configure {
    return self;
}

+ (void)setAppCode:(NSString *)appCode {
    [[PWPreferences preferences] setAppCode:appCode];
}

+ (NSString *)getAppCode {
    return [[PWPreferences preferences] appCode];
}

+ (NSString *)getApplicationCode {
    return [[PWPreferences preferences] appCode];
}

+ (void)setApiToken:(NSString *)apiToken {
    [[PWPreferences preferences] setApiToken:apiToken];
}

+ (NSString *)getApiToken {
    return [[PWPreferences preferences] apiToken];
}

+ (NSString *)getHWID {
    return [[PWManagerBridge shared] getHWID];
}

+ (NSString *)getPushToken {
    return [[PWManagerBridge shared] getPushToken];
}

+ (BOOL)isServerCommunicationAllowed {
    return [[PWManagerBridge shared] isServerCommunicationAllowed];
}

+ (void)startServerCommunication {
    [[PWManagerBridge shared] startServerCommunication];
}

+ (void)stopServerCommunication {
    [[PWManagerBridge shared] stopServerCommunication];
}

+ (void)setTags:(NSDictionary *)tags {
    [[PWManagerBridge shared] setTags:tags];
}

+ (void)loadTags:(void (^)(NSDictionary *tags))successBlock error:(void (^)(NSError *error))errorBlock {
    [[PWManagerBridge shared] loadTags:successBlock error:errorBlock];
}

+ (void)registerForPushNotifications {
    [[PWManagerBridge shared] registerForPushNotifications];
}

+ (void)unregisterForPushNotifications:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] unregisterForPushNotificationsWithCompletion:completion];
}

+ (void)setEmail:(NSString *)email {
    [[PWManagerBridge shared] setEmail:email];
}

+ (void)setUserId:(NSString *)userId {
    [[PWManagerBridge shared].inAppManager setUserId:userId];
}

+ (NSString *)getUserId {
    return [[PWPreferences preferences] userId];
}

+ (void)setLanguage:(NSString *)language {
    [[PWPreferences preferences] setLanguage:language];
}

+ (NSString *)getLanguage {
    return [[PWPreferences preferences] language];
}

+ (void)setShowPushnotificationAlert:(BOOL)show {
    [[PWPreferences preferences] setShowForegroundNotifications:show];
    [[PWManagerBridge shared] setShowPushnotificationAlert:show];
}

+ (BOOL)getShowPushnotificationAlert {
    return [[PWPreferences preferences] showForegroundNotifications];
}

+ (void)handlePushRegistration:(NSData *)deviceToken {
    [[PWManagerBridge shared] handlePushRegistration:deviceToken];
}

+ (void)handlePushRegistrationFailure:(NSError *)error {
    [[PWManagerBridge shared] handlePushRegistrationFailure:error];
}

+ (BOOL)handlePushReceived:(NSDictionary *)userInfo {
    return [[PWManagerBridge shared] handlePushReceived:userInfo autoAcceptAllowed:YES];
}

+ (NSDictionary *)getRemoteNotificationStatus {
    return [PWManagerBridge getRemoteNotificationStatus];
}

+ (void)setDelegate:(id<PWMessagingDelegate>)delegate {
    [[PWManagerBridge shared] setDelegate:delegate];
}

+ (id<PWMessagingDelegate>)getDelegate {
    return [[PWManagerBridge shared] delegate];
}

#if TARGET_OS_IOS
+ (void)setPurchaseDelegate:(id<PWPurchaseDelegate>)delegate {
    [[PWManagerBridge shared] setPurchaseDelegate:delegate];
}

+ (id<PWPurchaseDelegate>)getPurchaseDelegate {
    return [[PWManagerBridge shared] purchaseDelegate];
}
#endif

#pragma mark - Tags with Completion

+ (void)setTags:(NSDictionary *)tags completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setTags:tags withCompletion:completion];
}

+ (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email {
    [[PWManagerBridge shared] setEmailTags:tags forEmail:email];
}

+ (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setEmailTags:tags forEmail:email withCompletion:completion];
}

+ (void)getTags:(PushwooshGetTagsHandler)successHandler onFailure:(PushwooshErrorHandler)errorHandler {
    [[PWManagerBridge shared] loadTags:successHandler error:errorHandler];
}

#pragma mark - Registration with Completion

+ (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion {
    [[PWManagerBridge shared] registerForPushNotificationsWithCompletion:completion];
}

+ (void)registerForPushNotificationsWith:(NSDictionary *)tags {
    [[PWManagerBridge shared] registerForPushNotificationsWith:tags];
}

+ (void)registerForPushNotificationsWith:(NSDictionary *)tags completion:(PushwooshRegistrationHandler)completion {
    [[PWManagerBridge shared] registerForPushNotificationsWith:tags completion:completion];
}

#pragma mark - SMS and WhatsApp

+ (void)registerSmsNumber:(NSString *)number {
    [[PWManagerBridge shared] registerSmsNumber:number];
}

+ (void)registerWhatsappNumber:(NSString *)number {
    [[PWManagerBridge shared] registerWhatsappNumber:number];
}

#pragma mark - Email with Completion

+ (void)setEmail:(NSString *)email completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setEmails:@[email] completion:completion];
}

+ (void)setEmails:(NSArray *)emails {
    [[PWManagerBridge shared] setEmails:emails];
}

+ (void)setEmails:(NSArray *)emails completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setEmails:emails completion:completion];
}

#pragma mark - User Management

+ (void)setUserId:(NSString *)userId completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setUserId:userId completion:completion];
}

+ (void)setUser:(NSString *)userId emails:(NSArray *)emails {
    [[PWManagerBridge shared] setUser:userId emails:emails];
}

+ (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setUser:userId emails:emails completion:completion];
}

+ (void)setUser:(NSString *)userId email:(NSString *)email completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] setUser:userId email:email completion:completion];
}

+ (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
    [[PWManagerBridge shared] mergeUserId:oldUserId to:newUserId doMerge:doMerge completion:completion];
}

#pragma mark - Reverse Proxy

+ (void)setReverseProxy:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers {
    [[PWManagerBridge shared] setReverseProxy:url headers:headers];
}

#pragma mark - Badge

+ (void)sendBadges:(NSInteger)badge {
    [[PWManagerBridge shared] sendBadges:badge];
}

#pragma mark - URL Handling

#if TARGET_OS_IOS || TARGET_OS_WATCH
+ (BOOL)handleOpenURL:(NSURL *)url {
    return [[PWManagerBridge shared] handleOpenURL:url];
}
#endif

#pragma mark - Purchases (iOS only)

#if TARGET_OS_IOS
+ (void)sendSKPaymentTransactions:(NSArray *)transactions {
    [[PWManagerBridge shared] sendSKPaymentTransactions:transactions];
}

+ (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date {
    [[PWManagerBridge shared] sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:date];
}
#endif

#pragma mark - Utility

+ (void)clearNotificationCenter {
    [PWManagerBridge clearNotificationCenter];
}

+ (NSString *)version {
    return [PWManagerBridge version];
}

+ (NSString *)getCustomPushData:(NSDictionary *)pushNotification {
    return [[PWManagerBridge shared] getCustomPushData:pushNotification];
}

@end
