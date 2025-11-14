//
//  PWNotificationManagerCompattvOS.m
//  Pushwoosh
//
//  Created by André Kis on 08.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#if TARGET_OS_TV

#import "PWNotificationManagerCompattvOS.h"
#import <UserNotifications/UserNotifications.h>

@implementation PWNotificationManagerCompattvOS

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion {
    // Note: setNotificationCategories is API_UNAVAILABLE(tvos)
    // tvOS doesn't support notification categories

    UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;

    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
        [PushwooshLog pushwooshLog:PW_LL_INFO
                         className:self
                           message:[NSString stringWithFormat:@"NotificationCenter authorization granted: %d", granted]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAuthorizationStatusUpdated object:nil];

            if (completion) {
                completion();
            }
        });
    }];
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    results[@"pushBadge"] = @"0";
    results[@"pushAlert"] = @"0";
    results[@"pushSound"] = @"0";
    results[@"enabled"] = @"0";

    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings != nil) {
            // On tvOS, individual settings (alertSetting, soundSetting, badgeSetting) are API_UNAVAILABLE
            // We only check authorizationStatus
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                results[@"enabled"] = @"1";
                results[@"pushBadge"] = @"1";
                results[@"pushAlert"] = @"1";
                results[@"pushSound"] = @"1";
            }
        }

        completion(results);
    }];
}

- (void)clearLocalNotifications {
    // Note: removeAllDeliveredNotifications is API_UNAVAILABLE(tvos)
    // tvOS doesn't support clearing delivered notifications
}

- (void)didRegisterUserNotificationSettings:(id)notificationSettings {
    // Stub
}

@end

#endif
