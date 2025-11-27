# ``Pushwoosh/getPushToken()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Retrieves the current device push token.

## Overview

The push token (also known as device token) is a unique identifier assigned by Apple Push Notification service (APNs) to this specific app installation on this device. Pushwoosh uses this token to deliver push notifications.

Common use cases:
- Sending the token to your own backend for server-side push delivery
- Debugging push notification issues
- Verifying successful registration

## Availability

The push token becomes available only after:
1. User grants notification permission
2. Device successfully registers with APNs
3. Token is received from APNs

Before registration completes, this method returns `nil`.

## Example

Send push token to your backend for custom push delivery:

```swift
func registerDeviceWithBackend() {
    guard let pushToken = Pushwoosh.configure.getPushToken() else {
        return
    }

    let hwid = Pushwoosh.configure.getHWID()

    apiClient.registerDevice(
        pushToken: pushToken,
        hwid: hwid,
        platform: "ios"
    )
}
```

Check if device is registered for push notifications:

```swift
func isPushRegistered() -> Bool {
    return Pushwoosh.configure.getPushToken() != nil
}
```

## See Also

- ``Pushwoosh/getHWID()``
- ``Pushwoosh/registerForPushNotifications()``
- ``Pushwoosh/registerForPushNotifications(completion:)``
