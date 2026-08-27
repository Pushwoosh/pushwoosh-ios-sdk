//
//  PWUtils.ios.m
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
#import "PWConfig.h"
#import "PWUniversalLinkResolver.h"
#import <PushwooshCore/PWManagerBridge.h>
#import "PWPushNotificationsManager.h"

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
    NSString *scheme = url.scheme.lowercaseString;

    if (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"]) {
        [self openURLReportingOutcome:url];
        return;
    }

    [PWUniversalLinkResolver resolveURL:url completion:^(PWUniversalLinkVerdict verdict) {
        [self routeURL:url verdict:verdict];
    }];
}

+ (void)routeURL:(NSURL *)url verdict:(PWUniversalLinkVerdict)verdict {
    if (verdict == PWUniversalLinkVerdictNoMatch) {
        [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"Universal link: host %@ not associated with this app (AASA) -> opening in Safari", url.host]];
        [self openURLInSafari:url];
        return;
    }
    if (verdict == PWUniversalLinkVerdictMatch) {
        [self deliverActivityForURL:url logPrefix:@"Universal link: AASA match" logLevel:PW_LL_INFO];
        return;
    }
    /// Unknown means the domain could not be reached, not that the app claims it. Handing the
    /// activity over on a guess loses the link outright: `scene:continueUserActivity:` returns
    /// void, so a SwiftUI app whose router ignores the URL leaves the user on the screen they
    /// were on, with no navigation, no browser and no error. Safari is the outcome the user can
    /// still act on, so it wins unless the integrator asked us to never open it.
    if ([[PWConfig config] disableUrlFallback]) {
        [self deliverActivityForURL:url
                          logPrefix:@"Universal link: AASA verdict unknown, Pushwoosh_DISABLE_URL_FALLBACK is set"
                           logLevel:PW_LL_WARN];
        return;
    }
    [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"Universal link: AASA verdict unknown for host %@ -> opening in Safari", url.host]];
    [self openURLInSafari:url];
}

+ (NSUserActivity *)browsingActivityWithURL:(NSURL *)url {
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    userActivity.webpageURL = url;
    return userActivity;
}

+ (UIScene *)sceneForUniversalLinkDelivery API_AVAILABLE(ios(13.0)) {
    NSArray<NSNumber *> *activationStatePriority = @[@(UISceneActivationStateForegroundActive),
                                                     @(UISceneActivationStateForegroundInactive),
                                                     @(UISceneActivationStateBackground),
                                                     @(UISceneActivationStateUnattached)];
    for (NSNumber *activationState in activationStatePriority) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]
                && scene.activationState == activationState.integerValue
                && [scene.delegate respondsToSelector:@selector(scene:continueUserActivity:)]) {
                return scene;
            }
        }
    }
    return nil;
}

+ (BOOL)appDelegateRespondsToContinueUserActivity {
    return [[UIApplication sharedApplication].delegate respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)];
}

+ (BOOL)deliverActivityToAppDelegate:(NSUserActivity *)userActivity {
    return [[UIApplication sharedApplication].delegate application:[UIApplication sharedApplication]
                                              continueUserActivity:userActivity
                                                restorationHandler:^(NSArray<id<UIUserActivityRestoring>> * _Nullable restorableObjects) {}];
}

+ (void)deliverActivityForURL:(NSURL *)url logPrefix:(NSString *)logPrefix logLevel:(PUSHWOOSH_LOG_LEVEL)logLevel {
    NSUserActivity *userActivity = [self browsingActivityWithURL:url];

    if (@available(iOS 13.0, *)) {
        UIScene *scene = [self sceneForUniversalLinkDelivery];
        if (scene) {
            [scene.delegate scene:scene continueUserActivity:userActivity];
            [PushwooshLog pushwooshLog:logLevel className:self message:[NSString stringWithFormat:@"%@ -> delivered to scene delegate %@ (scene state %ld); outcome is unobservable on the scene path", logPrefix, NSStringFromClass([scene.delegate class]), (long)scene.activationState]];
            return;
        }
    }

    if ([self appDelegateRespondsToContinueUserActivity]) {
        if ([self deliverActivityToAppDelegate:userActivity]) {
            [PushwooshLog pushwooshLog:logLevel className:self message:[NSString stringWithFormat:@"%@ -> app delegate handled the activity", logPrefix]];
            return;
        }
        if ([[PWConfig config] disableUrlFallback]) {
            [PushwooshLog pushwooshLog:logLevel className:self message:[NSString stringWithFormat:@"%@ -> app delegate returned NO, Pushwoosh_DISABLE_URL_FALLBACK is set -> not opening a link to %@", logPrefix, url.host]];
            return;
        }
        [PushwooshLog pushwooshLog:logLevel className:self message:[NSString stringWithFormat:@"%@ -> app delegate returned NO -> opening in Safari", logPrefix]];
        [self openURLInSafari:url];
        return;
    }

    [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"%@ -> neither scene nor app delegate implements continueUserActivity -> opening in Safari", logPrefix]];
    [self openURLInSafari:url];
}

+ (void)openURLInSafari:(NSURL *)url {
    [self openURLReportingOutcome:url];
}

+ (void)openURLReportingOutcome:(NSURL *)url {
    NSString *loggableURL = [self loggableURLDescription:url];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Opened remote url: %@", loggableURL]];
            return;
        }
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Can't open remote url: %@", loggableURL]];
    }];
}

#if TARGET_OS_IOS

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

#endif

+ (BOOL)isIphoneX {
    if ([[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        if ([[UIScreen mainScreen] bounds].size.height > 736) {
            return  YES;
        }
    }
    return  NO;
}

+ (NSString *)generateIdentifier {
    NSString *vendorId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if ([vendorId isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        return [[NSUUID new] UUIDString];
    }
    return vendorId;
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIViewController *rootController = [self findRootViewController];

    if (rootController) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [rootController presentViewController:alertController animated:YES completion:nil];
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

#pragma mark - Background

+ (NSNumber *)startBackgroundTask {
    __block NSInteger regionMonitoringBGTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:regionMonitoringBGTask];
        regionMonitoringBGTask = UIBackgroundTaskInvalid;
    }];
    
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"started task: %ld", (long)regionMonitoringBGTask]];
    return @(regionMonitoringBGTask);
}

+ (void)stopBackgroundTask:(NSNumber *)taskId {
    if (!taskId || [taskId integerValue] == UIBackgroundTaskInvalid) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Empty task id to stop!"];
        return;
    }
    
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"stopping task: %ld", (long)[taskId integerValue]]];
    [[UIApplication sharedApplication] endBackgroundTask:[taskId integerValue]];
}

+ (BOOL)handleURL:(NSURL *)url {
    if ([[url scheme] hasPrefix:@"pushwoosh-"]) {
        if ([[url host] isEqualToString:@"createTestDevice"]) {
                dispatch_block_t registerTestDeviceBlock = ^{
                    [[PWManagerBridge shared].pushNotificationManager registerTestDevice];
                };
                
                if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), registerTestDeviceBlock);
                }
                else {
                    registerTestDeviceBlock();
                }
        } else {
            [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:[NSString stringWithFormat:@"Unrecognized pushwoosh command: %@", [url host]]];
        }
        return YES;
    }
    return NO;
}

+ (NSInteger)getStatusesMask {
    NSDictionary *permissionsStatusDict = [PWManagerBridge getRemoteNotificationStatus];
    
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

+ (NSDictionary *)embeddedProvisioningProfileEntitlements {
    return [self embeddedProvisioningProfileEntitlementsInBundle:[NSBundle mainBundle]];
}

+ (NSDictionary *)embeddedProvisioningProfileEntitlementsInBundle:(NSBundle *)bundle {
    NSString *provisioningPath = [bundle pathForResource:@"embedded.mobileprovision" ofType:nil];
    if (!provisioningPath) {
        return nil;
    }
    NSString *contents = [NSString stringWithContentsOfFile:provisioningPath encoding:NSASCIIStringEncoding error:nil];
    if (!contents) {
        return nil;
    }
    NSRange start = [contents rangeOfString:@"<?xml"];
    NSRange end = [contents rangeOfString:@"</plist>"];
    if (start.location == NSNotFound || end.location == NSNotFound || end.location < start.location) {
        return nil;
    }
    start.length = end.location + end.length - start.location;
    NSData *profileData = [[contents substringWithRange:start] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *profile = [NSPropertyListSerialization propertyListWithData:profileData
                                                                      options:NSPropertyListImmutable
                                                                       format:nil
                                                                        error:nil];
    NSDictionary *entitlements = profile[@"Entitlements"];
    return [entitlements isKindOfClass:[NSDictionary class]] ? entitlements : nil;
}

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert {
#if TARGET_OS_SIMULATOR
    return NO;
#endif

    NSString *provisioningPath = [[NSBundle mainBundle] pathForResource:@"embedded.mobileprovision" ofType:nil];
    if (!provisioningPath)
        return YES;

    NSDictionary *entitlements = [self embeddedProvisioningProfileEntitlements];
    NSString *apsGateway = entitlements[@"aps-environment"];
    if (!apsGateway && canShowAlert) {
        [self showAlertWithTitle:@"Pushwoosh Error" message:@"Your provisioning profile does not have APS entry. Please make your profile push compatible."];
    }

    if ([apsGateway isKindOfClass:[NSString class]] && [apsGateway isEqualToString:@"development"])
        return NO;

    return YES;
}

+ (PWReachability *)reachability {
    return [PWReachability reachabilityForInternetConnection];
}

@end
