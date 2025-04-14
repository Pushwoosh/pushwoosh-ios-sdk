//
//  PWCNotificationAppSettings.h
//  PushwooshCore
//
//  Created by André Kis on 10.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWCNotificationAppSettings : NSObject

+ (instancetype)defaultSettings;

/**
 The alert style of the notification.
 */
@property (nonatomic) BOOL soundEnabled;

@end
