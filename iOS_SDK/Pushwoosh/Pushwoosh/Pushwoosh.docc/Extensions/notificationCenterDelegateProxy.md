# ``Pushwoosh/notificationCenterDelegateProxy``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Proxy that manages UNUserNotificationCenterDelegate objects.

## Overview

Allows multiple objects to receive `UNUserNotificationCenterDelegate` callbacks alongside Pushwoosh's default handling. Use this when:
- Integrating multiple push notification SDKs
- Adding custom notification handling logic
- Implementing notification actions

## How It Works

The proxy forwards all delegate methods to registered delegates, enabling multiple components to respond to notification events without conflicts.

## Example

Add custom notification delegate:

```swift
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Analytics.log("notification_will_present")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        handleNotificationAction(response.actionIdentifier)
        completionHandler()
    }
}

// Register with proxy
let handler = NotificationHandler()
Pushwoosh.configure.notificationCenterDelegateProxy.addDelegate(handler)
```

## See Also

- ``Pushwoosh/delegate``
- ``PWMessagingDelegate``
