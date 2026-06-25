//
//  PWUtils.h
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWUtils.common.h>

@interface PWUtils : PWUtilsCommon

/// Returns the Entitlements dictionary of the embedded provisioning profile,
/// or nil when the profile is missing (App Store build) or cannot be parsed.
+ (NSDictionary *)embeddedProvisioningProfileEntitlements;

/// Same as `embeddedProvisioningProfileEntitlements`, but reads the profile from the given bundle.
+ (NSDictionary *)embeddedProvisioningProfileEntitlementsInBundle:(NSBundle *)bundle;

+ (UIButton *)webViewCloseButton;

+ (BOOL)handleURL:(NSURL *)url;

+ (NSNumber *)startBackgroundTask;
+ (void)stopBackgroundTask:(NSNumber *)taskId;

@end
