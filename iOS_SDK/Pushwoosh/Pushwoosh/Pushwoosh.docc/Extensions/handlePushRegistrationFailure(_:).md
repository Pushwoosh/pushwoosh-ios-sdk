# ``Pushwoosh/handlePushRegistrationFailure(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Handles push notification registration failures.

## Overview

Notifies Pushwoosh when APNs registration fails. This enables:
- Error tracking and analytics
- Debugging registration issues
- Server-side error monitoring

## Common Failure Reasons

- Missing Push Notifications capability
- Invalid provisioning profile
- Simulator without push support
- Network connectivity issues
- APNs server unavailable

## Example

Standard AppDelegate implementation:

```swift
func application(_ application: UIApplication,
                didFailToRegisterForRemoteNotificationsWithError error: Error) {
    Pushwoosh.configure.handlePushRegistrationFailure(error as NSError)
}
```

With additional error logging:

```swift
func application(_ application: UIApplication,
                didFailToRegisterForRemoteNotificationsWithError error: Error) {
    Pushwoosh.configure.handlePushRegistrationFailure(error as NSError)

    Analytics.log("push_registration_failed", [
        "error": error.localizedDescription,
        "code": (error as NSError).code
    ])

    #if DEBUG
    print("Push registration failed: \(error)")
    #endif
}
```

## See Also

- ``Pushwoosh/handlePushRegistration(_:)``
- ``Pushwoosh/registerForPushNotifications()``
