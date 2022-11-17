//
//  PWPushNotificationsManager.m
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationsManager.h"
#import "PWPushNotificationsManager+Internal.h"
#import "PWUtils.h"
#import "PWPreferences.h"
#import "Pushwoosh+Internal.h"
#import "PWGDPRManager.h"

@implementation PWPushNotificationsManager

- (void)internalRegisterForPushNotifications {
    [PWUtils getAPSProductionStatus:YES];
    
    [self.notificationManagerCompat registerForPushNotifications];
}

@end
