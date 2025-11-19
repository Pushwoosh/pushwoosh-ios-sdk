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

@end
