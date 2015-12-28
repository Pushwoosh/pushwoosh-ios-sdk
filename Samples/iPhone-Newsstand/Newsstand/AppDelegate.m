//
//  AppDelegate.m
//  Newsstand
//

#import "AppDelegate.h"
#import "StoreViewController.h"
#import <NewsstandKit/NewsstandKit.h>

@implementation AppDelegate

@synthesize window;
@synthesize store;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// reset the "new" badge when user opens the app
	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

	// IMPORTANT: DEV ONLY: allows more than one new content notification per day (development)
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NKDontThrottleNewsstandContentNotifications"];

	NSLog(@"LAUNCH OPTIONS = %@", launchOptions);

	self.store = [[[StoreViewController alloc] initWithNibName:nil bundle:nil] autorelease];
	navController = [[UINavigationController alloc] initWithRootViewController:store];

	// setup the window
	self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	self.window.backgroundColor = [UIColor whiteColor];
	self.window.rootViewController = navController;
	[self.window makeKeyAndVisible];

	// when the app is relaunched, it is better to restore pending downloading assets as abandoned downloadings will be cancelled
	NKLibrary *nkLib = [NKLibrary sharedLibrary];
	for (NKAssetDownload *asset in [nkLib downloadingAssets]) {
		NSLog(@"Asset to download: %@", asset);
		[asset downloadWithDelegate:store];
	}

	//-----------PUSHWOOSH PART-----------
	// set custom delegate for push handling, in our case - view controller
	PushNotificationManager *pushManager = [PushNotificationManager pushManager];
	pushManager.delegate = self;

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

// Delegate from Pushwoosh SDK
- (void)onPushReceived:(PushNotificationManager *)pushManager
	  withNotification:(NSDictionary *)pushNotification
			   onStart:(BOOL)onStart {
	[self handlePushAndDownloadNewContent:pushNotification];
}

- (void)handlePushAndDownloadNewContent:(NSDictionary *)pushNotification {
	NSDictionary *payload = [[PushNotificationManager pushManager] getApnPayload:pushNotification];

	// check if this is a push notifications for downloading content in background
	if (payload && [payload objectForKey:@"content-available"]) {
		// schedule for issue downloading in background
		// generally the URL for the new content will come in the push notifications payload or you can check the list of available issues on the server.
		// for simplicity we just refreshing Magazine-2
		NKIssue *issue = [[NKLibrary sharedLibrary] issueWithName:@"Magazine-2"];
		if (issue) {
			// let NKAssetDownload class to download the new issue
			NSURL *downloadURL = [NSURL URLWithString:@"http://www.pushwoosh.com/data/magazine-2.pdf"];
			NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
			NKAssetDownload *assetDownload = [issue addAssetWithRequest:request];
			[assetDownload downloadWithDelegate:store];

			int index = [store.publisher getIssueIndexByName:@"Magazine-2"];

			// store the index of the issue as a custom data. we will use it later to display connection progress
			[assetDownload
				setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:index], @"Index", nil]];
		}
	}
}

- (void)dealloc {
	[window release];
	[super dealloc];
}

@end
