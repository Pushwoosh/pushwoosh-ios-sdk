//
//  PWNotificationManagerCompat.h
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWNotificationManagerCompat : NSObject

- (void)registerUserNotifications:(NSSet*)categories completion:(dispatch_block_t)completion;

- (void)registerForPushNotifications;

- (void)clearLocalNotifications;

- (void)getRemoteNotificationStatusWithCompletion:(void (^)(NSDictionary*))completion;

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo;

- (void)didRegisterUserNotificationSettings:(id)notificationSettings;

@end
