//
//  PWPushPrimerBuilder.h
//  PushwooshCore
//
//  Created by André Kis on 15.06.2026.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Visual style of the push primer dialog.
typedef NS_ENUM(NSInteger, PWPushPrimerStyle) {
    /// Default. Rendered with a system `UIAlertController`. No image.
    PWPushPrimerStyleAlert = 0,
    /// Custom view controller. Supports image, colors, corner radius and `position`.
    PWPushPrimerStyleSheet = 1
};

/// On-screen placement of the custom primer (`PWPushPrimerStyleSheet`). Each position has its
/// own default design. Ignored for `PWPushPrimerStyleAlert` (system alert is always centered).
typedef NS_ENUM(NSInteger, PWPushPrimerPosition) {
    /// Default. Bottom sheet — slides up from the bottom, grabber, full-width buttons.
    PWPushPrimerPositionBottom = 0,
    /// Push-style banner — compact card that drops in from the top, like a notification.
    PWPushPrimerPositionTop = 1,
    /// Centered dialog — scales/fades in in the middle of the screen.
    PWPushPrimerPositionCenter = 2
};

/// Result of presenting the push primer.
typedef NS_ENUM(NSInteger, PWPushPrimerOutcome) {
    /// Primer was shown and the user accepted; the system push prompt was requested.
    PWPushPrimerOutcomeAccepted = 0,
    /// Primer was shown and the user declined.
    PWPushPrimerOutcomeDeclined = 1,
    /// Primer was not shown because notifications are already authorized/provisional,
    /// or because the status is denied and `fallbackToSettings` is disabled.
    PWPushPrimerOutcomeSuppressed = 2,
    /// Primer was shown in a denied state and accept opened the system Settings app.
    PWPushPrimerOutcomeRedirectedToSettings = 3
};

/// Completion block invoked once the primer flow finishes.
typedef void (^PWPushPrimerCompletion)(PWPushPrimerOutcome outcome);

/**
 A fluent builder for a soft push-permission primer.

 The primer is a soft in-app dialog shown *before* the iOS system permission prompt.
 It reads the current authorization status and decides whether to show or silently
 suppress, renders its own native UI, and on accept triggers push registration.

 The builder is obtained fresh on every access via `Pushwoosh.configure.pushPrimer`,
 configured through chained setters, and shown with `present` / `present:`.

 ```swift
 Pushwoosh.configure.pushPrimer
     .title("Stay in the loop")
     .message("Get notified about deals first")
     .acceptButton("Enable")
     .declineButton("Later")
     .present { outcome in }
 ```
 */
@interface PWPushPrimerBuilder : NSObject

/// Sets the dialog style. Defaults to `PWPushPrimerStyleAlert`.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^style)(PWPushPrimerStyle style);
/// Sets the on-screen position (sheet style only). Defaults to `PWPushPrimerPositionBottom`.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^position)(PWPushPrimerPosition position);
/// Sets the title text.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^title)(NSString *title);
/// Sets the body message text.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^message)(NSString *message);
/// Sets the accept button title.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^acceptButton)(NSString *title);
/// Sets the decline button title.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^declineButton)(NSString *title);
/// Sets the image URL (sheet style only). Loaded asynchronously.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^imageURL)(NSString *url);
/// Sets a local image (sheet style only). Takes precedence over `imageURL` when both are set.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^image)(UIImage *image);
/// Sets the background color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^backgroundColor)(UIColor *color);
/// Sets a soft multi-color watercolor gradient background from the given colors (sheet style only).
/// Rendered as overlapping radial color washes. Overrides `backgroundColor`.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^backgroundGradient)(NSArray<UIColor *> *colors);
/// Sets the title text color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^titleColor)(UIColor *color);
/// Sets the message text color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^messageColor)(UIColor *color);
/// Sets the accept button background color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^acceptButtonColor)(UIColor *color);
/// Sets the accept button text color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^acceptButtonTextColor)(UIColor *color);
/// Sets the decline button background color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^declineButtonColor)(UIColor *color);
/// Sets the decline button text color (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^declineButtonTextColor)(UIColor *color);
/// Sets the corner radius of the sheet (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^cornerRadius)(CGFloat radius);
/// Sets a border color for both buttons (sheet style only). A 1pt border is drawn when set.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^buttonBorderColor)(UIColor *color);
/// Sets the corner radius of both buttons (sheet style only).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^buttonCornerRadius)(CGFloat radius);
/// Controls behavior when notifications are already denied at the OS level. Defaults to `YES`:
/// the primer is shown and accept routes the user to the system Settings app. When `NO`, a denied
/// status suppresses the primer entirely (the system will not re-prompt anyway).
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^fallbackToSettings)(BOOL enabled);
/// Sets the minimum interval, in seconds, between primer displays. If the primer was shown more
/// recently than this it is suppressed (outcome `PWPushPrimerOutcomeSuppressed`). Defaults to 0 —
/// no throttling, the client controls timing. The last-shown time is persisted across launches.
/// For example pass `7 * 24 * 60 * 60` to ask at most once a week.
@property (nonatomic, copy, readonly) PWPushPrimerBuilder *(^minInterval)(NSTimeInterval seconds);

/// Presents the primer with no completion.
- (void)present;

/// Presents the primer and invokes `completion` with the outcome.
- (void)present:(nullable PWPushPrimerCompletion)completion;

@end

NS_ASSUME_NONNULL_END

#endif
