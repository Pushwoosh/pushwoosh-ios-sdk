//
//  PWPushRuntime.m
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushRuntime.mac.h"
#import "PWUtils.h"
#import "PushNotificationManager.h"
#import "PWConfig.h"

#import <objc/runtime.h>

@interface NSApplication (SupressWarnings)

- (void)pw_applicationDidFinishLaunching:(NSNotification *)notification;
- (void)application:(NSApplication *)application pw_didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken;
- (void)application:(NSApplication *)application pw_didFailToRegisterForRemoteNotificationsWithError:(NSError *)err;
- (void)application:(NSApplication *)application pw_didReceiveRemoteNotification:(NSDictionary *)userInfo;

@end

@interface NSApplication (InternalPushRuntime)

- (NSObject<PushNotificationDelegate> *)getPushwooshDelegate;
- (BOOL)pushwooshUseRuntimeMagic;  //use runtime to handle default push notifications callbacks (used in plugins)

@end

@implementation NSApplication (Pushwoosh)

void dynamicDidFinishLaunching(id self, SEL _cmd, id aNotification) {
	BOOL result = YES;

	if ([self respondsToSelector:@selector(pw_applicationDidFinishLaunching:)]) {
		[self pw_applicationDidFinishLaunching:aNotification];
		result = YES;
	}

	if (![PushNotificationManager pushManager].delegate) {
		if ([[NSApplication sharedApplication] respondsToSelector:@selector(getPushwooshDelegate)]) {
			[PushNotificationManager pushManager].delegate = [[NSApplication sharedApplication] getPushwooshDelegate];
		} else {
			[PushNotificationManager pushManager].delegate = (NSObject<PushNotificationDelegate> *)self;
		}
	}

	//this function will also handle UIApplicationLaunchOptionsLocationKey
	[[PushNotificationManager pushManager] handlePushReceived:[aNotification userInfo]];
	[[PushNotificationManager pushManager] sendAppOpen];
}

void dynamicDidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, id application, id devToken) {
	if ([self respondsToSelector:@selector(application:pw_didRegisterForRemoteNotificationsWithDeviceToken:)]) {
		[self application:application pw_didRegisterForRemoteNotificationsWithDeviceToken:devToken];
	}

	[[PushNotificationManager pushManager] handlePushRegistration:devToken];
}

void dynamicDidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, id application, id error) {
	if ([self respondsToSelector:@selector(application:pw_didFailToRegisterForRemoteNotificationsWithError:)]) {
		[self application:application pw_didFailToRegisterForRemoteNotificationsWithError:error];
	}

	PWLogError(@"Error registering for push notifications. Error: %@", error);

	[[PushNotificationManager pushManager] handlePushRegistrationFailure:error];
}

void dynamicDidReceiveRemoteNotification(id self, SEL _cmd, id application, id userInfo) {
	if ([self respondsToSelector:@selector(application:pw_didReceiveRemoteNotification:)]) {
		[self application:application pw_didReceiveRemoteNotification:userInfo];
	}

	[[PushNotificationManager pushManager] handlePushReceived:userInfo];
}

- (void)pw_setDelegate:(id<NSApplicationDelegate>)delegate {
	BOOL useRuntime = [PWConfig config].useRuntime;

	//override runtime functions only if requested (used in plugins or by user decision)

	if (![[NSApplication sharedApplication] respondsToSelector:@selector(pushwooshUseRuntimeMagic)] && !useRuntime) {
		//auto test check
		[self pw_setDelegate:delegate];
		return;
	}

	static Class delegateClass = nil;

	//do not swizzle the same class twice
	if (delegateClass == [delegate class]) {
		[self pw_setDelegate:delegate];
		return;
	}

	delegateClass = [delegate class];

	[PWUtils swizzle:delegateClass
		  fromSelector:@selector(applicationDidFinishLaunching:)
			toSelector:@selector(pw_applicationDidFinishLaunching:)
		implementation:(IMP)dynamicDidFinishLaunching
		  typeEncoding:"v@:::"];

	[PWUtils swizzle:delegateClass
		  fromSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
			toSelector:@selector(application:pw_didRegisterForRemoteNotificationsWithDeviceToken:)
		implementation:(IMP)dynamicDidRegisterForRemoteNotificationsWithDeviceToken
		  typeEncoding:"v@:::"];

	[PWUtils swizzle:delegateClass
		  fromSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
			toSelector:@selector(application:pw_didFailToRegisterForRemoteNotificationsWithError:)
		implementation:(IMP)dynamicDidFailToRegisterForRemoteNotificationsWithError
		  typeEncoding:"v@:::"];

	[PWUtils swizzle:delegateClass
		  fromSelector:@selector(application:didReceiveRemoteNotification:)
			toSelector:@selector(application:pw_didReceiveRemoteNotification:)
		implementation:(IMP)dynamicDidReceiveRemoteNotification
		  typeEncoding:"v@:::"];

	[self pw_setDelegate:delegate];
}

+ (void)load {
	method_exchangeImplementations(class_getInstanceMethod(self, @selector(setDelegate:)), class_getInstanceMethod(self, @selector(pw_setDelegate:)));

	PWLogInfo(@"Pushwoosh: Initializing application runtime");
}

@end
