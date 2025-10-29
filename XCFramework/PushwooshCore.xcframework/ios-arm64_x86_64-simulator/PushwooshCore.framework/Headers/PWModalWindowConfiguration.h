//
//  PWRichMediaConfiguration.h
//  Pushwoosh
//
//  Created by André Kis on 01.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWRichMediaTypes.h>

@class PWRichMedia;

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
