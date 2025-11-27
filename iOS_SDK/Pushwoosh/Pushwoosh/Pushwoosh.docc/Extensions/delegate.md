# ``Pushwoosh/delegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate that receives push notification events.

## Overview

Set this property to receive callbacks when:
- Push notifications are received
- User taps on a push notification

The delegate must conform to ``PWMessagingDelegate`` protocol.

## Default Behavior

By default, Pushwoosh sets `AppDelegate` as the delegate if it conforms to `PWMessagingDelegate`. You can override this with any other object.

## Example

Set delegate in AppDelegate:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Use a dedicated notification handler:

```swift
class NotificationHandler: NSObject, PWMessagingDelegate {
    static let shared = NotificationHandler()

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
        NotificationCenter.default.post(
            name: .pushReceived,
            object: nil,
            userInfo: ["message": message]
        )
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
        DeepLinkRouter.shared.handle(message.customData)
    }
}

// In AppDelegate
Pushwoosh.configure.delegate = NotificationHandler.shared
```

## See Also

- ``PWMessagingDelegate``
- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``
- ``PWMessagingDelegate/pushwoosh(_:onMessageOpened:)``
