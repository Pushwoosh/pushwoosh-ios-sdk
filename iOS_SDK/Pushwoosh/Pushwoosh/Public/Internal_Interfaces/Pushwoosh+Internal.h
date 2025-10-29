//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PushwooshFramework.h"
#import <PushwooshCore/PWDataManager.h>
#import <PushwooshCore/PWPushNotificationsManager.h>
#if TARGET_OS_IOS || TARGET_OS_TV
#import "PWInAppManager.h"
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_IPHONE
#import <PushwooshCore/PWBusinessCaseManager.h>
#import <PushwooshCore/PWRichPushManager.h>
#import <PushwooshCore/PWPurchaseManager.h>
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
#import <PushwooshCore/PWInAppMessagesManager.h>
#endif

@interface Pushwoosh ()

@property (nonatomic, strong) PWDataManager *dataManager;

@property (nonatomic, strong) PWPushNotificationsManager *pushNotificationManager;

#if TARGET_OS_IOS || TARGET_OS_TV
@property (nonatomic, strong) PWInAppManager *inAppManager;
#endif

#if TARGET_OS_IOS || TARGET_OS_OSX

@property (nonatomic, strong) PWPurchaseManager *purchaseManager;

@property (nonatomic, strong) PWRichPushManager *richPushManager;

#endif

@property (nonatomic, copy) NSDictionary *launchNotification;

- (instancetype)initWithApplicationCode:(NSString *)appCode;

+ (void)destroy;

@end

