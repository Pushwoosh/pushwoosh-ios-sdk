//
//  PWNotification.m
//  PWNotificationsUI
//
//  Created by Leo Natan on 9/4/14.
//  Copyright (c) 2014 Leo Natan. All rights reserved.
//

#import "PWNotification.h"

@interface PWNotificationAction ()

@property (nonatomic, copy, readwrite) NSString* title;
@property(nonatomic, copy, readwrite) void (^handler)(PWNotificationAction* action);

@end

@implementation PWNotificationAction

+ (instancetype)actionWithTitle:(NSString *)title handler:(void (^)(PWNotificationAction *))handler
{
	PWNotificationAction* action = [self new];
	action.title = title;
	action.handler = handler;
	
	return action;
}

@end

@interface PWNotification ()

@property (nonatomic, copy) NSString* appIdentifier;
@property (nonatomic, copy) NSDictionary* userInfo;

@end

@implementation PWNotification

+ (BOOL)supportsSecureCoding
{
	return YES;
}

+ (instancetype)notificationWithMessage:(NSString*)message
{
	return [[PWNotification alloc] initWithTitle:nil message:message icon:nil date:[NSDate date]];
}

+ (instancetype)notificationWithTitle:(NSString*)title message:(NSString*)message
{
	return [[PWNotification alloc] initWithTitle:title message:message icon:nil date:[NSDate date]];
}

+ (instancetype)notificationWithTitle:(NSString*)title message:(NSString*)message icon:(UIImage*)icon date:(NSDate*)date
{
	return [[PWNotification alloc] initWithTitle:title message:message icon:icon date:date];
}

- (instancetype)initWithMessage:(NSString*)message
{
	return [self initWithTitle:nil message:message icon:nil date:[NSDate date]];
}

- (instancetype)initWithTitle:(NSString*)title message:(NSString*)message
{
	return [self initWithTitle:title message:message icon:nil date:[NSDate date]];
}

- (instancetype)initWithTitle:(NSString*)title message:(NSString*)message icon:(UIImage*)icon date:(NSDate*)date
{
	self = [super init];
	
	if(self)
	{
		self.title = title;
		self.message = message;
		self.icon = icon;
		self.date = date;
		self.displaysWithRelativeDateFormatting = YES;
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	PWNotification* copy = [[PWNotification allocWithZone:zone] initWithTitle:self.title message:self.message icon:self.icon date:self.date];
	copy.displaysWithRelativeDateFormatting = self.displaysWithRelativeDateFormatting;
	copy.defaultAction = self.defaultAction;
	copy.otherActions = self.otherActions;
	copy.soundName = self.soundName;
	
	return copy;
}

- (NSString*)description
{
	NSMutableString* description = [[super description] mutableCopy];
	
	if(self.appIdentifier)
	{
		[description appendFormat:@" appIdentifier: %@", self.appIdentifier];
	}
	
	[description appendFormat:@" ; data: {\n\ttitle = %@\n\tmessage = %@\n\tdate = %@\n\tdisplaysWithRelativeDateFormatting = %@\n\tsoundName = %@\n}", self.title.description, self.message.description, self.date.description, self.displaysWithRelativeDateFormatting ? @"YES" : @"NO", self.soundName.description];
	
	return description;
}

@end
