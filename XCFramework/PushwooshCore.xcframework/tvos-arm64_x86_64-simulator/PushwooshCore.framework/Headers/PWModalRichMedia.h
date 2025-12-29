//
//  PWModalRichMedia.h
//  PushwooshCore
//
//  Created by André Kis on 24.12.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWRichMediaTypes.h>
#import <PushwooshCore/PWRichMediaManager.h>

@class PWRichMedia;

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol for configuring modal Rich Media presentation.

 Access via `Pushwoosh.media.modalRichMedia` in Swift.
 */
@protocol PWModalRichMedia <NSObject>

+ (Class<PWModalRichMedia>)modalRichMedia;

/**
 Configures the modal window appearance and animations.

 @param position Screen position of the modal window.
 @param presentAnimation Animation when presenting.
 @param dismissAnimation Animation when dismissing.
 */
+ (void)configureWithPosition:(ModalWindowPosition)position
             presentAnimation:(PresentModalWindowAnimation)presentAnimation
             dismissAnimation:(DismissModalWindowAnimation)dismissAnimation;

/**
 Sets swipe directions that dismiss the modal window.

 @param directions Array of `DismissSwipeDirection` values wrapped in NSNumber.
 */
+ (void)setDismissSwipeDirections:(NSArray<NSNumber *>*)directions;

/**
 Sets haptic feedback when presenting the modal window.

 @param type The haptic feedback type.
 */
+ (void)setHapticFeedbackType:(HapticFeedbackType)type;

/**
 Sets corner radius for the modal window.

 @param type Which corners to round.
 @param radius Corner radius in points.
 */
+ (void)setCornerType:(CornerType)type withRadius:(CGFloat)radius;

/**
 Automatically closes the modal window after specified interval.

 @param interval Time in seconds before auto-dismiss.
 */
+ (void)closeAfter:(NSTimeInterval)interval;

/**
 Returns the Rich Media presenting delegate.
 */
+ (nullable id<PWRichMediaPresentingDelegate>)getDelegate;

/**
 Sets the Rich Media presenting delegate.

 @param delegate The delegate to receive Rich Media lifecycle events.
 */
+ (void)setDelegate:(nullable id<PWRichMediaPresentingDelegate>)delegate;

/**
 Presents the Rich Media content.

 @param richMedia The Rich Media object to present.
 */
+ (void)presentRichMedia:(PWRichMedia *)richMedia;

@end

/**
 Modal Rich Media configuration interface.

 Access via `Pushwoosh.media.modalRichMedia` in Swift or `[[Pushwoosh media] modalRichMedia]` in Objective-C.

 Configure modal Rich Media presentation in your AppDelegate:

 ```swift
 func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

     Pushwoosh.media.setRichMediaPresentationStyle(.modal)
     Pushwoosh.media.modalRichMedia.configure(
         position: .PWModalWindowPositionBottom,
         presentAnimation: .PWAnimationPresentFromBottom,
         dismissAnimation: .PWAnimationDismissDown
     )
     Pushwoosh.media.modalRichMedia.setDismissSwipeDirections([NSNumber(value: PWSwipeDismissDown.rawValue)])
     Pushwoosh.media.modalRichMedia.delegate = self

     Pushwoosh.configure.registerForPushNotifications()
     return true
 }
 ```
 */
@interface PWModalRichMedia : NSObject <PWModalRichMedia>

+ (Class<PWModalRichMedia>)modalRichMedia;

/**
 Configures the modal window appearance and animations.

 @discussion
 Use this method to customize modal window position and animations.
 Only applies when presentation style is set to `PWRichMediaPresentationStyleModal`.

 @param position Screen position: `PWModalWindowPositionTop`, `PWModalWindowPositionCenter`, `PWModalWindowPositionBottom`, `PWModalWindowPositionBottomSheet`, `PWModalWindowPositionFullScreen`, `PWModalWindowPositionDefault`.
 @param presentAnimation Present animation: `PWAnimationPresentFromBottom`, `PWAnimationPresentFromTop`, `PWAnimationPresentFromRight`, `PWAnimationPresentFromLeft`, `PWAnimationPresentNone`.
 @param dismissAnimation Dismiss animation: `PWAnimationDismissDown`, `PWAnimationDismissUp`, `PWAnimationDismissLeft`, `PWAnimationDismissRight`, `PWAnimationDismissNone`, `PWAnimationDismissDefault`.

 ```swift
 Pushwoosh.media.modalRichMedia.configure(
     position: .PWModalWindowPositionBottom,
     presentAnimation: .PWAnimationPresentFromBottom,
     dismissAnimation: .PWAnimationDismissDown
 )
 ```
 */
+ (void)configureWithPosition:(ModalWindowPosition)position
             presentAnimation:(PresentModalWindowAnimation)presentAnimation
             dismissAnimation:(DismissModalWindowAnimation)dismissAnimation;

/**
 Sets swipe directions that dismiss the modal window.

 @discussion
 Allows users to dismiss the modal window by swiping in specified directions.
 Only applies when presentation style is set to `PWRichMediaPresentationStyleModal`.

 @param directions Array of `DismissSwipeDirection` values wrapped in NSNumber: `PWSwipeDismissDown`, `PWSwipeDismissUp`, `PWSwipeDismissLeft`, `PWSwipeDismissRight`, `PWSwipeDismissNone`.

 ```swift
 Pushwoosh.media.modalRichMedia.setDismissSwipeDirections([
     NSNumber(value: PWSwipeDismissDown.rawValue),
     NSNumber(value: PWSwipeDismissLeft.rawValue)
 ])
 ```
 */
+ (void)setDismissSwipeDirections:(NSArray<NSNumber *>*)directions;

/**
 Sets haptic feedback when presenting the modal window.

 @discussion
 Provides tactile feedback when the modal window appears.
 Only applies when presentation style is set to `PWRichMediaPresentationStyleModal`.

 @param type The haptic feedback type: `PWHapticFeedbackLight`, `PWHapticFeedbackMedium`, `PWHapticFeedbackHard`, `PWHapticFeedbackNone`.

 ```swift
 Pushwoosh.media.modalRichMedia.setHapticFeedbackType(.PWHapticFeedbackMedium)
 ```
 */
+ (void)setHapticFeedbackType:(HapticFeedbackType)type;

/**
 Sets corner radius for the modal window.

 @discussion
 Rounds the corners of the modal window for a modern appearance.
 Only applies when presentation style is set to `PWRichMediaPresentationStyleModal`.

 @param type Corner mask using `CornerType` options: `PWCornerTypeNone`, `PWCornerTypeTopLeft`, `PWCornerTypeTopRight`, `PWCornerTypeBottomLeft`, `PWCornerTypeBottomRight`. Combine with bitwise OR.
 @param radius Corner radius in points.

 ```swift
 let topCorners = PWCornerTypeTopLeft.rawValue | PWCornerTypeTopRight.rawValue
 Pushwoosh.media.modalRichMedia.setCornerType(CornerType(rawValue: topCorners), radius: 16)
 ```
 */
+ (void)setCornerType:(CornerType)type withRadius:(CGFloat)radius;

/**
 Automatically closes the modal window after specified interval.

 @discussion
 Sets a timer to automatically dismiss the modal window.
 Useful for promotional content that should disappear after a set time.
 Only applies when presentation style is set to `PWRichMediaPresentationStyleModal`.

 @param interval Time in seconds before auto-dismiss. Pass 0 to disable.

 ```swift
 Pushwoosh.media.modalRichMedia.closeAfter(10)
 ```
 */
+ (void)closeAfter:(NSTimeInterval)interval;

/**
 Returns the Rich Media presenting delegate.

 @discussion
 The delegate receives Rich Media lifecycle events such as presentation,
 dismissal, and errors.

 @return The current Rich Media presenting delegate, or nil if not set.

 @see PWRichMediaPresentingDelegate
 */
+ (nullable id<PWRichMediaPresentingDelegate>)getDelegate;

/**
 Sets the Rich Media presenting delegate.

 @discussion
 Set a delegate to receive Rich Media lifecycle events. The delegate methods
 are called for all Rich Media presentations, regardless of style.

 @param delegate The delegate to receive Rich Media lifecycle events.

 ```swift
 class AppDelegate: UIResponder, UIApplicationDelegate, PWRichMediaPresentingDelegate {
     func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
         Pushwoosh.media.modalRichMedia.delegate = self
         return true
     }

     func richMediaManager(_ richMediaManager: PWRichMediaManager, shouldPresent richMedia: PWRichMedia) -> Bool {
         return !userIsInCheckout
     }

     func richMediaManager(_ richMediaManager: PWRichMediaManager, didPresent richMedia: PWRichMedia) {
         Analytics.log("rich_media_shown", code: richMedia.code)
     }

     func richMediaManager(_ richMediaManager: PWRichMediaManager, didClose richMedia: PWRichMedia) {
         Analytics.log("rich_media_closed", code: richMedia.code)
     }
 }
 ```

 @see PWRichMediaPresentingDelegate
 */
+ (void)setDelegate:(nullable id<PWRichMediaPresentingDelegate>)delegate;

/**
 Presents the Rich Media content.

 @discussion
 Use this method to manually present Rich Media content.
 The presentation style will follow the current modal configuration.

 @param richMedia The Rich Media object to present.

 ```swift
 Pushwoosh.media.modalRichMedia.present(richMedia)
 ```
 */
+ (void)presentRichMedia:(PWRichMedia *)richMedia;

@end

NS_ASSUME_NONNULL_END
