//
//  PWPlatformModule.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPlatformModule.h"

#if TARGET_OS_IOS
#import "PWNotificationManagerCompatiOS8.h"
#import "PWNotificationManagerCompatiOS10.h"
#import "PWNotificationCategoryBuilderiOS8.h"
#import "PWNotificationCategoryBuilderiOS9.h"
#import "PWNotificationCategoryBuilderiOS10.h"
#elif TARGET_OS_OSX
#import "PWNotificationManagerCompatmacOS.h"
#elif TARGET_OS_WATCH
#import "PWNotificationManagerCompatwatchOS.h"
#import "PWNotificationCategoryBuilderwatchOS.h"
#endif

#import <UserNotifications/UNUserNotificationCenter.h>

@implementation PWPlatformModule

- (instancetype)init {
	self = [super init];
	if (self) {
        
#if TARGET_OS_IOS
		if ([UNUserNotificationCenter class]) {
			_notificationManagerCompat = [PWNotificationManagerCompatiOS10 new];
		}
		else if ([UIApplication instancesRespondToSelector:@selector(registerForRemoteNotifications)]) {
			_notificationManagerCompat = [PWNotificationManagerCompatiOS8 new];
		}
		else {
			_notificationManagerCompat = [PWNotificationManagerCompat new];
		}
#elif TARGET_OS_OSX
		_notificationManagerCompat = [PWNotificationManagerCompatmacOS new];
#elif TARGET_OS_WATCH
        _notificationManagerCompat = [PWNotificationManagerCompatwatchOS new];
#endif
		
#if TARGET_OS_IOS
		if ([UNUserNotificationCenter class]) {
			_NotificationCategoryBuilder = [PWNotificationCategoryBuilderiOS10 class];
		}
		else if ([UIUserNotificationAction instancesRespondToSelector:@selector(behavior)]) {
			_NotificationCategoryBuilder = [PWNotificationCategoryBuilderiOS9 class];
		}
		else if ([UIApplication instancesRespondToSelector:@selector(registerForRemoteNotifications)]) {
			_NotificationCategoryBuilder = [PWNotificationCategoryBuilderiOS8 class];
		}
		else {
			_NotificationCategoryBuilder = [PWNotificationCategoryBuilder class];
		}
#elif TARGET_OS_WATCH
        _NotificationCategoryBuilder = [PWNotificationCategoryBuilderwatchOS class];
#endif
	}
	return self;
}

+ (PWPlatformModule*)module {
	static PWPlatformModule *instance = nil;
	static dispatch_once_t pred;
	
	dispatch_once(&pred, ^{
		instance = [PWPlatformModule new];
	});
	
	return instance;
}

- (void)inject:(id)object {
	if ([object respondsToSelector:@selector(setNotificationManagerCompat:)]) {
		[object setNotificationManagerCompat:self.notificationManagerCompat];
	}
}

- (PWNotificationCategoryBuilder*)createCategoryBuilder {
	return [self.NotificationCategoryBuilder new];
}

@end
