# ``PushwooshConfig``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Configuration interface for the Pushwoosh SDK.

## Overview

`PushwooshConfig` provides static methods for SDK configuration. Access all methods through `Pushwoosh.configure`.

## Configuration Categories

### Registration
- `registerForPushNotifications()`
- `unregisterForPushNotifications()`

### User Identity
- `setUserId(_:)`
- `setEmail(_:)`
- `setTags(_:)`

### Device Info
- `getHWID()`
- `getPushToken()`
- `getUserId()`

### Delegates
- `delegate`
- `purchaseDelegate`

## Example

Complete setup example:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWMessagingDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Pushwoosh.configure.delegate = self
        Pushwoosh.configure.showPushnotificationAlert = true
        Pushwoosh.configure.registerForPushNotifications()

        return true
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
        handleDeepLink(from: message)
    }
}
```

## See Also

- ``PWConfiguration``
- ``Pushwoosh/configure``
