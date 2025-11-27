# ``Pushwoosh/unregisterForPushNotifications(completion:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Unregisters the device from push notifications with a completion handler.

## Overview

Same as ``unregisterForPushNotifications()`` but provides a completion callback to confirm the operation finished.

Use this variant when you need to:
- Confirm unregistration before proceeding
- Show user feedback about the operation
- Handle errors during unregistration

## Example

Unregister on logout with confirmation:

```swift
func handleLogout(completion: @escaping (Bool) -> Void) {
    Pushwoosh.configure.setUserId("")

    Pushwoosh.configure.unregisterForPushNotifications { error in
        if let error = error {
            Analytics.log("unregister_failed", error: error)
            completion(false)
        } else {
            self.clearLocalUserData()
            completion(true)
        }
    }
}
```

Toggle push notifications in settings:

```swift
func togglePushNotifications(enabled: Bool, completion: @escaping (Bool) -> Void) {
    if enabled {
        Pushwoosh.configure.registerForPushNotifications { _, error in
            completion(error == nil)
        }
    } else {
        Pushwoosh.configure.unregisterForPushNotifications { error in
            completion(error == nil)
        }
    }
}
```

## See Also

- ``Pushwoosh/unregisterForPushNotifications()``
- ``Pushwoosh/registerForPushNotifications(completion:)``
