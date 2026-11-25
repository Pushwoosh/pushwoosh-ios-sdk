# ``PWMedia-c.protocol/modalRichMedia``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to modal Rich Media configuration.

## Overview

Use this property to configure modal-specific settings such as window position, animations, haptic feedback, corner radius, and delegate.

Modal configuration only applies when the presentation style is set to `.modal`.

Available configuration options:
- Window position (top, center, bottom, bottom sheet, full screen)
- Present and dismiss animations
- Swipe-to-dismiss directions
- Haptic feedback on presentation
- Corner radius
- Auto-dismiss timer
- Rich Media lifecycle delegate

## Example

Configure a bottom sheet modal with swipe-to-dismiss:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.media.setRichMediaPresentationStyle(.modal)

    Pushwoosh.media.modalRichMedia.configure(
        with: .PWModalWindowPositionBottom,
        present: .PWAnimationPresentSlideUp,
        dismiss: .PWAnimationDismissSlideDown
    )

    Pushwoosh.media.modalRichMedia.setDismissSwipeDirections([
        NSNumber(value: DismissSwipeDirection.PWSwipeDismissDown.rawValue)
    ])

    Pushwoosh.media.modalRichMedia.setCornerType([.PWCornerTypeTopLeft, .PWCornerTypeTopRight], withRadius: 16)

    Pushwoosh.media.modalRichMedia.setHapticFeedbackType(.PWHapticFeedbackMedium)
    Pushwoosh.media.modalRichMedia.delegate = self

    Pushwoosh.configure.registerForPushNotifications()
    return true
}
```

Configure a centered popup with auto-dismiss:

```swift
func setupCenteredRichMedia() {
    Pushwoosh.media.setRichMediaPresentationStyle(.modal)

    Pushwoosh.media.modalRichMedia.configure(
        with: .PWModalWindowPositionCenter,
        present: .PWAnimationPresentFadeIn,
        dismiss: .PWAnimationDismissFadeOut
    )

    Pushwoosh.media.modalRichMedia.setCornerType(
        [.PWCornerTypeTopLeft, .PWCornerTypeTopRight, .PWCornerTypeBottomLeft, .PWCornerTypeBottomRight],
        withRadius: 12
    )

    Pushwoosh.media.modalRichMedia.close(after: 10)
}
```

Handle Rich Media lifecycle events:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWRichMediaPresentingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Pushwoosh.media.modalRichMedia.delegate = self
        return true
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          shouldPresent richMedia: PWRichMedia) -> Bool {
        return !userIsInCheckout
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          didPresent richMedia: PWRichMedia) {
        Analytics.log("rich_media_shown", payload: richMedia.pushPayload)
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          didClose richMedia: PWRichMedia) {
        Analytics.log("rich_media_closed", payload: richMedia.pushPayload)
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          presentingDidFailFor richMedia: PWRichMedia,
                          withError error: Error) {
        Analytics.log("rich_media_failed", error: error)
    }
}
```

## Topics

### Window Configuration

- ``PWModalRichMedia-c.protocol/configureWithPosition:presentAnimation:dismissAnimation:``
- ``PWModalRichMedia-c.protocol/setDismissSwipeDirections:``
- ``PWModalRichMedia-c.protocol/setCornerType:withRadius:``
- ``PWModalRichMedia-c.protocol/setHapticFeedbackType:``
- ``PWModalRichMedia-c.protocol/closeAfter:``

### Delegate

- ``PWModalRichMedia-c.protocol/getDelegate``
- ``PWModalRichMedia-c.protocol/setDelegate:``

## See Also

- ``PWMedia-c.protocol/legacyRichMedia``
