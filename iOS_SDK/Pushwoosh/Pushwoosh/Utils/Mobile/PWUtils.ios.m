//
//  PWUtils.m
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWUtils.ios.h"
#import "PWButtonExt.h"
#import "PWUtils+Internal.h"
#import "PWReachability.h"
#import "PWPreferences.h"
#import "Pushwoosh+Internal.h"
#import "PushNotificationManager.h"

@implementation PWUtils

+ (NSString *)deviceName {
	return [[UIDevice currentDevice] name];
}

+ (NSString *)systemVersion {
	return [[UIDevice currentDevice] systemVersion];
}

+ (BOOL)isSystemVersionGreaterOrEqualTo:(NSString *)systemVersion {
    return ([[[UIDevice currentDevice] systemVersion] compare:systemVersion options:NSNumericSearch] != NSOrderedAscending);
}

+ (void)applicationOpenURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

+ (UIButton *)webViewCloseButton {
	CGSize buttonSize = CGSizeMake(35, 35);
	UIGraphicsBeginImageContextWithOptions(buttonSize, NO, 0);

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(context, 2.6f);
	CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);

	CGFloat inset = 0.26 * buttonSize.width;

	CGContextMoveToPoint(context, inset, inset);
	CGContextAddLineToPoint(context, buttonSize.width - inset, buttonSize.height - inset);
	CGContextMoveToPoint(context, inset, buttonSize.height - inset);
	CGContextAddLineToPoint(context, buttonSize.width - inset, inset);

	CGContextStrokePath(context);

	UIImage *crossImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	PWButtonExt *closeButton = [PWButtonExt buttonWithType:UIButtonTypeSystem];
	closeButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    if ([self isIphoneX]) {
        closeButton.frame = CGRectMake(5, 40, buttonSize.width, buttonSize.height);
    } else {
        closeButton.frame = CGRectMake(5, 20, buttonSize.width, buttonSize.height);
    }
	closeButton.layer.cornerRadius = closeButton.frame.size.width / 2.0;
	closeButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
	closeButton.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);

	[closeButton setBackgroundImage:crossImage forState:UIControlStateNormal];

	return closeButton;
}

+ (BOOL)isIphoneX {
    if ([[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        if ([[UIScreen mainScreen] bounds].size.height > 736) {
            return  YES;
        }
    }
    return  NO;
}

+ (NSString *)generateIdentifier {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIViewController *rootController = [self findRootViewController];
    
    if (rootController) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [rootController presentViewController:alertController animated:YES completion:nil];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
    }
}

+ (UIViewController*)findRootViewController {
    UIApplication *sharedApplication = [UIApplication valueForKey:@"sharedApplication"];
    UIViewController *controller = sharedApplication.keyWindow.rootViewController;
    
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

+ (BOOL)isSimulator {
	NSString *deviceName = [[UIDevice currentDevice].model lowercaseString];
	if ([deviceName rangeOfString:@"simulator"].location != NSNotFound)
		return true;
	
	return false;
}

#pragma mark - Background

+ (NSNumber *)startBackgroundTask {
    __block NSInteger regionMonitoringBGTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:regionMonitoringBGTask];
        regionMonitoringBGTask = UIBackgroundTaskInvalid;
    }];
    
    PWLogDebug(@"started task: %ld", (long)regionMonitoringBGTask);
    return @(regionMonitoringBGTask);
}

+ (void)stopBackgroundTask:(NSNumber *)taskId {
    if (!taskId || [taskId integerValue] == UIBackgroundTaskInvalid) {
        PWLogWarn(@"Empty task id to stop!");
        return;
    }
    
    PWLogDebug(@"stopping task: %ld", (long)[taskId integerValue]);
    [[UIApplication sharedApplication] endBackgroundTask:[taskId integerValue]];
}

+ (BOOL)handleURL:(NSURL *)url {
    if ([[url scheme] hasPrefix:@"pushwoosh-"]) {
        if ([[url host] isEqualToString:@"createTestDevice"]) {
                dispatch_block_t registerTestDeviceBlock = ^{
                    [[Pushwoosh sharedInstance].pushNotificationManager registerTestDevice];
                };
                
                if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), registerTestDeviceBlock);
                }
                else {
                    registerTestDeviceBlock();
                }
        } else {
            PWLogWarn(@"Unrecognized pushwoosh command: %@", [url host]);
        }
        return YES;
    }
    return NO;
}

+ (NSInteger)getStatusesMask {
    NSDictionary *permissionsStatusDict = [PushNotificationManager getRemoteNotificationStatus];
    
    BOOL soundsEnabled = [permissionsStatusDict[@"pushSound"] boolValue];
    BOOL badgesEnabled = [permissionsStatusDict[@"pushBadge"] boolValue];
    BOOL alertEnabled = [permissionsStatusDict[@"pushAlert"] boolValue];
    
    NSInteger statusesMask = 0;
    
    if (badgesEnabled) {
        statusesMask |= 1;
    }
    
    if (soundsEnabled) {
        statusesMask |= 1 << 1;
    }
    
    if (alertEnabled) {
        statusesMask |= 1 << 2;
    }
        
    return statusesMask;
}

@end
