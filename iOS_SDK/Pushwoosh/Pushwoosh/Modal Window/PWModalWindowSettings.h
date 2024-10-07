//
//  PWModalWindowSettings.h
//  Pushwoosh
//
//  Created by André Kis on 16.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWModalWindowConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWModalWindowSettings : NSObject

@property (nonatomic) ModalWindowPosition modalWindowPosition;
@property (nonatomic) NSArray<NSNumber *> *dismissSwipeDirections;
@property (nonatomic) HapticFeedbackType hapticFeedbackType;
@property (nonatomic) PresentModalWindowAnimation presentAnimation;
@property (nonatomic) DismissModalWindowAnimation dismissAnimation;

+ (instancetype)sharedSettings;

@end

NS_ASSUME_NONNULL_END
