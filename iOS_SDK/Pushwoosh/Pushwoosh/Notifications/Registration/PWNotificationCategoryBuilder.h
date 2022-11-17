//
//  PWNotificationCategoryBuilder.h
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWNotificationCategoryBuilder : NSObject

@property (nonatomic, strong) NSMutableSet *result;

- (void)pushCategory;

- (void)setCategoryIdentifier:(NSString*)identifier;

- (void)pushAction;

- (void)setActionIdentifier:(NSString*)identifier;

- (void)setActionTitle:(NSString*)title;

- (void)setActionDestructive:(BOOL)destructive;

- (void)setActionStartApplication:(BOOL)start;

- (void)setActionAuthRequired:(BOOL)auth;

- (void)setActionTextInputWithTitle:(NSString*)title placeholder:(NSString*)placeholder;

- (void)addCurrentCategoriesWithCompletion:(dispatch_block_t)completion;

- (NSSet*)build;

@end
