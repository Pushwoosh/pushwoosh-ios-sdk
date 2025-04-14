//
//  PWNotificationManagerCompatiOS10.m
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationManagerCompatiOS10.h"
#import <UserNotifications/UserNotifications.h>
#import "PushwooshFramework.h"
#import "PWUtils.h"

#define SETTING_ENABLED @2

@implementation PWNotificationManagerCompatiOS10

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion {
    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:categories];
    
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        UNAuthorizationOptions options = 0;
        if (settings != nil) {
            if (settings.badgeSetting == UNNotificationSettingEnabled) {
                options |= UNAuthorizationOptionBadge;
            }
            if (settings.alertSetting == UNNotificationSettingEnabled) {
                options |= UNAuthorizationOptionAlert;
            }
            if (settings.soundSetting == UNNotificationSettingEnabled) {
                options |= UNAuthorizationOptionSound;
            }
            if (settings.carPlaySetting == UNNotificationSettingEnabled) {
                options |= UNAuthorizationOptionCarPlay;
            }
            
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            
            if ([settings respondsToSelector:@selector(providesAppNotificationSettings)]) {
                if (settings.providesAppNotificationSettings) {
                    options |= UNAuthorizationOptionProvidesAppNotificationSettings;
                }
                if (settings.criticalAlertSetting) {
                    options |= UNAuthorizationOptionCriticalAlert;
                }
                if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
                    options |= UNAuthorizationOptionProvisional;
                }
            }
        }
        
        if (options == 0) {
            options = UNAuthorizationOptionBadge| UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionCarPlay;
        }
        
        options |= [Pushwoosh sharedInstance].additionalAuthorizationOptions;
        
#pragma clang diagnostic pop
        
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
    }];
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    results[@"pushBadge"] = @"0";
    results[@"pushAlert"] = @"0";
    results[@"pushSound"] = @"0";
    results[@"time_sensitive_notifications"] = @"0";
    results[@"scheduled_summary"] = @"0";
    results[@"enabled"] = @"0";
    
    if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
        results[@"enabled"] = @"1";
    }
    
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings != nil) {
            if (settings.badgeSetting == UNNotificationSettingEnabled) {
                results[@"pushBadge"] = @"1";
            }
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && (settings.alertSetting == UNNotificationSettingEnabled || settings.lockScreenSetting == UNNotificationSettingEnabled || settings.notificationCenterSetting == UNNotificationSettingEnabled)) {
                results[@"pushAlert"] = @"1";
            }
            if (settings.soundSetting == UNNotificationSettingEnabled) {
                results[@"pushSound"] = @"1";
            }
            if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"15.0"]) {
                if ([[settings valueForKey:@"timeSensitiveSetting"] isEqualToNumber:SETTING_ENABLED]) {
                    results[@"time_sensitive_notifications"] = SETTING_ENABLED;
                }
            }
            if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"15.0"]) {
                if ([[settings valueForKey:@"scheduledDeliverySetting"] isEqualToNumber:SETTING_ENABLED]) {
                    results[@"scheduled_summary"] = SETTING_ENABLED;
                }
            }
        }
        
        completion(results);
    }];
}

- (void)clearLocalNotifications {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
}

- (void)didRegisterUserNotificationSettings:(id)notificationSettings {
    // Stub
}

@end
