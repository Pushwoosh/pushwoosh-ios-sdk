//
//  PWNotificationManagerCompatiOS8.m
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationManagerCompatiOS8.h"
#import <UIKit/UIKit.h>
#import "PWPushRuntime.h"

@interface PWNotificationManagerCompatiOS8()

@property (nonatomic, strong) dispatch_block_t savedRegisterUserNotificationSettings;
@property (nonatomic, assign) bool notificationDialogHasBeenDismissed;
@property (nonatomic, assign) bool notificationSettingsNeverRegistered;

@end

@implementation PWNotificationManagerCompatiOS8


- (instancetype)init {
    self = [super init];
    if (self) {
        self.notificationDialogHasBeenDismissed = false;
        self.notificationSettingsNeverRegistered = true;
    }
    return self;
}

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion {
    UIUserNotificationType types = [[[UIApplication sharedApplication] currentUserNotificationSettings] types];
    if (types == UIUserNotificationTypeNone) {
        types = UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge;
    }
    
    UIUserNotificationSettings *pushSettings = [UIUserNotificationSettings settingsForTypes:types categories:categories];
    [PWPushRuntime swizzleNotificationSettingsHandler];
    [self registerUserNotificationSettings:pushSettings];

    if (completion) {
        completion();
    }
    
}

//Due to BUG in iOS9 registering again while "allow notifications" popup is active will result in two notifiations on homescreen.
//So we postpone next registrations untill user dismisses dialog.
- (void)registerUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    @synchronized(self) {
        if (!self.notificationDialogHasBeenDismissed && !self.notificationSettingsNeverRegistered) {
            self.savedRegisterUserNotificationSettings = ^void() {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
                });
            };
            return;
        }
        self.notificationSettingsNeverRegistered = false;
    }
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
}

- (void)didRegisterUserNotificationSettings:(id)notificationSettings {
    @synchronized(self) {
        self.notificationDialogHasBeenDismissed = true;
        
        if (self.savedRegisterUserNotificationSettings) {
            self.savedRegisterUserNotificationSettings();
            self.savedRegisterUserNotificationSettings = nil;
        }
    }
}

- (void)registerForPushNotifications {
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    NSInteger type = settings.types;
    results[@"type"] = [NSString stringWithFormat:@"%d", (int)type];
    results[@"pushBadge"] = @"0";
    results[@"pushAlert"] = @"0";
    results[@"pushSound"] = @"0";
    results[@"enabled"] = @"0";
    
    if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
        results[@"enabled"] = @"1";
    }
    if (type & UIUserNotificationTypeBadge) {
        results[@"pushBadge"] = @"1";
    }
    if (type & UIUserNotificationTypeAlert) {
        results[@"pushAlert"] = @"1";
    }
    if (type & UIUserNotificationTypeSound) {
        results[@"pushSound"] = @"1";
    }
    completion(results);
}

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo {
    //try as launchOptions dictionary
    NSDictionary *pushDict = userInfo[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (pushDict == nil) {
        id notification = userInfo[UIApplicationLaunchOptionsLocalNotificationKey];
        
        if (notification && [notification isKindOfClass:[UILocalNotification class]]) {
            pushDict = [notification userInfo];
            
            if (pushDict[@"pw_push"] == nil) {
                pushDict = nil;
            }
        }
    }

    return pushDict;
}

- (void)clearLocalNotifications {
    UIApplication *application = [UIApplication sharedApplication];
    NSArray *scheduledNotifications = [NSArray arrayWithArray:application.scheduledLocalNotifications];
    application.scheduledLocalNotifications = scheduledNotifications;
}

@end
