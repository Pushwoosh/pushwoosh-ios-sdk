//
//  PushNotificationsApp
//
//  (c) Pushwoosh 2014
//

#import "AppDelegate.h"
#import <Pushwoosh/PushNotificationManager.h>

@implementation AppDelegate

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	// Override point for customization after application launch.
	self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];

	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];

	//-----------PUSHWOOSH PART-----------

	// set custom delegate for push handling, in our case - view controller
	[PushNotificationManager pushManager].delegate = self.viewController;

	// handling push on app start
	[[PushNotificationManager pushManager] handlePushReceived:launchOptions];

	// make sure we count app open in Pushwoosh stats
	[[PushNotificationManager pushManager] sendAppOpen];

	// register for push notifications!
	[[PushNotificationManager pushManager] registerForPushNotifications];

	return YES;
}

// system push notification registration success callback, delegate to pushManager
- (void)application:(UIApplication *)application
	didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[[PushNotificationManager pushManager] handlePushRegistration:deviceToken];
}

// system push notification registration error callback, delegate to pushManager
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	[[PushNotificationManager pushManager] handlePushRegistrationFailure:error];
}

// system push notifications callback, delegate to pushManager
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	[[PushNotificationManager pushManager] handlePushReceived:userInfo];
}

// silent push handling for applications with the "remote-notification" background mode
- (void)application:(UIApplication *)application
	didReceiveRemoteNotification:(NSDictionary *)userInfo
		  fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	NSDictionary *pushDict = [userInfo objectForKey:@"aps"];
	BOOL isSilentPush = [[pushDict objectForKey:@"content-available"] boolValue];

	if (isSilentPush) {
		NSLog(@"Silent push notification:%@", userInfo);

		//load content here

		// must call completionHandler
		completionHandler(UIBackgroundFetchResultNewData);
	} else {
		[[PushNotificationManager pushManager] handlePushReceived:userInfo];

		// must call completionHandler
		completionHandler(UIBackgroundFetchResultNoData);
	}
}

+ (AppDelegate *)sharedDelegate {
	return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
													message:notification.alertBody
												   delegate:nil
										  cancelButtonTitle:@"OK"
										  otherButtonTitles:nil];
	[alert show];
}

@end
