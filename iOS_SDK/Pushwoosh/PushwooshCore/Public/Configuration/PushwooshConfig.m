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
#import "PWSetAdvertisingIdRequest.h"
#import "PWNetworkModule.h"
#import "PWServerCommunicationManager.h"
#import "PWConfig.h"
#import <PushwooshCore/PWSdkStateProvider.h>
#import <PushwooshCore/PushwooshLog.h>

@implementation PushwooshConfig

+ (NSString *)trim:(NSString *)value {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *trimmed = [value stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

+ (NSString *)validateAndTrim:(NSString *)value forSelector:(SEL)selector {
    if (value == nil) {
        return nil;
    }
    NSString *trimmed = [self trim:value];
    if (trimmed == nil) {
        [self logIgnoredForSelector:selector];
    }
    return trimmed;
}

+ (NSArray<NSString *> *)trimEmails:(NSArray *)emails forSelector:(SEL)selector {
    if (emails == nil) {
        return nil;
    }
    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:emails.count];
    for (id entry in emails) {
        NSString *trimmed = [self trim:entry];
        if (trimmed != nil) {
            [result addObject:trimmed];
        }
    }
    if (result.count == 0) {
        [self logIgnoredForSelector:selector];
        return nil;
    }
    return [result copy];
}

+ (void)logIgnoredForSelector:(SEL)selector {
    [PushwooshLog pushwooshLog:PW_LL_WARN
                     className:[PushwooshConfig class]
                       message:[NSString stringWithFormat:@"%@ ignored: empty or whitespace-only value",
                                NSStringFromSelector(selector)]];
}

+ (Class)configure {
    return self;
}

+ (void)executeOrQueue:(dispatch_block_t)block {
    [[PWSdkStateProvider sharedInstance] executeOrQueue:block];
}

+ (void)setAppCode:(NSString *)appCode {
    NSString *value = [self validateAndTrim:appCode forSelector:_cmd];
    if (appCode != nil && value == nil) return;
    if (value != nil && [value rangeOfString:@"."].location != NSNotFound) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:[PushwooshConfig class]
                           message:@"setAppCode: ignored — Application id format with '.' is deprecated. Please contact Pushwoosh support."];
        return;
    }
    [[PWPreferences preferences] setAppCode:value];
}

+ (NSString *)getAppCode {
    return [[PWPreferences preferences] appCode];
}

+ (NSString *)getApplicationCode {
    return [[PWPreferences preferences] appCode];
}

+ (void)setApiToken:(NSString *)apiToken {
    NSString *value = [self validateAndTrim:apiToken forSelector:_cmd];
    if (apiToken != nil && value == nil) return;
    [[PWPreferences preferences] setApiToken:value];
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
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setTags:tags];
    }];
}

+ (void)loadTags:(void (^)(NSDictionary *tags))successBlock error:(void (^)(NSError *error))errorBlock {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] loadTags:successBlock error:errorBlock];
    }];
}

+ (void)registerForPushNotifications {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] registerForPushNotifications];
    }];
}

+ (void)unregisterForPushNotifications:(void (^)(NSError *error))completion {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] unregisterForPushNotificationsWithCompletion:completion];
    }];
}

+ (void)setEmail:(NSString *)email {
    NSString *value = [self validateAndTrim:email forSelector:_cmd];
    if (email != nil && value == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setEmail:value];
    }];
}

+ (void)setUserId:(NSString *)userId {
    NSString *value = [self validateAndTrim:userId forSelector:_cmd];
    if (userId != nil && value == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared].inAppManager setUserId:value];
    }];
}

+ (NSString *)getUserId {
    return [[PWPreferences preferences] userId];
}

+ (void)setLanguage:(NSString *)language {
    [[PWPreferences preferences] setLanguage:[self trim:language]];
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
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setTags:tags withCompletion:completion];
    }];
}

+ (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setEmailTags:tags forEmail:email];
    }];
}

+ (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email completion:(void (^)(NSError *error))completion {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setEmailTags:tags forEmail:email withCompletion:completion];
    }];
}

+ (void)getTags:(PushwooshGetTagsHandler)successHandler onFailure:(PushwooshErrorHandler)errorHandler {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] loadTags:successHandler error:errorHandler];
    }];
}

#pragma mark - Registration with Completion

+ (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] registerForPushNotificationsWithCompletion:completion];
    }];
}

+ (void)registerForPushNotificationsWith:(NSDictionary *)tags {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] registerForPushNotificationsWith:tags];
    }];
}

+ (void)registerForPushNotificationsWith:(NSDictionary *)tags completion:(PushwooshRegistrationHandler)completion {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] registerForPushNotificationsWith:tags completion:completion];
    }];
}

#pragma mark - SMS and WhatsApp

+ (void)registerSmsNumber:(NSString *)number {
    NSString *value = [self validateAndTrim:number forSelector:_cmd];
    if (number != nil && value == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] registerSmsNumber:value];
    }];
}

+ (void)registerWhatsappNumber:(NSString *)number {
    NSString *value = [self validateAndTrim:number forSelector:_cmd];
    if (number != nil && value == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] registerWhatsappNumber:value];
    }];
}

#pragma mark - Email with Completion

+ (void)setEmail:(NSString *)email completion:(void (^)(NSError *error))completion {
    NSString *value = [self validateAndTrim:email forSelector:_cmd];
    if (email != nil && value == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setEmails:@[value] completion:completion];
    }];
}

+ (void)setEmails:(NSArray *)emails {
    NSArray<NSString *> *trimmed = [self trimEmails:emails forSelector:_cmd];
    if (emails != nil && trimmed == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setEmails:trimmed];
    }];
}

+ (void)setEmails:(NSArray *)emails completion:(void (^)(NSError *error))completion {
    NSArray<NSString *> *trimmed = [self trimEmails:emails forSelector:_cmd];
    if (emails != nil && trimmed == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setEmails:trimmed completion:completion];
    }];
}

#pragma mark - User Management

+ (void)setUserId:(NSString *)userId completion:(void (^)(NSError *error))completion {
    NSString *value = [self validateAndTrim:userId forSelector:_cmd];
    if (userId != nil && value == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setUserId:value completion:completion];
    }];
}

+ (void)setUser:(NSString *)userId emails:(NSArray *)emails {
    NSString *userIdValue = [self validateAndTrim:userId forSelector:_cmd];
    if (userId != nil && userIdValue == nil) return;
    NSArray<NSString *> *emailsValue = [self trimEmails:emails forSelector:_cmd];
    if (emails != nil && emailsValue == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setUser:userIdValue emails:emailsValue];
    }];
}

+ (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void (^)(NSError *error))completion {
    NSString *userIdValue = [self validateAndTrim:userId forSelector:_cmd];
    if (userId != nil && userIdValue == nil) return;
    NSArray<NSString *> *emailsValue = [self trimEmails:emails forSelector:_cmd];
    if (emails != nil && emailsValue == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setUser:userIdValue emails:emailsValue completion:completion];
    }];
}

+ (void)setUser:(NSString *)userId email:(NSString *)email completion:(void (^)(NSError *error))completion {
    NSString *userIdValue = [self validateAndTrim:userId forSelector:_cmd];
    if (userId != nil && userIdValue == nil) return;
    NSString *emailValue = [self validateAndTrim:email forSelector:_cmd];
    if (email != nil && emailValue == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] setUser:userIdValue email:emailValue completion:completion];
    }];
}

+ (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion {
    NSString *oldValue = [self validateAndTrim:oldUserId forSelector:_cmd];
    if (oldUserId != nil && oldValue == nil) return;
    NSString *newValue = [self validateAndTrim:newUserId forSelector:_cmd];
    if (newUserId != nil && newValue == nil) return;
    [self executeOrQueue:^{
        [[PWManagerBridge shared] mergeUserId:oldValue to:newValue doMerge:doMerge completion:completion];
    }];
}

#pragma mark - Advertising

static NSString *const kZeroAdvertisingId = @"00000000-0000-0000-0000-000000000000";

+ (void)setAdvertisingId:(NSString *)advertisingId {
    if (advertisingId.length == 0 || [kZeroAdvertisingId caseInsensitiveCompare:advertisingId] == NSOrderedSame) {
        advertisingId = nil;
    }

    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Communication with Pushwoosh is disabled. To send the request you have to enable the server communication using method startServerCommunication of Pushwoosh class."];
        return;
    }

    PWPreferences *prefs = [PWPreferences preferences];
    NSString *lastSent = prefs.advertisingId;

    if (!advertisingId && (!lastSent || lastSent.length == 0)) {
        return;
    }
    if (advertisingId && [advertisingId isEqualToString:lastSent]) {
        return;
    }

    NSString *normalized = advertisingId;
    [self executeOrQueue:^{
        PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];
        request.advertisingId = normalized;
        [[PWNetworkModule module].requestManager sendRequest:request completion:^(NSError *error) {
            if (!error) {
                [prefs setAdvertisingId:normalized];
            }
        }];
    }];
}

#pragma mark - Reverse Proxy

+ (void)setReverseProxy:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers {
    NSString *value = [self validateAndTrim:url forSelector:_cmd];
    if (url != nil && value == nil) return;
    [[PWManagerBridge shared] setReverseProxy:value headers:headers];
}

#pragma mark - Badge

+ (void)sendBadges:(NSInteger)badge {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] sendBadges:badge];
    }];
}

#pragma mark - URL Handling

#if TARGET_OS_IOS
+ (BOOL)handleOpenURL:(NSURL *)url {
    return [[PWManagerBridge shared] handleOpenURL:url];
}
#endif

#pragma mark - Purchases (iOS only)

#if TARGET_OS_IOS
+ (void)sendSKPaymentTransactions:(NSArray *)transactions {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] sendSKPaymentTransactions:transactions];
    }];
}

+ (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date {
    [self executeOrQueue:^{
        [[PWManagerBridge shared] sendPurchase:productIdentifier withPrice:price currencyCode:currencyCode andDate:date];
    }];
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

#pragma mark - Notification Center Delegate

+ (void)addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate>)delegate {
    if ([PWManagerBridge shared].addNotificationCenterDelegateBlock) {
        [PWManagerBridge shared].addNotificationCenterDelegateBlock(delegate);
    }
}

#pragma mark - Launch Notification

+ (NSDictionary *)getLaunchNotification {
    return [PWManagerBridge shared].launchNotification;
}

#pragma mark - Additional Authorization Options

+ (void)setAdditionalAuthorizationOptions:(UNAuthorizationOptions)options {
    [PWManagerBridge shared].additionalAuthorizationOptions = options;
}

+ (UNAuthorizationOptions)getAdditionalAuthorizationOptions {
    return [PWManagerBridge shared].additionalAuthorizationOptions;
}

@end
