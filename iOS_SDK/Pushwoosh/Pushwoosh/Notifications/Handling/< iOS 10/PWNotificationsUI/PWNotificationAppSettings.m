//
//  PWNotificationAppSettings.m
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/18/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import "PWNotificationAppSettings.h"

NSString *const PWAppAlertStyleKey = @"PWNotificationAlertStyleKey";
NSString *const PWNotificationsDisabledKey = @"PWNotificationsDisabledKey";
NSString *const PWAppSoundsKey = @"PWNotificationsSoundEnabledKey";
NSString *const PWAppNameKey = @"PWNotificationCenterAppNameKey";
NSString *const PWAppIconNameKey = @"PWNotificationCenterAppIconKey";

@implementation PWNotificationAppSettings

+ (instancetype)defaultSettings {
	static PWNotificationAppSettings *instance = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		instance = [PWNotificationAppSettings new];
		instance.alertStyle = PWNotificationAlertStyleBanner;
		instance.soundEnabled = YES;
	});
				  
	return instance;
}
				  
@end
