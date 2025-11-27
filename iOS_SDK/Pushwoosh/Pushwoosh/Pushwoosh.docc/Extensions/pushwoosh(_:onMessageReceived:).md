# ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Called when the application receives a push notification.

## Overview

This method is invoked when a push notification arrives, regardless of app state:
- **Foreground**: Called immediately when notification arrives
- **Background**: Called when system wakes your app to process the notification

Use this method to:
- Log notification receipt for analytics
- Update local data based on notification content
- Refresh UI if app is in foreground
- Trigger background data sync

## Foreground Behavior

When the app is in foreground, notifications are received but not displayed by default. Use ``Pushwoosh/showPushnotificationAlert`` to control this behavior.

## Example

Track notification receipt and update local data:

```swift
func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
    Analytics.log("push_received", [
        "campaign_id": message.customData?["campaign_id"] ?? "",
        "app_state": UIApplication.shared.applicationState.rawValue
    ])

    if let action = message.customData?["action"] as? String {
        switch action {
        case "refresh_orders":
            OrderManager.shared.refreshOrders()
        case "update_cart":
            CartManager.shared.syncWithServer()
        default:
            break
        }
    }
}
```

Show in-app notification banner when app is in foreground:

```swift
func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
    guard UIApplication.shared.applicationState == .active else { return }

    let banner = InAppNotificationBanner(
        title: message.title ?? "New Notification",
        message: message.message ?? ""
    )
    banner.show()
}
```

## See Also

- ``PWMessagingDelegate/pushwoosh(_:onMessageOpened:)``
- ``PWMessage``
- ``Pushwoosh/showPushnotificationAlert``
