//
//  PWNotificationManagerCompat.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWNotificationManagerCompat.h"
#import "PWLog+Internal.h"

// Default implementation
@implementation PWNotificationManagerCompat

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion {
    if (completion) {
        completion();
    }
    
	PWLogDebug(@"STUB");
}

- (void)registerForPushNotifications {
	PWLogDebug(@"STUB");
}

- (void)unregisterForPushNotifications {
	PWLogDebug(@"STUB");
}

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion {
	PWLogDebug(@"STUB");
	completion(nil);
}

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo {
	PWLogDebug(@"STUB");
	return nil;
}

- (void)clearLocalNotifications {
	PWLogDebug(@"STUB");
}

- (void)didRegisterUserNotificationSettings:(id)notificationSettings {
	PWLogDebug(@"STUB");
}

@end
