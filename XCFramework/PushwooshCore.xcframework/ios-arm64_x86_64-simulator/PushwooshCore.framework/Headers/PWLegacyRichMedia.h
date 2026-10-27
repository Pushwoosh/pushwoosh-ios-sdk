//
//  PWLegacyRichMedia.h
//  PushwooshCore
//
//  Created by André Kis on 24.12.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWRichMediaManager.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol for configuring legacy Rich Media presentation.

 Access via `Pushwoosh.media.legacyRichMedia` in Swift.
 */
@class PWRichMedia;

@protocol PWLegacyRichMedia <NSObject>

+ (Class<PWLegacyRichMedia>)legacyRichMedia;

/**
 Returns the Rich Media presenting delegate.
 */
+ (nullable id<PWRichMediaPresentingDelegate>)getDelegate;

/**
 Sets the Rich Media presenting delegate.

 @param delegate The delegate to receive Rich Media lifecycle events.
 */
+ (void)setDelegate:(nullable id<PWRichMediaPresentingDelegate>)delegate;

#if TARGET_OS_IOS
/**
 Returns the style of the legacy Rich Media presentation.
 */
+ (PWRichMediaStyle *)getRichMediaStyle NS_SWIFT_NAME(getRichMediaStyle());

/**
 Sets the style of the legacy Rich Media presentation; nil restores the default style.
 */
+ (void)setRichMediaStyle:(nullable PWRichMediaStyle *)style NS_SWIFT_NAME(setRichMediaStyle(_:));
#endif

/**
 Presents the Rich Media content.

 @param richMedia The Rich Media object to present.
 */
+ (void)presentRichMedia:(PWRichMedia *)richMedia;

@end

/**
 Legacy Rich Media configuration interface.

 Access via `Pushwoosh.media.legacyRichMedia` in Swift or `[[Pushwoosh media] legacyRichMedia]` in Objective-C.

 The legacy presentation style displays Rich Media in full-screen mode.
 Use this interface to set up a delegate for Rich Media lifecycle events
 when using the legacy presentation style.

 ```swift
 func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

     Pushwoosh.media.setRichMediaPresentationStyle(.legacy)
     Pushwoosh.media.legacyRichMedia.delegate = self

     Pushwoosh.configure.registerForPushNotifications()
     return true
 }
 ```
 */
@interface PWLegacyRichMedia : NSObject <PWLegacyRichMedia>

+ (Class<PWLegacyRichMedia>)legacyRichMedia;

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
         Pushwoosh.media.legacyRichMedia.delegate = self
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

#if TARGET_OS_IOS
/**
 Returns the style of the legacy Rich Media presentation.

 @discussion
 The style controls the loading backdrop, the close button delay, the status bar and inline
 media playback of full-screen Rich Media. Swift exposes it as the `richMediaStyle` property.

 @return The current style, or a default style if none is set.

 @see PWRichMediaStyle
 */
+ (PWRichMediaStyle *)getRichMediaStyle NS_SWIFT_NAME(getRichMediaStyle());

/**
 Sets the style of the legacy Rich Media presentation.

 @discussion
 Replaces `PWRichMediaManager.shared().richMediaStyle`. Passing nil restores the default style.

 @param style The style to apply, or nil to restore the default style.

 ```swift
 let style = PWRichMediaStyle()
 style.backgroundColor = UIColor.black.withAlphaComponent(0.5)
 style.closeButtonPresentingDelay = 2
 Pushwoosh.media.legacyRichMedia.richMediaStyle = style
 ```

 @see PWRichMediaStyle
 */
+ (void)setRichMediaStyle:(nullable PWRichMediaStyle *)style NS_SWIFT_NAME(setRichMediaStyle(_:));
#endif

/**
 Presents the Rich Media content.

 @discussion
 Use this method to manually present Rich Media content.
 The presentation style will follow the current configuration.

 @param richMedia The Rich Media object to present.

 ```swift
 Pushwoosh.media.legacyRichMedia.present(richMedia)
 ```
 */
+ (void)presentRichMedia:(PWRichMedia *)richMedia;

@end

NS_ASSUME_NONNULL_END
