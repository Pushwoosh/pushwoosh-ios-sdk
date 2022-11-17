//
//  PWNotificationCategoryBuilderiOS10.m
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationCategoryBuilderiOS10.h"
#import <UserNotifications/UserNotifications.h>

@interface PWNotificationCategoryBuilderiOS10()

@property (nonatomic, strong) NSString *categoryId;

@property (nonatomic, strong) NSMutableArray<UNNotificationAction*> *categoryActions;

@property (nonatomic, strong) NSString *actionId;

@property (nonatomic, strong) NSString *actionTitle;

@property (nonatomic, assign) BOOL actionDestruct;

@property (nonatomic, assign) BOOL actionStartsApplication;

@property (nonatomic, assign) BOOL actionAuth;

@property (nonatomic, strong) NSString *actionTextInputTitle;

@property (nonatomic, strong) NSString *actionTextInputPlaceHolder;

@property (nonatomic, strong) NSMutableSet *categoriesId;

@end


@implementation PWNotificationCategoryBuilderiOS10

- (instancetype)init {
    self = [super init];
    if (self) {
        _categoriesId = [NSMutableSet new];
    }
    return self;
}

- (void)pushCategory {
    [self prepare];
    
    _categoryActions = [NSMutableArray new];
}

- (void)setCategoryIdentifier:(NSString*)identifier {
    _categoryId = identifier;
}

- (void)pushAction {
    if (_actionId) {
        UNNotificationActionOptions options = UNNotificationActionOptionNone;
        if (_actionDestruct) {
            options |= UNNotificationActionOptionDestructive;
        }
        if (_actionStartsApplication) {
            options |= UNNotificationActionOptionForeground;
        }
        if (_actionAuth) {
            options |= UNNotificationActionOptionAuthenticationRequired;
        }
        
        UNNotificationAction *action = nil;
        if (_actionTextInputTitle) {
            
            action = [UNTextInputNotificationAction actionWithIdentifier:_actionId
                                                                   title:_actionTitle
                                                                 options:options
                                                    textInputButtonTitle:_actionTextInputTitle
                                                    textInputPlaceholder:_actionTextInputPlaceHolder];
        }
        else {
            action = [UNNotificationAction actionWithIdentifier:_actionId title:_actionTitle options:options];
        }
        [_categoryActions addObject:action];
    }
    
    _actionId = nil;
    _actionTitle = nil;
    _actionDestruct = NO;
    _actionStartsApplication = NO;
    _actionAuth = NO;
    _actionTextInputTitle = nil;
    _actionTextInputPlaceHolder = nil;
}

- (void)setActionIdentifier:(NSString*)identifier {
    _actionId = identifier;
}

- (void)setActionTitle:(NSString*)title {
    _actionTitle = [PWNotificationCategoryBuilderiOS10 localizedString:title withDefault:title];
}

- (void)setActionDestructive:(BOOL)destructive {
    _actionDestruct = destructive;
}

- (void)setActionStartApplication:(BOOL)start {
    _actionStartsApplication = start;
}

- (void)setActionAuthRequired:(BOOL)auth {
    _actionAuth = auth;
}

- (void)setActionTextInputWithTitle:(NSString*)title placeholder:(NSString*)placeholder {
    _actionTextInputTitle = [PWNotificationCategoryBuilderiOS10 localizedString:title withDefault:@"Send"];
    _actionTextInputPlaceHolder = [PWNotificationCategoryBuilderiOS10 localizedString:placeholder withDefault:@""];
}

- (void)addCurrentCategoriesWithCompletion:(dispatch_block_t)completion {
    [self prepare];
    
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> * _Nonnull categories) {
        for (UNNotificationCategory *category in categories) {
            NSString *categoryId = category.identifier;
            if (![_categoriesId containsObject:categoryId]) {
                [self.result addObject:category];
            }
        }
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    }];
}

- (NSSet*)build {
    [self prepare];
    
    return [super build];
}

- (void)prepare {
    [self pushAction];
    
    if (_categoryId) {
        UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:_categoryId
                                                                                  actions:_categoryActions
                                                                        intentIdentifiers:@[]
                                                                                  options:UNNotificationCategoryOptionNone];
        [_categoriesId addObject:_categoryId];
        [self.result addObject:category];
    }
    
    _categoryId = nil;
    _categoryActions = nil;
}

+ (NSString*)localizedString:(NSString*)string withDefault:(NSString*)defaultString {
    NSString *result = @"";
    if (string) {
        result = [NSString localizedUserNotificationStringForKey:string arguments:@[]];
    }
    
    if ([result length] == 0) {
        result = defaultString;
    }
    
    return result;
}

@end

