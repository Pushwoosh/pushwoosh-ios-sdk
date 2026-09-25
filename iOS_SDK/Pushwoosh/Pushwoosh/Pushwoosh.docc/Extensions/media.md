# ``Pushwoosh/media``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to Rich Media presentation and color scheme configuration.

## Overview

Use this property to configure how Rich Media content is displayed. You can choose between modal presentation with customizable animations or legacy full-screen presentation.

Available presentation styles:
- `.modal` - Modal window with customizable position, animations, and swipe-to-dismiss
- `.legacy` - Legacy full-screen presentation

Access style-specific configuration via `modalRichMedia` or `legacyRichMedia` sub-interfaces:
- `Pushwoosh.media.modalRichMedia` - Modal-specific settings (position, animations, corners, haptic feedback, delegate)
- `Pushwoosh.media.legacyRichMedia` - Legacy-specific settings (delegate)

The presentation style is persisted across app launches. If you remove the configuration from your code, it reverts to Info.plist settings on the next launch.

### Color scheme

Rich Media content reads its theme through the `prefers-color-scheme` CSS media query. The color scheme setting controls which value the SDK reports; the SDK never recolors content, so a campaign without a dark variant stays light regardless of the setting.

- `.app` - follows the interface style of your app UI (default)
- `.system` - follows the device appearance setting, ignoring window- and controller-level overrides such as `preferredColorScheme(_:)`. An app-wide `UIUserInterfaceStyle` in Info.plist still applies, so with that key set `.system` and `.app` report the same style
- `.light` / `.dark` - fixed scheme

The value is persisted, takes precedence over Info.plist, and is read when a Rich Media is presented. The same options exist on Android, so both platforms render the same variant for the same setting.

## Example

Configure Rich Media with modal presentation style:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Select modal presentation style
    Pushwoosh.media.setRichMediaPresentationStyle(.modal)

    // Configure modal-specific settings
    Pushwoosh.media.modalRichMedia.configure(
        position: .PWModalWindowPositionBottom,
        presentAnimation: .PWAnimationPresentFromBottom,
        dismissAnimation: .PWAnimationDismissDown
    )
    Pushwoosh.media.modalRichMedia.setDismissSwipeDirections([NSNumber(value: PWSwipeDismissDown.rawValue)])

    let topCorners = PWCornerTypeTopLeft.rawValue | PWCornerTypeTopRight.rawValue
    Pushwoosh.media.modalRichMedia.setCornerType(CornerType(rawValue: topCorners), radius: 16)

    // Set delegate for Rich Media lifecycle events
    Pushwoosh.media.modalRichMedia.delegate = self

    Pushwoosh.configure.registerForPushNotifications()
    return true
}
```

Configure Rich Media with legacy presentation style:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Select legacy (full-screen) presentation style
    Pushwoosh.media.setRichMediaPresentationStyle(.legacy)

    // Set delegate for Rich Media lifecycle events
    Pushwoosh.media.legacyRichMedia.delegate = self

    Pushwoosh.configure.registerForPushNotifications()
    return true
}
```

Force a fixed color scheme, for example while dark campaign variants are not ready yet:

```swift
Pushwoosh.media.setRichMediaColorScheme(.light)
```

Configure via Info.plist instead of code:

Add `Pushwoosh_RICH_MEDIA_STYLE` key with value `MODAL_RICH_MEDIA` or `LEGACY_RICH_MEDIA`.

Add `Pushwoosh_RICH_MEDIA_COLOR_SCHEME` key with value `APP`, `SYSTEM`, `LIGHT` or `DARK`.

## Topics

### Style Configuration

- ``PWMedia/setRichMediaPresentationStyle(_:)``
- ``PWMedia/richMediaPresentationStyle()``

### Color Scheme

- ``PWMedia/setRichMediaColorScheme(_:)``
- ``PWMedia/richMediaColorScheme()``
- ``PWRichMediaColorScheme``

### Sub-interfaces

- ``PWMedia/modalRichMedia``
- ``PWMedia/legacyRichMedia``

## See Also

- ``Pushwoosh/debug``
- ``Pushwoosh/configure``
