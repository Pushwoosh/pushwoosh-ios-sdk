//
//  PWPlatformModule.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPlatformModule.h"

#if TARGET_OS_IOS
#import "PWNotificationManagerCompatUserNotifications.h"
#import "PWNotificationCategoryBuilderUserNotifications.h"
#elif TARGET_OS_TV
#import "PWNotificationManagerCompattvOS.h"
#elif TARGET_OS_OSX
#import "PWNotificationManagerCompatmacOS.h"
#endif

#import <UserNotifications/UNUserNotificationCenter.h>

@implementation PWPlatformModule

- (instancetype)init {
	self = [super init];
	if (self) {

#if TARGET_OS_IOS
		if ([UNUserNotificationCenter class]) {
			_notificationManagerCompat = [PWNotificationManagerCompatUserNotifications new];
		}
		else {
			_notificationManagerCompat = [PWNotificationManagerCompat new];
		}
#elif TARGET_OS_TV
		_notificationManagerCompat = [PWNotificationManagerCompattvOS new];
#elif TARGET_OS_OSX
		_notificationManagerCompat = [PWNotificationManagerCompatmacOS new];
#endif

#if TARGET_OS_IOS
		if ([UNUserNotificationCenter class]) {
			_NotificationCategoryBuilder = [PWNotificationCategoryBuilderUserNotifications class];
		}
		else {
			_NotificationCategoryBuilder = [PWNotificationCategoryBuilder class];
		}
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
