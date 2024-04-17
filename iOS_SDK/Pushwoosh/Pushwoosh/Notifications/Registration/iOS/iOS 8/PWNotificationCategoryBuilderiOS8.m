//
//  PWNotificationCategoryBuilderiOS8.m
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//


#import "PWNotificationCategoryBuilderiOS8.h"

@interface PWNotificationCategoryBuilderiOS8()

@property (nonatomic, strong) UIMutableUserNotificationCategory *currentCategory;

@property (nonatomic, strong) NSMutableArray *actions;

@property (nonatomic, strong) NSMutableSet *categoriesId;



@end

@implementation PWNotificationCategoryBuilderiOS8

- (instancetype)init {
    self = [super init];
    if (self) {
        _categoriesId = [NSMutableSet new];
    }
    return self;
}

- (void)pushCategory {
    [self prepare];
    
    _currentCategory = [UIMutableUserNotificationCategory new];
    _currentAction = nil;
    _actions = [NSMutableArray new];
}

- (void)setCategoryIdentifier:(NSString*)identifier  {
    _currentCategory.identifier = identifier;
}

- (void)pushAction {
    if (_currentAction) {
        [_actions addObject:_currentAction];
    }
    _currentAction = [UIMutableUserNotificationAction new];
}

- (void)setActionIdentifier:(NSString*)identifier {
    _currentAction.identifier = identifier;
}

- (void)setActionTitle:(NSString*)title {
    _currentAction.title = title;
}

- (void)setActionDestructive:(BOOL)destructive {
    _currentAction.destructive = destructive;
}

- (void)setActionStartApplication:(BOOL)start {
    _currentAction.activationMode = start ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
}

- (void)setActionAuthRequired:(BOOL)auth {
    _currentAction.authenticationRequired = auth;
}

- (void)prepare {
    [self pushAction];
    
    if (_currentCategory) {
        // iOS8-9 categories has a bug with incorrect buttons order
        NSArray *actions = [[_actions reverseObjectEnumerator] allObjects];
        
        [_currentCategory setActions:actions forContext:UIUserNotificationActionContextDefault];
        [_currentCategory setActions:actions forContext:UIUserNotificationActionContextMinimal];
        [_categoriesId addObject:_currentCategory.identifier];
        [self.result addObject:_currentCategory];
    }
    
    _currentCategory = nil;
    _currentAction = nil;
    _actions = nil;
}

- (void)addCurrentCategoriesWithCompletion:(dispatch_block_t)completion {
    [self prepare];
    
    UIUserNotificationSettings *currentSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    NSSet *currentCategories = currentSettings.categories;
    for (UIUserNotificationCategory *category in currentCategories) {
        if (![_categoriesId containsObject:category.identifier]) {
            [self.result addObject:category];
        }
    }

    if (completion) {
        completion();
    }
}

- (NSSet*)build {
    [self prepare];
    
    return [super build];
}

@end
