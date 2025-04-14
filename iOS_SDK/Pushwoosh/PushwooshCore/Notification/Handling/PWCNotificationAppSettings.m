//
//  PWCNotificationAppSettings.m
//  PushwooshCore
//
//  Created by André Kis on 10.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWCNotificationAppSettings.h"

NSString *const PWAppAlertStyleKey = @"PWNotificationAlertStyleKey";
NSString *const PWNotificationsDisabledKey = @"PWNotificationsDisabledKey";
NSString *const PWAppSoundsKey = @"PWNotificationsSoundEnabledKey";
NSString *const PWAppNameKey = @"PWNotificationCenterAppNameKey";
NSString *const PWAppIconNameKey = @"PWNotificationCenterAppIconKey";

@implementation PWCNotificationAppSettings

+ (instancetype)defaultSettings {
    static PWCNotificationAppSettings *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [PWCNotificationAppSettings new];
        instance.soundEnabled = YES;
    });
                  
    return instance;
}
                  
@end
