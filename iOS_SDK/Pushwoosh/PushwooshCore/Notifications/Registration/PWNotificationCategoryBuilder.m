//
//  PWNotificationCategoryBuilder.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 02/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWNotificationCategoryBuilder.h"

@implementation PWNotificationCategoryBuilder

- (instancetype)init {
	self = [super init];
	if (self) {
		_result = [NSMutableSet new];
	}
	return self;
}

- (void)pushCategory {
	// Stub
}

- (void)setCategoryIdentifier:(NSString*)identifier {
	// Stub
}

- (void)pushAction {
	// Stub
}

- (void)setActionIdentifier:(NSString*)identifier {
	// Stub
}

- (void)setActionTitle:(NSString*)title {
	// Stub
}

- (void)setActionDestructive:(BOOL)destructive {
	// Stub
}

- (void)setActionStartApplication:(BOOL)start {
	// Stub
}

- (void)setActionAuthRequired:(BOOL)auth {
	// Stub
}

- (void)setActionTextInputWithTitle:(NSString*)title placeholder:(NSString*)placeholder {
	// Stub
}

- (void)addCurrentCategoriesWithCompletion:(dispatch_block_t)completion {
	if (completion) {
		completion();
	}
	// Stub
}

- (NSSet*)build {
	return self.result;
}

- (void)dealloc {
	
}

@end
