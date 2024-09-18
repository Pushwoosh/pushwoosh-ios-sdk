//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PushwooshFramework.h"
#import "PWDataManager.h"
#import "PWPushNotificationsManager.h"
#import "PWInAppManager.h"

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_IPHONE
#import "PWBusinessCaseManager.h"
#import "PWRichPushManager.h"
#import "PWInAppMessagesManager.h"
#import "PWPurchaseManager.h"
#endif

@interface Pushwoosh ()

@property (nonatomic, strong) PWDataManager *dataManager;

@property (nonatomic, strong) PWPushNotificationsManager *pushNotificationManager;

@property (nonatomic, strong) PWInAppManager *inAppManager;

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_IPHONE

@property (nonatomic, strong) PWPurchaseManager *purchaseManager;

@property (nonatomic, strong) PWRichPushManager *richPushManager;

#endif

@property (nonatomic, copy) NSDictionary *launchNotification;

- (instancetype)initWithApplicationCode:(NSString *)appCode;

+ (void)destroy;

@end

