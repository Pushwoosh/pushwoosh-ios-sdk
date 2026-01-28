//
//  PWPushNotificationsManager.m
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationsManager.h"
#import "PWPushNotificationsManager+Internal.h"
#import "PWPushRuntime.h"
#import "PWInteractivePush.h"
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWUtils.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWInboxBridge.h>
#import "PWUserNotificationCenterDelegate.h"

@interface PWPushNotificationsManager ()

@property (nonatomic) BOOL fromForeground;

@end

@implementation PWPushNotificationsManager

- (instancetype)init {
	if (self = [super init]) {
        //need to track app is waking from background or just become active. if app woke from background [UIApplication sharedApplication].applicationState == UIApplicationStateInactive
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	return self;
}

- (void)didFinishLaunching:(NSNotification *)notification {
    [self willForeground:notification];
#if TARGET_OS_IOS || TARGET_OS_WATCH
    [PWManagerBridge shared].launchNotification = notification.userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
#endif
}

- (void)willForeground:(NSNotification *)notifiaction {
    _fromForeground = YES;
}

- (void)didBecomeActive:(NSNotification *)notifiaction {
    _fromForeground = NO;
}

- (void)internalRegisterForPushNotifications {
    [PWUtils getAPSProductionStatus:YES];
    
    [PWInteractivePush getCategoriesWithCompletion:^(NSSet *categories) {
        [self.notificationManagerCompat registerUserNotifications:categories completion:^{
            [self.notificationManagerCompat registerForPushNotifications];
        }];
    }];
}

- (BOOL)preHandlePushReceived:(NSDictionary *)userInfo onStart:(BOOL)onStart {
	return NO;
}

- (BOOL)dispatchInboxPushIfNeeded:(NSDictionary *)userInfo {
    if ([[PWManagerBridge shared].inboxBridge isInboxPushNotification:userInfo]) {
        [[PWManagerBridge shared].inboxBridge addInboxMessageFromPushNotification:userInfo];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)dispatchActionInboxPushIfNeeded:(NSDictionary *)userInfo {
    if ([[PWManagerBridge shared].inboxBridge isInboxPushNotification:userInfo]) {
        [[PWManagerBridge shared].inboxBridge actionInboxMessageFromPushNotification:userInfo];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isAppInBackground {
    return [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive;
}

- (BOOL)showForegroundAlert:(NSDictionary *)userInfo onStart:(BOOL)onStart {
	// Legacy in-app banner removed. Foreground notifications are now handled by UNUserNotificationCenter.
	return NO;
}

@end
