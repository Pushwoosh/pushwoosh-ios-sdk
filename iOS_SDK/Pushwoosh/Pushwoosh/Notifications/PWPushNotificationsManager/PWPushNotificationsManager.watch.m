//
//  PWPushNotificationManager.watch.m
//  Pushwoosh.watchOS
//
//  Created by Fectum on 23/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWPushNotificationsManager.h"
#import "PWPushNotificationsManager+Internal.h"
#import "PWUtils.h"
#import "PWInteractivePush.h"
#import <WatchKit/WatchKit.h>

@implementation PWPushNotificationsManager

- (void)internalRegisterForPushNotifications {
    [PWUtils getAPSProductionStatus:YES];
    
    [PWInteractivePush getCategoriesWithCompletion:^(NSSet *categories) {
        [self.notificationManagerCompat registerUserNotifications:categories completion:^{
            [self.notificationManagerCompat registerForPushNotifications];
        }];
    }];
}

- (BOOL)isAppInBackground {
    return [WKExtension sharedExtension].applicationState != WKApplicationStateActive;
}

@end
