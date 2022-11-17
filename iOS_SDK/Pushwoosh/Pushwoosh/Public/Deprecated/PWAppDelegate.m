//
//  PWAppDelegate.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import "PWAppDelegate.h"
#import "PushNotificationManager.h"

@implementation PWAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if ([UNUserNotificationCenter class]) {
        [UNUserNotificationCenter currentNotificationCenter].delegate = [PushNotificationManager pushManager].notificationCenterDelegate;
    }
    
    [[PushNotificationManager pushManager] sendAppOpen];
    
    return YES;
}

// system push notification registration success callback, delegate to pushManager
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [[PushNotificationManager pushManager] handlePushRegistration:deviceToken];
}

// system push notification registration error callback, delegate to pushManager
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    [[PushNotificationManager pushManager] handlePushRegistrationFailure:error];
}

// system push notifications callback, delegate to pushManager
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    if ([UNUserNotificationCenter class]) {
        completionHandler(UIBackgroundFetchResultNoData);
    } else {
        [[PushNotificationManager pushManager] handlePushReceived:userInfo];
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

@end
