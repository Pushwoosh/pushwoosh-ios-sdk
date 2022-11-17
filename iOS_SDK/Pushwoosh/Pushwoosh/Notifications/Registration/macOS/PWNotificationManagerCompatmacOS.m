//
//  PWNotificationManagerCompatmacOS.m
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationManagerCompatmacOS.h"

@implementation PWNotificationManagerCompatmacOS

- (void)registerForPushNotifications {
    NSRemoteNotificationType types = NSRemoteNotificationTypeBadge | NSRemoteNotificationTypeSound | NSRemoteNotificationTypeAlert;
    [[NSApplication sharedApplication] registerForRemoteNotificationTypes:types];
}

- (void)clearLocalNotifications {
    NSUserNotificationCenter *notificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (NSUserNotification *notification in notificationCenter.deliveredNotifications) {
        if (notification.isRemote) {
            [notificationCenter removeDeliveredNotification:notification];
        }
    }
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    NSInteger type = [[NSApplication sharedApplication] enabledRemoteNotificationTypes];
    results[@"type"] = [NSString stringWithFormat:@"%d", (int)type];
    results[@"pushBadge"] = @"0";
    results[@"pushAlert"] = @"0";
    results[@"pushSound"] = @"0";
    results[@"enabled"] = @"0";
    
    if (type & NSRemoteNotificationTypeBadge) {
        results[@"pushBadge"] = @"1";
    }
    if (type & NSRemoteNotificationTypeAlert) {
        results[@"pushAlert"] = @"1";
    }
    if (type & NSRemoteNotificationTypeSound) {
        results[@"pushSound"] = @"1";
    }
    if (type != NSRemoteNotificationTypeNone) {
        results[@"enabled"] = @"1";
    }
    
    completion(results);
}

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo {
    NSUserNotification *notification = userInfo[NSApplicationLaunchUserNotificationKey];
    if (notification.isRemote != YES)
        return nil;
    
    return notification.userInfo;
}

@end
