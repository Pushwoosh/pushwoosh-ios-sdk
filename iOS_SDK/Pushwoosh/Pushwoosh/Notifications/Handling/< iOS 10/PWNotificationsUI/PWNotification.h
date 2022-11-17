//
//  PWNotification.h
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/4/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface PWNotificationAction : NSObject

+ (instancetype)actionWithTitle:(NSString *)title handler:(void (^)(PWNotificationAction* action))handler;

@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) void (^handler)(PWNotificationAction* action);

@end

@interface PWNotification : NSObject <NSCopying>

+ (instancetype)notificationWithMessage:(NSString*)message;
+ (instancetype)notificationWithTitle:(NSString*)title message:(NSString*)message;
+ (instancetype)notificationWithTitle:(NSString*)title message:(NSString*)message icon:(UIImage*)icon date:(NSDate*)date;

- (instancetype)initWithMessage:(NSString*)message;
- (instancetype)initWithTitle:(NSString*)title message:(NSString*)message;
- (instancetype)initWithTitle:(NSString*)title message:(NSString*)message icon:(UIImage*)icon date:(NSDate*)date;

@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* message;
@property (nonatomic, strong) UIImage* icon;
@property (nonatomic, copy) NSDate* date;
@property (nonatomic) BOOL displaysWithRelativeDateFormatting;

@property (nonatomic, copy) NSString* soundName;
@property (nonatomic, strong) PWNotificationAction* defaultAction;
@property (nonatomic, copy) NSArray* otherActions;

@end
