//
//  PWNotificationManagerCompatwatchOS.m
//  Pushwoosh.watchOS
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationManagerCompatwatchOS.h"
#import <WatchKit/WatchKit.h>
#import <UserNotifications/UserNotifications.h>
#import "PushNotificationManager.h"
#import "PWLog+Internal.h"

@implementation PWNotificationManagerCompatwatchOS

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion {
    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:categories];
    
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        UNAuthorizationOptions options = 0;
        if (settings != nil) {
            if (settings.alertSetting == UNNotificationSettingEnabled) {
                options |= UNAuthorizationOptionAlert;
            }
            if (settings.soundSetting == UNNotificationSettingEnabled) {
                options |= UNAuthorizationOptionSound;
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
            options =  UNAuthorizationOptionAlert | UNAuthorizationOptionSound;
        }
        
        options |= [PushNotificationManager pushManager].additionalAuthorizationOptions;
        
#pragma clang diagnostic pop
        
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
            PWLogInfo(@"NotificationCenter authorization granted: %d", granted);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion();
                }
            });
        }];
    }];
}

- (void)registerForPushNotifications {
    [[WKExtension sharedExtension] registerForRemoteNotifications];
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    
    results[@"pushAlert"] = @"0";
    results[@"pushSound"] = @"0";
    results[@"enabled"] = @"0";
    
    if ([[WKExtension sharedExtension] isRegisteredForRemoteNotifications]) {
        results[@"enabled"] = @"1";
    }
    
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings != nil) {
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && (settings.alertSetting == UNNotificationSettingEnabled || settings.notificationCenterSetting == UNNotificationSettingEnabled)) {
                results[@"pushAlert"] = @"1";
            }
            if (settings.soundSetting == UNNotificationSettingEnabled) {
                results[@"pushSound"] = @"1";
            }
        }
        
        completion(results);
    }];
}

- (void)clearLocalNotifications {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
}

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo {
    //there is no start push dictionary on watchOS
    return nil;
}

@end
