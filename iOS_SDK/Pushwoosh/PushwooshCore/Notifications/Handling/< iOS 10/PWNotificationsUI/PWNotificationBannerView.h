//
//  PWNotificationBannerView.h
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/5/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PWNotificationCenter.h"

@class PWNotification;

@interface PWNotificationBannerView : UIView

@property (nonatomic, strong, readonly) UIView* backgroundView;
@property (nonatomic, strong, readonly) UIView* notificationContentView;

- (instancetype)initWithFrame:(CGRect)frame style:(PWNotificationBannerStyle)style;

- (void)configureForNotification:(PWNotification*)notification;

@property (nonatomic, strong, readonly) PWNotification* currentNotification;

@end
