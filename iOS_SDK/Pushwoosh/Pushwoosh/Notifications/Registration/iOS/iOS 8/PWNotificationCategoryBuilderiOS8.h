//
//  PWNotificationCategoryBuilderiOS8.h
//  Pushwoosh
//
//  Created by Fectum on 19/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWNotificationCategoryBuilder.h"
#import <UIKit/UIUserNotificationSettings.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWNotificationCategoryBuilderiOS8 : PWNotificationCategoryBuilder
@property (nonatomic, strong) UIMutableUserNotificationAction *currentAction;

@end

NS_ASSUME_NONNULL_END
