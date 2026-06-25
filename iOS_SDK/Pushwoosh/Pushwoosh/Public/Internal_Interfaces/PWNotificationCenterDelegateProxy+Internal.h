//
//  PWNotificationCenterDelegateProxy+Internal.h
//  Pushwoosh
//
//  Created by Fectum on 28.02.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

@class PWPushNotificationsManager;

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UserNotifications/UserNotifications.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface PWNotificationCenterDelegateProxy ()

- (instancetype)initWithNotificationManager:(PWPushNotificationsManager *)manager;

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)preserveExistingDelegate:(nullable id<UNUserNotificationCenterDelegate>)existingDelegate;

/// Overrides the delay before the proxy force-completes a notification a delegate never completed.
/// Tests set it small so the fallback path can be observed without a real-time wait.
+ (void)setCompletionFallbackDelayForTesting:(NSTimeInterval)delay;
#endif

@end

NS_ASSUME_NONNULL_END
