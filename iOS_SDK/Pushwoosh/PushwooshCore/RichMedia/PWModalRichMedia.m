//
//  PWModalRichMedia.m
//  PushwooshCore
//
//  Created by André Kis on 24.12.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import "PWModalRichMedia.h"
#import "PWModalWindowConfiguration.h"
#import "PWRichMediaManager.h"

@implementation PWModalRichMedia

+ (Class<PWModalRichMedia>)modalRichMedia {
    return self;
}

+ (void)configureWithPosition:(ModalWindowPosition)position
             presentAnimation:(PresentModalWindowAnimation)presentAnimation
             dismissAnimation:(DismissModalWindowAnimation)dismissAnimation {
    [[PWModalWindowConfiguration shared] configureModalWindowWith:position
                                                 presentAnimation:presentAnimation
                                                 dismissAnimation:dismissAnimation];
}

+ (void)setDismissSwipeDirections:(NSArray<NSNumber *>*)directions {
    [[PWModalWindowConfiguration shared] setDismissSwipeDirections:directions];
}

+ (void)setHapticFeedbackType:(HapticFeedbackType)type {
    [[PWModalWindowConfiguration shared] setPresentHapticFeedbackType:type];
}

+ (void)setCornerType:(CornerType)type withRadius:(CGFloat)radius {
    [[PWModalWindowConfiguration shared] setCornerType:type withRadius:radius];
}

+ (void)closeAfter:(NSTimeInterval)interval {
    [[PWModalWindowConfiguration shared] closeModalWindowAfter:interval];
}

+ (id<PWRichMediaPresentingDelegate>)getDelegate {
    return [PWRichMediaManager sharedManager].delegate;
}

+ (void)setDelegate:(id<PWRichMediaPresentingDelegate>)delegate {
    [PWRichMediaManager sharedManager].delegate = delegate;
}

+ (void)presentRichMedia:(PWRichMedia *)richMedia {
    [[PWRichMediaManager sharedManager] presentRichMedia:richMedia];
}

@end

#endif
