# ``Pushwoosh/setUserId(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Associates a unique identifier with the current device.

## Overview

Set a user identifier to track the same user across multiple devices. This enables:
- Cross-device push notification targeting (send to all user's devices)
- User-level analytics and reporting
- Data merging when users switch devices

The user ID can be any unique string: database ID, email, username, Firebase UID, etc.

## When to Call

Call this method after user authentication:
- After successful login
- After account creation
- When restoring a session

## Example

Set user ID after successful login:

```swift
func handleLoginSuccess(user: User) {
    Pushwoosh.configure.setUserId(user.id)
    Pushwoosh.configure.setEmail(user.email)

    let tags: [String: Any] = [
        "subscription_tier": user.subscriptionTier,
        "account_created": user.createdAt
    ]
    Pushwoosh.configure.setTags(tags)
}
```

Clear user ID on logout (reset to HWID):

```swift
func handleLogout() {
    Pushwoosh.configure.setUserId("")

    Pushwoosh.configure.unregisterForPushNotifications { _ in
        self.navigateToLogin()
    }
}
```

## See Also

- ``Pushwoosh/setUserId(_:completion:)``
- ``Pushwoosh/getUserId()``
- ``Pushwoosh/setEmail(_:)``
- ``Pushwoosh/mergeUserId(_:to:doMerge:completion:)``
