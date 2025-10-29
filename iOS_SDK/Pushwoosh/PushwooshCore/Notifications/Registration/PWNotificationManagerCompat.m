//
//  PWNotificationManagerCompat.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWNotificationManagerCompat.h"

// Default implementation
@implementation PWNotificationManagerCompat

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion {
    if (completion) {
        completion();
    }
    
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
}

- (void)registerForPushNotifications {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
}

- (void)unregisterForPushNotifications {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
	completion(nil);
}

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
	return nil;
}

- (void)clearLocalNotifications {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
}

- (void)didRegisterUserNotificationSettings:(id)notificationSettings {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"STUB"];
}

@end
