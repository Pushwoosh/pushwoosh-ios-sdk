# ``Pushwoosh/unregisterForPushNotifications()-9o2u``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Unregisters the device from push notifications.

## Overview

This method:
1. Notifies Pushwoosh servers to stop sending push notifications to this device
2. Removes the device token from Pushwoosh

The device will no longer receive push notifications through Pushwoosh until ``Pushwoosh/registerForPushNotifications()-9g5uw`` is called again.

## Use Cases

- User logs out of the app
- User disables notifications in app settings
- GDPR/privacy compliance requests

## Important

This method only unregisters from Pushwoosh. The device may still receive push notifications from other providers if registered separately.

## Example

Unregister when user logs out:

```swift
func handleLogout() {
    Pushwoosh.configure.resetUserId()
    Pushwoosh.configure.unregisterForPushNotifications(completion: nil)

    clearLocalUserData()
    navigateToLogin()
}
```

## See Also

- ``Pushwoosh/unregisterForPushNotifications()-80mv5``
- ``Pushwoosh/registerForPushNotifications()-9g5uw``
