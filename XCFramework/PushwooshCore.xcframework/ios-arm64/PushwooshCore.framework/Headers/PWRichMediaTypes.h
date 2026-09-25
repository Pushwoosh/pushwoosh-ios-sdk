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

/**
 Present animation for the modal window. Names match the Android SDK
 (`ModalRichMediaPresentAnimationType`) — direction of travel.
 */
typedef NS_ENUM(NSInteger, PresentModalWindowAnimation) {
    /// Slides in from the bottom edge moving up. Server value: `"up"`.
    PWAnimationPresentSlideUp        = 0,
    /// Drops in from the top edge moving down. Server value: `"down"`.
    PWAnimationPresentDropDown       = 1,
    /// Slides in from the right edge. Server value: `"right"`.
    PWAnimationPresentSlideFromRight = 2,
    /// Slides in from the left edge. Server value: `"left"`.
    PWAnimationPresentSlideFromLeft  = 3,
    /// No animation; appears instantly. Server value: `"none"`.
    PWAnimationPresentNone           = 4,
    /// Fades in. Server value: `"fade_in"`.
    PWAnimationPresentFadeIn         = 5,
    /// Internal: config did not specify a present animation; the global/default value is used.
    PWAnimationPresentUnset          = 6,

    PWAnimationPresentFromBottom __attribute__((deprecated("Renamed to PWAnimationPresentSlideUp"))) = PWAnimationPresentSlideUp,
    PWAnimationPresentFromTop    __attribute__((deprecated("Renamed to PWAnimationPresentDropDown"))) = PWAnimationPresentDropDown,
    PWAnimationPresentFromRight  __attribute__((deprecated("Renamed to PWAnimationPresentSlideFromRight"))) = PWAnimationPresentSlideFromRight,
    PWAnimationPresentFromLeft   __attribute__((deprecated("Renamed to PWAnimationPresentSlideFromLeft"))) = PWAnimationPresentSlideFromLeft,
};

/**
 Dismiss animation for the modal window. Names match the Android SDK
 (`ModalRichMediaDismissAnimationType`) — direction of travel.
 */
typedef NS_ENUM(NSInteger, DismissModalWindowAnimation) {
    /// Slides out downward off-screen. Server value: `"down"`.
    PWAnimationDismissSlideDown      = 0,
    /// Slides out upward off-screen. Server value: `"up"`.
    PWAnimationDismissSlideUp        = 1,
    /// Slides out leftward off-screen. Server value: `"left"`.
    PWAnimationDismissSlideLeft      = 2,
    /// Slides out rightward off-screen. Server value: `"right"`.
    PWAnimationDismissSlideRight     = 3,
    /// Scale-up + fade close (legacy; no Android counterpart).
    PWAnimationCurveEaseInOut        = 4,
    /// No animation; disappears instantly. Server value: `"none"`.
    PWAnimationDismissNone           = 5,
    /// Internal: programmatic default close (scale + fade).
    PWAnimationDismissDefault        = 6,
    /// Fades out. Server value: `"fade_out"`.
    PWAnimationDismissFadeOut        = 7,
    /// Internal: config did not specify a dismiss animation; the global/default value is used.
    PWAnimationDismissUnset          = 8,

    PWAnimationDismissDown __attribute__((deprecated("Renamed to PWAnimationDismissSlideDown"))) = PWAnimationDismissSlideDown,
    PWAnimationDismissUp   __attribute__((deprecated("Renamed to PWAnimationDismissSlideUp"))) = PWAnimationDismissSlideUp,
    PWAnimationDismissLeft __attribute__((deprecated("Renamed to PWAnimationDismissSlideLeft"))) = PWAnimationDismissSlideLeft,
    PWAnimationDismissRight __attribute__((deprecated("Renamed to PWAnimationDismissSlideRight"))) = PWAnimationDismissSlideRight,
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

/**
 Color scheme the SDK reports to Rich Media content via `prefers-color-scheme`.

 The scheme only affects the CSS media query the content sees. Content without a dark variant stays light regardless of the value.
 */
typedef NS_ENUM(NSInteger, PWRichMediaColorScheme) {
    /// Follows the app's own interface style: the top-most presented view controller of the app key window. Default.
    PWRichMediaColorSchemeApp,
    /// Follows the device appearance setting, ignoring window- and controller-level overrides.
    /// An app-wide `UIUserInterfaceStyle` in Info.plist still applies: UIKit propagates it to the
    /// screen traits this mode reads, so under that key `System` reports the same style as `App`.
    PWRichMediaColorSchemeSystem,
    /// Always light.
    PWRichMediaColorSchemeLight,
    /// Always dark.
    PWRichMediaColorSchemeDark
};
