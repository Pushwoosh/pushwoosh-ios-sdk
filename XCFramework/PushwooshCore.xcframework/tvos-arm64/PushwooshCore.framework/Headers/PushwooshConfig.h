//
//  PushwooshConfig.h
//  PushwooshCore
//
//  Created by André Kis on 16.04.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWPreferences.h>

@protocol PWMessagingDelegate;
#if TARGET_OS_IOS
@protocol PWPurchaseDelegate;
#endif

@protocol PWConfiguration <NSObject>

+ (void)setAppCode:(NSString *_Nonnull)appCode;
+ (NSString *_Nullable)getAppCode;

+ (void)setApiToken:(NSString *_Nonnull)apiToken;
+ (NSString *_Nullable)getApiToken;

+ (NSString *_Nonnull)getHWID;
+ (NSString *_Nullable)getPushToken;

+ (BOOL)isServerCommunicationAllowed;
+ (void)startServerCommunication;
+ (void)stopServerCommunication;

+ (void)setTags:(NSDictionary *_Nonnull)tags;
+ (void)loadTags:(void (^_Nullable)(NSDictionary *_Nullable tags))successBlock error:(void (^_Nullable)(NSError *_Nullable error))errorBlock;

+ (void)registerForPushNotifications;
+ (void)unregisterForPushNotifications:(void (^_Nullable)(NSError *_Nullable error))completion;

+ (void)setEmail:(NSString *_Nonnull)email;

+ (void)handlePushRegistration:(NSData *_Nonnull)deviceToken;
+ (BOOL)handlePushReceived:(NSDictionary *_Nonnull)userInfo;

+ (NSDictionary *_Nullable)getRemoteNotificationStatus;

+ (void)setDelegate:(id<PWMessagingDelegate> _Nullable)delegate;
+ (id<PWMessagingDelegate> _Nullable)getDelegate;

#if TARGET_OS_IOS
+ (void)setPurchaseDelegate:(id<PWPurchaseDelegate> _Nullable)delegate;
+ (id<PWPurchaseDelegate> _Nullable)getPurchaseDelegate;
#endif

@end

@interface PushwooshConfig : NSObject<PWConfiguration>

+ (Class _Nonnull)configure;

@end
