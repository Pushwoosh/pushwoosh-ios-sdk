//
//  PWModalWindowSettings.m
//  Pushwoosh
//
//  Created by André Kis on 16.08.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import "PWModalWindowSettings.h"

@implementation PWModalWindowSettings

+ (instancetype)sharedSettings {
    static PWModalWindowSettings *sharedSettings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSettings = [[self alloc] init];
        
        // Initialize default values
        sharedSettings.modalWindowPosition = PWModalWindowPositionDefault;
        sharedSettings.dismissSwipeDirections = @[@(PWSwipeDismissNone)];
        sharedSettings.hapticFeedbackType = PWHapticFeedbackNone;
        sharedSettings.presentAnimation = PWAnimationPresentFromBottom;
        sharedSettings.dismissAnimation = PWAnimationCurveEaseInOut;
    });
    return sharedSettings;
}

@end
