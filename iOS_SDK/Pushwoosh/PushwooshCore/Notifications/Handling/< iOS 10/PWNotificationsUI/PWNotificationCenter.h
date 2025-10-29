//
//  PWNotificationCenter.h
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/4/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class PWNotification, PWNotificationAppSettings;

typedef NS_ENUM(NSUInteger, PWNotificationBannerStyle) {
	PWNotificationBannerStyleDark,
	PWNotificationBannerStyleLight
};

@interface PWNotificationCenter : NSObject

+ (instancetype)defaultCenter;

/**
 The notifications banner style. Default is dark.
 */
@property (nonatomic, assign) PWNotificationBannerStyle notificationsBannerStyle;

/**
 Registers an application with the notification center. Name and icon will be used for notification without titles and icons.

 Normally, should be called early in the application life cycle, before presenting notifications.
 */
- (void)registerApplicationWithIdentifier:(NSString*)appIdentifier name:(NSString*)name icon:(UIImage*)icon defaultSettings:(PWNotificationAppSettings*)defaultSettings;

/**
 Enqueues the specified notification for presentation when possible. The application identifier must be a previously registered identifier.
 */
- (void)presentNotification:(PWNotification*)notification forApplicationIdentifier:(NSString*)appIdentifier;

/**
 Enqueues the specified notification for presentation when possible. The application identifier must be a previously registered identifier. The passed user info dictionary will be passed back in tap notifications.
 */
- (void)presentNotification:(PWNotification*)notification forApplicationIdentifier:(NSString*)appIdentifier userInfo:(NSDictionary*)userInfo;

- (void)setSettings:(PWNotificationAppSettings*)settings enabled:(BOOL)enabled forAppIdentifier:(NSString*)appIdentifier;

/**
 Clears pending notifications for the specified application identifier.
 */
- (void)clearPendingNotificationForApplictionIdentifier:(NSString*)appIdentifier;

/**
 Clears all pending notifications.
 */
- (void)clearAllPendingNotifications;

@end
