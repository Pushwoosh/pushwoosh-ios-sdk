//
//  PWPlatformModule.h
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWNotificationManagerCompat.h"
#import "PWNotificationCategoryBuilder.h"

@interface PWPlatformModule : NSObject

@property (nonatomic, strong) PWNotificationManagerCompat *notificationManagerCompat;

@property (nonatomic, assign) Class NotificationCategoryBuilder;

+ (PWPlatformModule*)module;

- (void)inject:(id)object;

- (PWNotificationCategoryBuilder*)createCategoryBuilder;

@end
