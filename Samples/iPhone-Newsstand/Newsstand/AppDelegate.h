//
//  AppDelegate.h
//  Newsstand
//

#import <UIKit/UIKit.h>
#import <Pushwoosh/PushNotificationManager.h>

@class StoreViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, PushNotificationDelegate> {
	UINavigationController *navController;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) StoreViewController *store;

@end
