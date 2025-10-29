//
//  PWNotificationAppSettings.h
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/18/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, PWNotificationAlertStyle) {
	/**
	 Do not display a visual alert.
	 */
	PWNotificationAlertStyleNone = 2,
	/**
	 Display a banner-style alert.
	 */
	PWNotificationAlertStyleBanner = 0,
	/**
	 Display an alert to the user.
	 */
	PWNotificationAlertStyleAlert = 1,
};

@interface PWNotificationAppSettings : NSObject

+ (instancetype)defaultSettings;

/**
 The alert style of the notification.
 */
@property (nonatomic) PWNotificationAlertStyle alertStyle;
@property (nonatomic) BOOL soundEnabled;

@end
