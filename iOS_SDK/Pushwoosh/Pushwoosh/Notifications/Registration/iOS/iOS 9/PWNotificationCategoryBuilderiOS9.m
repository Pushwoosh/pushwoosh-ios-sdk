//
//  PWNotificationCategoryBuilderiOS9.m
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//
#import "PWNotificationCategoryBuilderiOS9.h"

@implementation PWNotificationCategoryBuilderiOS9

- (void)setActionTextInputWithTitle:(NSString*)title placeholder:(NSString*)placeholder {
    self.currentAction.behavior = UIUserNotificationActionBehaviorTextInput;
    if (title) {
        self.currentAction.parameters = @{ UIUserNotificationTextInputActionButtonTitleKey : title };
    }
}

@end
