//
//  PWPushNotificationsManager+Internal.h
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationsManager.common.h"

#import "PWNotificationManagerCompat.h"

@interface PWPushNotificationsManagerCommon (Internal)

@property (nonatomic, strong) PWNotificationManagerCompat *notificationManagerCompat;

- (void)internalRegisterForPushNotifications;

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo;
- (void)processUserInfo:(NSDictionary *)userInfo;

@end
