# ``PWMessagingDelegate``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Delegate protocol for handling push notification events.

## Overview

Implement `PWMessagingDelegate` to respond to push notification lifecycle events:
- **Received**: Notification arrived (app may be in foreground or background)
- **Opened**: User tapped on the notification

Both methods provide a ``PWMessage`` object containing the notification payload, custom data, and metadata.

## Implementation

1. Conform to the protocol
2. Set the delegate on Pushwoosh
3. Implement the methods you need

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWMessagingDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Pushwoosh.configure.delegate = self
        Pushwoosh.configure.registerForPushNotifications()

        return true
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
        Analytics.log("push_received", [
            "title": message.title ?? "",
            "customData": message.customData ?? [:]
        ])
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
        handleDeepLink(from: message)
    }

    private func handleDeepLink(from message: PWMessage) {
        guard let customData = message.customData,
              let screen = customData["screen"] as? String else {
            return
        }

        switch screen {
        case "order":
            if let orderId = customData["order_id"] as? String {
                navigateToOrder(orderId)
            }
        case "promo":
            if let promoId = customData["promo_id"] as? String {
                navigateToPromo(promoId)
            }
        default:
            break
        }
    }
}
```

## Topics

### Handling Notifications

- ``pushwoosh(_:onMessageReceived:)``
- ``pushwoosh(_:onMessageOpened:)``
