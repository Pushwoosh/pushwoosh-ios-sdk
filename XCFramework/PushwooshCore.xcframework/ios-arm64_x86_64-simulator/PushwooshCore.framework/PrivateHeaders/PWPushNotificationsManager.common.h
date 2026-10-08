//
//  PWPushNotificationsManager.common.h
//  PushNotificationManager
//
//  Created by Kaizer on 06/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PWConfig.h>
#import <PushwooshCore/PWTypes.h>

/// User defaults key of the hashes of the last received pushes.
FOUNDATION_EXPORT NSString * const kPWReceivedPushHashesKey;

@interface PWPushNotificationsManagerCommon : NSObject

- (instancetype)initWithConfig:(PWConfig *)config;

- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion;
- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *))completion;

/// Unregisters the device from the application it is leaving, pinned to that application's code and
/// host. The local push token is deliberately kept so the device can register into the new application.
- (void)unregisterFromApplicationWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl;

- (void)updateRegistration;

- (void)handlePushRegistrationFailure:(NSError *)error;
- (void)handlePushRegistrationString:(NSString *)deviceID;
/// YES for a Pushwoosh push; a repeat of the last push returns NO as before, while a visible content-available
/// push on iOS stays YES when it was already received through another delivery path.
- (BOOL)handlePushReceived:(NSDictionary *)userInfo autoAcceptAllowed:(BOOL)autoAcceptAllowed;

/// The app's own handlePushReceived: call. A visible content-available push on iOS returns NO only when the app
/// passes it again, not after SDK deliveries; any other push is answered as before.
- (BOOL)handlePushReceivedFromApp:(NSDictionary *)userInfo;

- (BOOL)handlePushAccepted:(NSDictionary *)userInfo onStart:(BOOL)onStart;
- (void)handlePushRegistration:(NSData *)devToken;

/// How many device tokens were handed to the SDK in this process, by the app or by the runtime hook.
@property (nonatomic, readonly) NSUInteger pushRegistrationCount;

- (BOOL)isAppInBackground;

- (NSString *)getCustomPushData:(NSDictionary *)pushNotification;
- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification;
- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification;

- (void)processActionUserInfo:(NSDictionary *)userInfo;

/// Same destinations, but only one of them: rich media wins over the `l` deep link.
/// An inbox card is one tap with one outcome, while a push may legitimately do both.
- (void)processInboxActionUserInfo:(NSDictionary *)userInfo;
- (BOOL)dispatchInboxPushIfNeeded:(NSDictionary *)userInfo;

+ (void)clearNotificationCenter;
+ (NSMutableDictionary *)getRemoteNotificationStatus;

- (void)registerTestDevice;

- (void)setReverseProxy:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers;

- (void)registerSmsNumber:(NSString *)number;
- (void)registerWhatsappNumber:(NSString *)number;

@end
