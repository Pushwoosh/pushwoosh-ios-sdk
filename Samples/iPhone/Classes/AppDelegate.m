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

	// check launch notification (optional)
	NSDictionary *launchNotification = [PushNotificationManager pushManager].launchNotification;
	if (launchNotification) {
		NSError *error;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:launchNotification
														   options:NSJSONWritingPrettyPrinted
															 error:&error];
		
		if (!jsonData) {
			NSLog(@"Got an error: %@", error);
		} else {
			NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
			NSLog(@"Received launch notification with data: %@", jsonString);
		}
	}
	else {
		NSLog(@"No launch notification");
	}

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

- (void)application:(UIApplication *)application
	handleActionWithIdentifier:(NSString *)identifier
		 forRemoteNotification:(NSDictionary *)notification
			 completionHandler:(void (^)())completionHandler {
	if ([identifier isEqualToString:@"ACCEPT_IDENTIFIER"]) {
	}

	// Must be called when finished
	completionHandler();
}

+ (AppDelegate *)sharedDelegate {
	return (AppDelegate *)[UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Attempting to open URL"
													message:[NSString stringWithFormat:
															 @"Url - %@", url]
												   delegate:self cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[alert show];
	
	return YES;
}

@end
