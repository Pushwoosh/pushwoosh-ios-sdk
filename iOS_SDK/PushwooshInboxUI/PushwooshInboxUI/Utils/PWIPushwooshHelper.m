//
//  PWIPushwooshHelper.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWIPushwooshHelper.h"
#import "PushwooshInboxUI.h"

#define kPushwooshVersionPrefix @"5."
#define kPushwooshVersion @"5.5+"
#define kIntegrateSDKLink @"http://docs.pushwoosh.com/docs/native-ios-sdk"

#define kPWI_Attention @"\n\n\n\n===========================\n\n\n\n"
#define kPWI_WarningNeedIntegratePushwoosh @"To use PushwooshInboxUI, please integrate the Pushwoosh SDK v%@: %@"
#define kPWI_WarningNeedUpdatePushwoosh @"To use PushwooshInboxUI, please update the Pushwoosh SDK to v4.6.0: link"
#define kPWI_WarningDiffentVersionPushwoosh @"Attention: PushwooshInboxUI version (v%@) is different from Pushwoosh SDK version (v%@). There might be compatibility issues."

@interface PushNotificationManager : NSObject

+ (NSString *)pushwooshVersion;

@end

@implementation PWIPushwooshHelper

+ (Class)pwInbox {
    return NSClassFromString(@"PWInbox");
}

+ (Class)pushNotificationManager {
    return NSClassFromString(@"PushNotificationManager");
}

+ (BOOL)checkPushwooshFrameworkAvailableAndRunExaptionIfNeeded {
    BOOL pushwooshFrameworkAvailable = YES;
    NSString *exceptionReason = nil;
    
    if (!self.checkPushwooshInboxAvailable) {
        pushwooshFrameworkAvailable = NO;
        exceptionReason = [NSString stringWithFormat:kPWI_WarningNeedUpdatePushwoosh];
    }
    if (!self.checkSDKVersion) {
        pushwooshFrameworkAvailable = NO;
        exceptionReason = [NSString stringWithFormat:kPWI_WarningNeedUpdatePushwoosh];
    }
    if (!self.checkPushwooshAvailable) {
        pushwooshFrameworkAvailable = NO;
        exceptionReason = [NSString stringWithFormat:kPWI_WarningNeedIntegratePushwoosh, kPushwooshVersion, kIntegrateSDKLink];
    }
    
    if (exceptionReason) {
        NSLog(@"%@ Integrate PushwooshInboxUI Error: %@%@", kPWI_Attention, exceptionReason, kPWI_Attention);
    }
    
    if (!pushwooshFrameworkAvailable) {
#ifdef DEBUG
        [[NSException exceptionWithName:@"Integrate PushwooshInboxUI Error" reason:exceptionReason userInfo:@{}] raise];
#endif
    }
    
    return pushwooshFrameworkAvailable;
}

+ (BOOL)checkPushwooshInboxAvailable {
    if ([self.pwInbox class]) {
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)checkPushwooshAvailable {
    Class pushwoosh = NSClassFromString(@"PushNotificationManager");
    if ([pushwoosh class]) {
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)checkSDKVersion {
    Class pushNotificationManager = self.pushNotificationManager;
    if ([pushNotificationManager respondsToSelector:@selector(pushwooshVersion)]) {
        NSString *pushwooshVersion = [pushNotificationManager pushwooshVersion];
        if (![pushwooshVersion hasPrefix:kPushwooshVersionPrefix]) {
            NSLog(@"%@%@%@", kPWI_Attention, [NSString stringWithFormat:kPWI_WarningDiffentVersionPushwoosh, PushwooshInboxUIVersion, pushwooshVersion], kPWI_Attention);
        }
        return YES;
    } else {
        return NO;
    }
}

@end
