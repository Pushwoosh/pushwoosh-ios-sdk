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

#pragma mark - Tags with Completion

- (void)setTags:(NSDictionary *)tags withCompletion:(void (^)(NSError *error))completion;
- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email;
- (void)setEmailTags:(NSDictionary *)tags forEmail:(NSString *)email withCompletion:(void (^)(NSError *error))completion;

#pragma mark - Registration with Tags

- (void)registerForPushNotificationsWith:(NSDictionary *)tags;
- (void)registerForPushNotificationsWith:(NSDictionary *)tags completion:(PushwooshRegistrationHandler)completion;

#pragma mark - SMS and WhatsApp

- (void)registerSmsNumber:(NSString *)number;
- (void)registerWhatsappNumber:(NSString *)number;

#pragma mark - Badge

- (void)sendBadges:(NSInteger)badge;

#pragma mark - User Management

- (void)setUserId:(NSString *)userId;
- (void)setUserId:(NSString *)userId completion:(void (^)(NSError *error))completion;
- (void)setEmails:(NSArray *)emails;
- (void)setEmails:(NSArray *)emails completion:(void (^)(NSError *error))completion;
- (void)setUser:(NSString *)userId emails:(NSArray *)emails;
- (void)setUser:(NSString *)userId emails:(NSArray *)emails completion:(void (^)(NSError *error))completion;
- (void)setUser:(NSString *)userId email:(NSString *)email completion:(void (^)(NSError *error))completion;
- (void)mergeUserId:(NSString *)oldUserId to:(NSString *)newUserId doMerge:(BOOL)doMerge completion:(void (^)(NSError *error))completion;

#pragma mark - Reverse Proxy

- (void)setReverseProxy:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers;

#pragma mark - URL Handling

#if TARGET_OS_IOS || TARGET_OS_WATCH
- (BOOL)handleOpenURL:(NSURL *)url;
#endif

#pragma mark - Purchases (iOS only)

#if TARGET_OS_IOS
- (void)sendPurchase:(NSString *)productIdentifier withPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode andDate:(NSDate *)date;
#endif

#pragma mark - Utility

+ (void)clearNotificationCenter;
+ (NSString *)version;

@end
