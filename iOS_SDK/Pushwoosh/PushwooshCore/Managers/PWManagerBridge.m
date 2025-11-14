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

@end
