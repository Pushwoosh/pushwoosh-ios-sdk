# ``PWMedia/legacyRichMedia``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to legacy Rich Media configuration.

## Overview

Use this property to configure legacy-specific settings such as the delegate.

Legacy configuration applies when the presentation style is set to `.legacy`.

The legacy presentation style displays Rich Media content in full-screen mode, similar to the original Pushwoosh Rich Media implementation.

## Example

Configure legacy Rich Media with delegate:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.media.setRichMediaPresentationStyle(.legacy)
    Pushwoosh.media.legacyRichMedia.delegate = self

    Pushwoosh.configure.registerForPushNotifications()
    return true
}
```

Handle Rich Media lifecycle events:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWRichMediaPresentingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Pushwoosh.media.legacyRichMedia.delegate = self
        return true
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          shouldPresent richMedia: PWRichMedia) -> Bool {
        return !userIsInCheckout
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          didPresent richMedia: PWRichMedia) {
        Analytics.log("rich_media_shown", code: richMedia.code)
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          didClose richMedia: PWRichMedia) {
        Analytics.log("rich_media_closed", code: richMedia.code)
    }

    func richMediaManager(_ richMediaManager: PWRichMediaManager,
                          presentingDidFailFor richMedia: PWRichMedia,
                          withError error: Error) {
        Analytics.log("rich_media_failed", error: error)
    }
}
```

## Topics

### Delegate

- ``PWLegacyRichMedia/delegate``
- ``PWLegacyRichMedia/setDelegate(_:)``

## See Also

- ``Pushwoosh/media``
- ``PWMedia/modalRichMedia``
