//
//  PWUserNotificationCenterDelegate.h
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 14/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationsManager.h"

#import <Foundation/Foundation.h>


#if TARGET_OS_IOS || TARGET_OS_WATCH

#import <UserNotifications/UserNotifications.h>

@interface PWUserNotificationCenterDelegate : NSObject<UNUserNotificationCenterDelegate>


#else


@interface PWUserNotificationCenterDelegate : NSObject<NSUserNotificationCenterDelegate>


#endif


- (instancetype)initWithNotificationManager:(PWPushNotificationsManager*)manager;

@end
