//
//  PWMedia.h
//  PushwooshCore
//
//  Created by André Kis on 24.12.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PWRichMediaTypes.h>

@protocol PWModalRichMedia, PWLegacyRichMedia;

NS_ASSUME_NONNULL_BEGIN

/**
 Presentation style for Rich Media content.
 */
typedef NS_ENUM(NSInteger, PWRichMediaPresentationStyle) {
    /// Modal window presentation with customizable position and animations
    PWRichMediaPresentationStyleModal,
    /// Legacy full-screen presentation
    PWRichMediaPresentationStyleLegacy
};

/**
 Protocol for configuring Rich Media presentation.

 Configure Rich Media in your AppDelegate before registering for push notifications:

 ```swift
 func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

     Pushwoosh.media.setRichMediaPresentationStyle(.modal)
     Pushwoosh.media.modalRichMedia.configure(
         position: .PWModalWindowPositionBottom,
         presentAnimation: .PWAnimationPresentFromBottom,
         dismissAnimation: .PWAnimationDismissDown
     )
     Pushwoosh.media.modalRichMedia.delegate = self

     Pushwoosh.sharedInstance().registerForPushNotifications()
     return true
 }
 ```

 The presentation style is persisted across app launches. If you remove the method call
 from your code, the setting will revert to Info.plist configuration on the next launch.

 You can also configure via Info.plist using `Pushwoosh_RICH_MEDIA_STYLE` key
 with values: `MODAL_RICH_MEDIA` or `LEGACY_RICH_MEDIA`.
 */
@protocol PWMedia <NSObject>

+ (Class<PWMedia>)media;

/**
 Sets the Rich Media presentation style.

 @param style The presentation style to use.
 */
+ (void)setRichMediaPresentationStyle:(PWRichMediaPresentationStyle)style;

/**
 Returns the current Rich Media presentation style.
 */
+ (PWRichMediaPresentationStyle)richMediaPresentationStyle;

/**
 Provides access to modal Rich Media configuration.
 */
+ (Class<PWModalRichMedia>)modalRichMedia NS_REFINED_FOR_SWIFT;

/**
 Provides access to legacy Rich Media configuration.
 */
+ (Class<PWLegacyRichMedia>)legacyRichMedia NS_REFINED_FOR_SWIFT;

@end

/**
 Rich Media configuration interface.

 Access via `Pushwoosh.media` in Swift or `[Pushwoosh media]` in Objective-C.

 Use this interface to configure Rich Media presentation style and access
 style-specific configuration via `modalRichMedia` or `legacyRichMedia` sub-interfaces.

 ```swift
 // Select presentation style
 Pushwoosh.media.setRichMediaPresentationStyle(.modal)

 // Configure modal-specific settings
 Pushwoosh.media.modalRichMedia.configure(
     position: .PWModalWindowPositionBottom,
     presentAnimation: .PWAnimationPresentFromBottom,
     dismissAnimation: .PWAnimationDismissDown
 )
 Pushwoosh.media.modalRichMedia.delegate = self

 // Or configure legacy-specific settings
 Pushwoosh.media.setRichMediaPresentationStyle(.legacy)
 Pushwoosh.media.legacyRichMedia.delegate = self
 ```
 */
@interface PWMedia : NSObject <PWMedia>

+ (Class<PWMedia>)media;

/**
 Sets the Rich Media presentation style.

 @discussion
 This method configures how Rich Media content (In-App messages) is displayed.
 The setting is persisted across app launches via NSUserDefaults.

 If you remove this method call from your code, the setting will revert
 to Info.plist configuration on the next app launch.

 You can also configure via Info.plist using `Pushwoosh_RICH_MEDIA_STYLE` key
 with values: `MODAL_RICH_MEDIA` or `LEGACY_RICH_MEDIA`.

 @param style The presentation style to use.

 ```swift
 func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     Pushwoosh.media.setRichMediaPresentationStyle(.modal)
     return true
 }
 ```

 @see PWRichMediaPresentationStyle
 */
+ (void)setRichMediaPresentationStyle:(PWRichMediaPresentationStyle)style;

/**
 Returns the current Rich Media presentation style.

 @return The current presentation style configured via code or Info.plist.
 */
+ (PWRichMediaPresentationStyle)richMediaPresentationStyle;

/**
 Provides access to modal Rich Media configuration.

 @discussion
 Use this property to configure modal-specific settings such as window position,
 animations, haptic feedback, corner radius, and delegate.

 Modal configuration only applies when the presentation style is set to
 `PWRichMediaPresentationStyleModal`.

 @return The PWModalRichMedia class for modal configuration.

 ```swift
 Pushwoosh.media.setRichMediaPresentationStyle(.modal)
 Pushwoosh.media.modalRichMedia.configure(
     position: .PWModalWindowPositionBottom,
     presentAnimation: .PWAnimationPresentFromBottom,
     dismissAnimation: .PWAnimationDismissDown
 )
 Pushwoosh.media.modalRichMedia.delegate = self
 ```

 @see PWModalRichMedia
 */
+ (Class<PWModalRichMedia>)modalRichMedia NS_REFINED_FOR_SWIFT;

/**
 Provides access to legacy Rich Media configuration.

 @discussion
 Use this property to configure legacy-specific settings such as the delegate.

 Legacy configuration applies when the presentation style is set to
 `PWRichMediaPresentationStyleLegacy`.

 @return The PWLegacyRichMedia class for legacy configuration.

 ```swift
 Pushwoosh.media.setRichMediaPresentationStyle(.legacy)
 Pushwoosh.media.legacyRichMedia.delegate = self
 ```

 @see PWLegacyRichMedia
 */
+ (Class<PWLegacyRichMedia>)legacyRichMedia NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
