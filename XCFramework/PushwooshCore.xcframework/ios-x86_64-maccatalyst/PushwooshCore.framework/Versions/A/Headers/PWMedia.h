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
         presentAnimation: .PWAnimationPresentSlideUp,
         dismissAnimation: .PWAnimationDismissSlideDown
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
 Sets the color scheme reported to Rich Media content.

 @param colorScheme The color scheme to use.
 */
+ (void)setRichMediaColorScheme:(PWRichMediaColorScheme)colorScheme;

/**
 Returns the current Rich Media color scheme.
 */
+ (PWRichMediaColorScheme)richMediaColorScheme;

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
     presentAnimation: .PWAnimationPresentSlideUp,
     dismissAnimation: .PWAnimationDismissSlideDown
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
 Sets the color scheme reported to Rich Media content.

 @discussion
 Rich Media content reads the scheme through the `prefers-color-scheme` CSS media query.
 The SDK never recolors content itself: a campaign without a dark variant stays light
 regardless of this setting.

 - `PWRichMediaColorSchemeApp` follows the interface style of your app UI (default).
 - `PWRichMediaColorSchemeSystem` follows the device appearance setting, ignoring window- and
   controller-level overrides such as SwiftUI's `preferredColorScheme(_:)`. An app-wide
   `UIUserInterfaceStyle` in your Info.plist still applies, so with that key set `System` and `App`
   report the same style.
 - `PWRichMediaColorSchemeLight` / `PWRichMediaColorSchemeDark` force a fixed scheme.

 The value is persisted across app launches and takes precedence over Info.plist.
 The scheme is read when a Rich Media is presented and does not change while it is on screen.

 You can also configure via Info.plist using the `Pushwoosh_RICH_MEDIA_COLOR_SCHEME` key
 with values `APP`, `SYSTEM`, `LIGHT` or `DARK`.

 @param colorScheme The color scheme to use.

 ```swift
 func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     Pushwoosh.media.setRichMediaColorScheme(.system)
     return true
 }
 ```

 @see PWRichMediaColorScheme
 */
+ (void)setRichMediaColorScheme:(PWRichMediaColorScheme)colorScheme;

/**
 Returns the current Rich Media color scheme.

 @return The scheme configured via code or Info.plist, `PWRichMediaColorSchemeApp` if neither is set.
 */
+ (PWRichMediaColorScheme)richMediaColorScheme;

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
     presentAnimation: .PWAnimationPresentSlideUp,
     dismissAnimation: .PWAnimationDismissSlideDown
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
