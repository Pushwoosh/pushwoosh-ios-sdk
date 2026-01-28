//
//  PWRichMediaTypes.h
//  PushwooshCore
//
//  Created by André Kis on 21.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ModalWindowPosition) {
    PWModalWindowPositionTop,
    PWModalWindowPositionCenter,
    PWModalWindowPositionBottom,
    PWModalWindowPositionBottomSheet,
    PWModalWindowPositionFullScreen,
    PWModalWindowPositionDefault
};

typedef NS_ENUM(NSInteger, PresentModalWindowAnimation) {
    PWAnimationPresentFromBottom,
    PWAnimationPresentFromTop,
    PWAnimationPresentFromRight,
    PWAnimationPresentFromLeft,
    PWAnimationPresentNone
};

typedef NS_ENUM(NSInteger, DismissModalWindowAnimation) {
    PWAnimationDismissDown,
    PWAnimationDismissUp,
    PWAnimationDismissLeft,
    PWAnimationDismissRight,
    PWAnimationCurveEaseInOut,
    PWAnimationDismissNone,
    PWAnimationDismissDefault
};

typedef NS_ENUM(NSInteger, DismissSwipeDirection) {
    PWSwipeDismissDown,
    PWSwipeDismissUp,
    PWSwipeDismissLeft,
    PWSwipeDismissRight,
    PWSwipeDismissNone
};

typedef NS_ENUM(NSInteger, HapticFeedbackType) {
    PWHapticFeedbackLight,
    PWHapticFeedbackMedium,
    PWHapticFeedbackHard,
    PWHapticFeedbackNone
};

typedef NS_OPTIONS(NSUInteger, CornerType) {
    PWCornerTypeNone        = 0,
    PWCornerTypeTopLeft     = 1 << 0,
    PWCornerTypeTopRight    = 1 << 1,
    PWCornerTypeBottomLeft  = 1 << 2,
    PWCornerTypeBottomRight = 1 << 3,
};

typedef NS_OPTIONS(NSInteger, PWSupportedOrientations) {
    PWOrientationPortrait = 1 << 0,
    PWOrientationPortraitUpsideDown = 1 << 1,
    PWOrientationLandscapeLeft = 1 << 2,
    PWOrientationLandscapeRight = 1 << 3,
};
