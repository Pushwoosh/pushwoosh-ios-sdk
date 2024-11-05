//
//  PWPushNotificationsManager.h
//  PushNotificationManager
//
//  Created by Kaizer on 06/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PushwooshFramework.h"
#import "PWConfig.h"

@interface PWPushNotificationsManagerCommon : NSObject

- (instancetype)initWithConfig:(PWConfig *)config;

- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion;
- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *))completion;

- (void)updateRegistration;

- (void)handlePushRegistrationFailure:(NSError *)error;
- (void)handlePushRegistrationString:(NSString *)deviceID;
- (BOOL)handlePushReceived:(NSDictionary *)userInfo autoAcceptAllowed:(BOOL)autoAcceptAllowed;
- (BOOL)handlePushAccepted:(NSDictionary *)userInfo onStart:(BOOL)onStart;
- (void)handlePushRegistration:(NSData *)devToken;

- (BOOL)isAppInBackground;

- (NSString *)getCustomPushData:(NSDictionary *)pushNotification;
- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification;
- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification;

- (void)processActionUserInfo:(NSDictionary *)userInfo;
- (BOOL)dispatchInboxPushIfNeeded:(NSDictionary *)userInfo;

+ (void)clearNotificationCenter;
+ (NSMutableDictionary *)getRemoteNotificationStatus;

- (void)registerTestDevice;

- (void)setReverseProxy:(NSString *)url;
- (void)disableReverseProxy;

- (void)registerSmsNumber:(NSString *)number;
- (void)registerWhatsappNumber:(NSString *)number;

@end
