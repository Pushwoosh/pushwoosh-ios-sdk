//
//  PushNotificationsApp
//
//  (c) Pushwoosh 2020
//

#import "AppDelegate.h"
#import <Pushwoosh/Pushwoosh.h>

@interface AppDelegate () <PWMessagingDelegate>

@end

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

	// set custom delegate for push handling, in our case AppDelegate
	[Pushwoosh sharedInstance].delegate = self;

	//register for push notifications!
	[[Pushwoosh sharedInstance] registerForPushNotifications];

	return YES;
}

//handle token received from APNS
- (void)application:(UIApplication *)application
	didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	[[Pushwoosh sharedInstance] handlePushRegistration:deviceToken];
}

//handle token receiving error
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	[[Pushwoosh sharedInstance] handlePushRegistrationFailure:error];
}

//this is for iOS < 10 and for silent push notifications
- (void)application:(UIApplication *)application
	didReceiveRemoteNotification:(NSDictionary *)userInfo
		  fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
		[[Pushwoosh sharedInstance] handlePushReceived:userInfo];
		completionHandler(UIBackgroundFetchResultNoData);
}

//this event is fired when the push gets received
- (void)pushwoosh:(Pushwoosh *)pushwoosh onMessageReceived:(PWMessage *)message {
    NSLog(@"onMessageReceived: %@", message.payload);
}

//this event is fired when user taps the notification
- (void)pushwoosh:(Pushwoosh *)pushwoosh onMessageOpened:(PWMessage *)message {
    NSLog(@"onMessageOpened: %@", message.payload);
}

@end
