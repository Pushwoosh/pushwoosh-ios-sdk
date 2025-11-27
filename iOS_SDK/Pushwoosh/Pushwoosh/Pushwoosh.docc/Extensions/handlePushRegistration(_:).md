# ``Pushwoosh/handlePushRegistration(_:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Manually handles the device push token registration.

## Overview

Forwards the APNs device token to Pushwoosh for push notification delivery.

## Automatic vs Manual Handling

The SDK handles token registration automatically in most cases. Use this method only when:
- Using custom push notification setup
- Integrating multiple push providers
- Implementing manual swizzling control

## Example

Standard AppDelegate implementation:

```swift
func application(_ application: UIApplication,
                didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Pushwoosh.configure.handlePushRegistration(deviceToken)
}
```

With multiple push providers:

```swift
func application(_ application: UIApplication,
                didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Pushwoosh.configure.handlePushRegistration(deviceToken)

    FirebaseMessaging.messaging().apnsToken = deviceToken

    OtherPushProvider.shared.registerToken(deviceToken)
}
```

## See Also

- ``Pushwoosh/handlePushRegistrationFailure(_:)``
- ``Pushwoosh/registerForPushNotifications()``
- ``Pushwoosh/getPushToken()``
