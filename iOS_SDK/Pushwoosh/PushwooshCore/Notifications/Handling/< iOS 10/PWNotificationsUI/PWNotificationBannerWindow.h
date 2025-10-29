//
//  PWNotificationBannerWindow.h
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/5/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PWNotification.h"
#import "PWNotificationCenter.h"

@interface PWNotificationBannerWindow : UIWindow

@property (nonatomic, readonly) BOOL isNotificationViewShown;

- (instancetype)initWithFrame:(CGRect)frame style:(PWNotificationBannerStyle)bannerStyle;

- (void)presentNotification:(PWNotification*)notification completionBlock:(void(^)())completionBlock;
- (void)dismissNotificationViewWithCompletionBlock:(void(^)())completionBlock;

@end
