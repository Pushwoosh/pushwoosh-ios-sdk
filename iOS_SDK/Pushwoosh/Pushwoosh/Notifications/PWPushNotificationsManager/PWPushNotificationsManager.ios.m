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
#import "PWNotification.h"
#import "PWNotificationCenter.h"
#import "PWNotificationAppSettings.h"
#import "PWConfig.h"
#import "PWUtils.h"
#import "Pushwoosh+Internal.h"
#import "PWInbox+Internal.h"
#import "PWUserNotificationCenterDelegate.h"
#import "PWGDPRManager.h"

@interface PWPushNotificationsManager ()

@property (nonatomic) BOOL fromForeground;

@end

@implementation PWPushNotificationsManager

- (instancetype)init {
	if (self = [super init]) {
		[self setUpInAppAlerts];
        //need to track app is waking from background or just become active. if app woke from background [UIApplication sharedApplication].applicationState == UIApplicationStateInactive
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	return self;
}

- (void)didFinishLaunching:(NSNotification *)notification {
    [self willForeground:notification];
    [Pushwoosh sharedInstance].launchNotification = notification.userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
}

- (void)willForeground:(NSNotification *)notifiaction {
    _fromForeground = YES;
}

- (void)didBecomeActive:(NSNotification *)notifiaction {
    _fromForeground = NO;
}

- (void)setUpInAppAlerts {
	//get app icon for in-app alert module
    UIImage *appIcon = [UIImage imageNamed:[[[NSBundle mainBundle] infoDictionary][@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"] firstObject]];

	if (!appIcon) {
		appIcon = [UIImage imageNamed:[[[NSBundle mainBundle] infoDictionary][@"CFBundleIconFiles"] firstObject]];
	}

	//initialize in-app alert module
	[[PWNotificationCenter defaultCenter] registerApplicationWithIdentifier:@"com.pushwoosh.app" name:[PWPreferences preferences].appName icon:appIcon defaultSettings:[PWNotificationAppSettings defaultSettings]];


	//set up alert type
	PWNotificationAppSettings *inappAlertSettings = [PWNotificationAppSettings new];
	inappAlertSettings.alertStyle = [PWConfig config].alertStyle;

	inappAlertSettings.soundEnabled = YES;
	[[PWNotificationCenter defaultCenter] setSettings:inappAlertSettings enabled:YES forAppIdentifier:@"com.pushwoosh.app"];
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
    if ([PWInbox isInboxPushNotification:userInfo]) {
        [PWInbox addInboxMessageFromPushNotification:userInfo];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)dispatchActionInboxPushIfNeeded:(NSDictionary *)userInfo {
    if ([PWInbox isInboxPushNotification:userInfo]) {
        [PWInbox actionInboxMessageFromPushNotification:userInfo];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isAppInBackground {
    return [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive;
}

// Returns YES if foreground alert is shown
- (BOOL)showForegroundAlert:(NSDictionary *)userInfo onStart:(BOOL)onStart {
	BOOL needToShowAlert = [PushNotificationManager pushManager].showPushnotificationAlert;
	if ([self isAppInBackground]) {
		needToShowAlert = NO;  //we cannot display alerts in background anyway
	}

	NSDictionary *pushDict = userInfo[@"aps"];
	id alertMsg = pushDict[@"alert"];
	
	if ([alertMsg isKindOfClass:[NSDictionary class]]) {
		alertMsg = alertMsg[@"body"];
	}

	bool msgIsString = YES;
	if (![alertMsg isKindOfClass:[NSString class]])
		msgIsString = NO;

	//the app is running, display alert only
	if (!onStart && needToShowAlert && msgIsString) {
		PWNotification *notification = [PWNotification notificationWithMessage:alertMsg];
		notification.title = [PushNotificationManager pushManager].appName;
		notification.soundName = pushDict[@"sound"];
		notification.defaultAction = [PWNotificationAction actionWithTitle:@"View" handler:^(PWNotificationAction *action) {
			[self handlePushAccepted:userInfo onStart:onStart];
		}];

		[[PWNotificationCenter defaultCenter] presentNotification:notification forApplicationIdentifier:@"com.pushwoosh.app"];
		return YES;
	}

	return NO;
}

@end
