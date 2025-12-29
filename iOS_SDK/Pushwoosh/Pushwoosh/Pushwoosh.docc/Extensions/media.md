# ``Pushwoosh/media``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to Rich Media presentation configuration.

## Overview

Use this property to configure how Rich Media content is displayed. You can choose between modal presentation with customizable animations or legacy full-screen presentation.

Available presentation styles:
- `.modal` - Modal window with customizable position, animations, and swipe-to-dismiss
- `.legacy` - Legacy full-screen presentation

Access style-specific configuration via `modalRichMedia` or `legacyRichMedia` sub-interfaces:
- `Pushwoosh.media.modalRichMedia` - Modal-specific settings (position, animations, corners, haptic feedback, delegate)
- `Pushwoosh.media.legacyRichMedia` - Legacy-specific settings (delegate)

The presentation style is persisted across app launches. If you remove the configuration from your code, it reverts to Info.plist settings on the next launch.

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

Configure via Info.plist instead of code:

Add `Pushwoosh_RICH_MEDIA_STYLE` key with value `MODAL_RICH_MEDIA` or `LEGACY_RICH_MEDIA`.

## Topics

### Style Configuration

- ``PWMedia/setRichMediaPresentationStyle(_:)``
- ``PWMedia/richMediaPresentationStyle()``

### Sub-interfaces

- ``PWMedia/modalRichMedia``
- ``PWMedia/legacyRichMedia``

## See Also

- ``Pushwoosh/debug``
- ``Pushwoosh/configure``
