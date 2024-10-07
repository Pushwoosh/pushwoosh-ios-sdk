//
//  PWModalWindowConfiguration.m
//  Pushwoosh
//
//  Created by André Kis on 01.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import "PWModalWindowConfiguration.h"
#import "PWModalWindowSettings.h"
#import "PWModalWindow.h"

@interface PWModalWindowConfiguration ()

@property (nonatomic) PWModalWindowSettings *settings;
@property (nonatomic) PWModalWindow *modalWindow;

@end

@implementation PWModalWindowConfiguration

+ (instancetype)shared {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.modalWindow = [[PWModalWindow alloc] init];
        self.settings = [PWModalWindowSettings sharedSettings];
    }
    return self;
}
                  
- (void)configureModalWindowWith:(ModalWindowPosition)position
                   presentAnimation:(PresentModalWindowAnimation)presentAnimation
                   dismissAnimation:(DismissModalWindowAnimation)dismissAnimation {
        self.settings.modalWindowPosition = position;
        self.settings.presentAnimation = presentAnimation;
        self.settings.dismissAnimation = dismissAnimation;
}

- (void)setDismissSwipeDirections:(NSArray<NSNumber *>*)swipeDirections {
    self.settings.dismissSwipeDirections = swipeDirections;
}

- (void)setPresentHapticFeedbackType:(HapticFeedbackType)type {
    self.settings.hapticFeedbackType = type;
}

- (void)closeModalWindowAfter:(NSTimeInterval)interval {
    [self.modalWindow closeModalWindowAfter:interval];
}

- (void)presentModalWindow:(PWRichMedia *)richMedia {
    [self.modalWindow presentModalWindow:richMedia modalWindow:_modalWindow];
}

@end
