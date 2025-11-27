# ``Pushwoosh/handlePushReceived(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Handles received push notifications.

## Overview

Manually processes a push notification payload. The SDK handles this automatically in most cases.

## When to Use

- Custom notification handling flow
- Processing notifications from multiple providers
- Background fetch implementations
- Testing and debugging

## Return Value

Returns `true` if the notification was a Pushwoosh notification and was processed, `false` if it was from another provider.

## Example

Handle notifications in AppDelegate:

```swift
func application(_ application: UIApplication,
                didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

    let handled = Pushwoosh.configure.handlePushReceived(userInfo)

    if handled {
        completionHandler(.newData)
    } else {
        handleOtherPushProvider(userInfo, completion: completionHandler)
    }
}
```

Route notifications to correct handler:

```swift
func routeNotification(_ userInfo: [AnyHashable: Any]) {
    if Pushwoosh.configure.handlePushReceived(userInfo) {
        return
    }

    if let firebaseData = userInfo["gcm.message_id"] {
        FirebaseHandler.handle(userInfo)
        return
    }

    CustomNotificationHandler.handle(userInfo)
}
```

## See Also

- ``Pushwoosh/delegate``
- ``PWMessagingDelegate``
- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``
