//
//  PWRichMediaConfiguration.h
//  Pushwoosh
//
//  Created by André Kis on 01.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWRichMediaManager.h"

/**
 Enum defining the possible positions for displaying a modal window.

 - `PWModalWindowPositionTop`: The modal window appears at the top of the screen, within the safe area.
 - `PWModalWindowPositionCenter`: The modal window appears at the center of the screen, within the safe area.
 - `PWModalWindowPositionBottom`: The modal window appears at the bottom of the screen, within the safe area.
 - `PWModalWindowPositionBottomSheet`: The modal window appears at the very bottom of the screen, ignoring the safe area.
 - `PWModalWindowPositionDefault`: The default position is the center of the screen, within the safe area.
 */
typedef NS_ENUM(NSInteger, ModalWindowPosition) {
    PWModalWindowPositionTop,       // Appears at the top of the screen (within safe area)
    PWModalWindowPositionCenter,    // Appears at the center of the screen (within safe area)
    PWModalWindowPositionBottom,    // Appears at the bottom of the screen (within safe area)
    PWModalWindowPositionBottomSheet, // Appears at the very bottom of the screen (ignores safe area)
    PWModalWindowPositionFullScreen, // Fullscreen, ignores safe area insets
    PWModalWindowPositionDefault    // Default position (center of the screen, within safe area)
};

/**
 Enum defining the types of haptic feedback that can be triggered when interacting with the modal window.

 - `PWHapticFeedbackLight`: Provides a light vibration feedback.
 - `PWHapticFeedbackMedium`: Provides a medium-intensity vibration feedback.
 - `PWHapticFeedbackHard`: Provides a strong vibration feedback.
 - `PWHapticFeedbackNone`: Vibration feedback is turned off by default.
 */
typedef NS_ENUM(NSInteger, HapticFeedbackType) {
    PWHapticFeedbackLight,         // Light vibration feedback
    PWHapticFeedbackMedium,        // Medium vibration feedback
    PWHapticFeedbackHard,          // Strong vibration feedback
    
    /**
     * Vibration is off by default.
     */
    PWHapticFeedbackNone
};

/**
 Enum defining the animation styles for dismissing the modal window.

 - `PWAnimationDismissDown`: The modal window slides down when dismissed.
 - `PWAnimationDismissUp`: The modal window slides up when dismissed.
 - `PWAnimationDismissLeft`: The modal window slides to the left when dismissed.
 - `PWAnimationDismissRight`: The modal window slides to the right when dismissed.
 - `PWAnimationCurveEaseInOut`: The modal window uses an ease-in-out curve animation when dismissed.
 - `PWAnimationDismissNone`: No animation is applied when dismissing the modal window.
 - `PWAnimationDismissDefault`: The default dismiss animation is `PWAnimationCurveEaseInOut`.
 */
typedef NS_ENUM(NSInteger, DismissModalWindowAnimation) {
    PWAnimationDismissDown,
    PWAnimationDismissUp,
    PWAnimationDismissLeft,
    PWAnimationDismissRight,
    PWAnimationCurveEaseInOut,
    PWAnimationDismissNone,
    
    /**
     * Default dismiss animation is `PWAnimationCurveEaseInOut`
     */
    PWAnimationDismissDefault
};

typedef NS_ENUM(NSInteger, DismissSwipeDirection) {
    PWSwipeDismissDown,
    PWSwipeDismissUp,
    PWSwipeDismissLeft,
    PWSwipeDismissRight,
    PWSwipeDismissNone
};

/**
 Enum defining the animation styles for presenting the modal window.

 - `PWAnimationPresentFromBottom`: The modal window slides in from the bottom of the screen.
 - `PWAnimationPresentFromTop`: The modal window slides in from the top of the screen.
 - `PWAnimationPresentFromRight`: The modal window slides in from the right side of the screen.
 - `PWAnimationPresentFromLeft`: The modal window slides in from the left side of the screen.
 - `PWAnimationPresentNone`: No animation is applied when presenting the modal window.
 */
typedef NS_ENUM(NSInteger, PresentModalWindowAnimation) {
    PWAnimationPresentFromBottom,
    PWAnimationPresentFromTop,
    PWAnimationPresentFromRight,
    PWAnimationPresentFromLeft,
    PWAnimationPresentNone
};

/**
 Enum options defining the corners that can be rounded in a modal window.

 - `PWCornerTypeNone`: No corners are rounded.
 - `PWCornerTypeTopLeft`: The top-left corner is rounded.
 - `PWCornerTypeTopRight`: The top-right corner is rounded.
 - `PWCornerTypeBottomLeft`: The bottom-left corner is rounded.
 - `PWCornerTypeBottomRight`: The bottom-right corner is rounded.
 
 In Objective-C, multiple values can be combined using the bitwise OR operator (`|`).

 In Swift, you can use the `OptionSet` syntax to combine multiple corner types. For example:
 
 ```swift
 let cornerTypes: CornerType = [.topLeft, .bottomRight]
 */
typedef NS_OPTIONS(NSUInteger, CornerType) {
    PWCornerTypeNone        = 0,
    PWCornerTypeTopLeft     = 1 << 0,
    PWCornerTypeTopRight    = 1 << 1,
    PWCornerTypeBottomLeft  = 1 << 2,
    PWCornerTypeBottomRight = 1 << 3,
};

NS_ASSUME_NONNULL_BEGIN

@interface PWModalWindowConfiguration : NSObject

/**
 Provides access to the shared instance of the modal window manager.

 @return A singleton instance of the modal window manager.
 */
+ (instancetype)shared;

/**
 Configures the modal window to be displayed at a specified position on the screen and defines the animation styles for presenting and dismissing the window.

 @param position The screen position where the modal window will be displayed (e.g., top, bottom).
 @param presentAnimation The animation style used when the modal window is presented (e.g., fade, slide).
 @param dismissAnimation The animation style used when the modal window is dismissed (e.g., fade, slide).
 */
- (void)configureModalWindowWith:(ModalWindowPosition)position
                presentAnimation:(PresentModalWindowAnimation)presentAnimation
                dismissAnimation:(DismissModalWindowAnimation)dismissAnimation;

/**
 Configures swipe gestures for interacting with the modal window. These gestures allow the user to dismiss the window by swiping in specified directions.

 @param swipeDirection An array of swipe directions allowed for dismissing the modal window (e.g., up, down, left, right).
 */
- (void)setDismissSwipeDirections:(NSArray<NSNumber *>*)swipeDirection;

/**
 Sets the type of haptic feedback that will be triggered when the modal window is presented.

 @param type The type of haptic feedback to be used (e.g., light, medium, heavy).
 */
- (void)setPresentHapticFeedbackType:(HapticFeedbackType)type;

/**
 Sets the corner type and radius for rounding specific corners of the view.

 @param type The type of corners to be rounded (e.g., top-left, bottom-right, or a combination).
 @param radius The radius of the corner rounding.
 */
- (void)setCornerType:(CornerType)type withRadius:(CGFloat)radius;

/**
 Schedules the automatic closing of the modal window after a specified time interval.

 @param interval The time interval, in seconds, after which the modal window will be automatically closed.
 */
- (void)closeModalWindowAfter:(NSTimeInterval)interval;

/**
 Presents the modal window with the specified rich media content.

 @param richMedia The rich media content that will be displayed inside the modal window.
 */
- (void)presentModalWindow:(PWRichMedia *)richMedia;

@end

NS_ASSUME_NONNULL_END
