# ``Pushwoosh/additionalAuthorizationOptions``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Additional authorization options for push notifications.

## Overview

Request additional notification capabilities beyond the defaults. The SDK automatically requests:
- `.badge`
- `.sound`
- `.alert`
- `.carPlay`

Use this property to add:
- `.provisional` - Deliver quietly without prompting (iOS 12+)
- `.criticalAlert` - Bypass Do Not Disturb (requires entitlement)
- `.announcement` - Siri announcement support (iOS 13+)

## Important

Set this property **before** calling ``registerForPushNotifications()``.

## Example

Request provisional authorization for soft opt-in:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if #available(iOS 12.0, *) {
        Pushwoosh.configure.additionalAuthorizationOptions = [.provisional]
    }

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Request critical alerts for medical app:

```swift
func setupNotifications() {
    if #available(iOS 12.0, *) {
        Pushwoosh.configure.additionalAuthorizationOptions = [.criticalAlert]
    }

    Pushwoosh.configure.registerForPushNotifications()
}
```

Request Siri announcement:

```swift
func setupNotificationsWithSiri() {
    if #available(iOS 13.0, *) {
        Pushwoosh.configure.additionalAuthorizationOptions = [.announcement]
    }

    Pushwoosh.configure.registerForPushNotifications()
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications()``
