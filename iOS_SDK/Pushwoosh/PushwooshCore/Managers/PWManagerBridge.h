//
//  PWManagerBridge.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <PushwooshCore/PWInboxBridge.h>
#import <PushwooshCore/PWTypes.h>

@class PWDataManager;
@class PWPushNotificationsManager;
@class PWInAppManager;
@class PWPurchaseManager;
@class PWRichPushManager;
@class PWRichMediaManager;
@class PWInAppMessagesManager;

@interface PWManagerBridge : NSObject

@property (nonatomic, strong) PWDataManager *dataManager;
@property (nonatomic, strong) PWPushNotificationsManager *pushNotificationManager;

#if TARGET_OS_IOS || TARGET_OS_TV
@property (nonatomic, strong) PWInAppManager *inAppManager;
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX
@property (nonatomic, strong) PWPurchaseManager *purchaseManager;
@property (nonatomic, strong) PWRichPushManager *richPushManager;
@property (nonatomic, strong) PWRichMediaManager *richMediaManager;
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
@property (nonatomic, strong) PWInAppMessagesManager *inAppMessagesManager;
#endif

@property (nonatomic, copy) NSDictionary *launchNotification;
@property (nonatomic, copy) NSString *pushToken;
@property (nonatomic) BOOL showPushnotificationAlert;
@property (nonatomic) UNAuthorizationOptions additionalAuthorizationOptions;

@property (nonatomic, copy) void (^setEmailBlock)(NSString *email);
@property (nonatomic, copy) void (^sendTransactionsBlock)(NSArray *transactions);

@property (nonatomic, strong) Class<PWInboxBridge> inboxBridge;

@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) id delegateSender;
@property (nonatomic, weak) id purchaseDelegate;
@property (nonatomic, copy) NSDictionary * (^getRemoteNotificationStatusBlock)(void);
@property (nonatomic, copy) NSString *appName;

+ (instancetype)shared;

- (void)sendSKPaymentTransactions:(NSArray *)transactions;
- (void)setEmail:(NSString *)email;
- (NSString *)getPushToken;
+ (NSDictionary *)getRemoteNotificationStatus;

- (NSString *)getHWID;
- (NSString *)appCode;
- (NSString *)getCustomPushData:(NSDictionary *)pushNotification;

- (void)handlePushReceived:(NSDictionary *)userInfo;
- (BOOL)handlePushReceived:(NSDictionary *)userInfo autoAcceptAllowed:(BOOL)autoAcceptAllowed;
- (void)handlePushRegistration:(NSData *)deviceToken;
- (void)handlePushRegistrationFailure:(NSError *)error;

- (void)setTags:(NSDictionary *)tags;
- (void)loadTags:(void (^)(NSDictionary *tags))successBlock error:(void (^)(NSError *error))errorBlock;
- (void)registerForPushNotifications;
- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)completion;
- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *error))completion;

- (BOOL)isServerCommunicationAllowed;
- (void)startServerCommunication;
- (void)stopServerCommunication;

@end
