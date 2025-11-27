# ``Pushwoosh/ForegroundPush``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to custom foreground push notification handling.

## Overview

Controls how push notifications are displayed when your app is in the foreground. By default, iOS may not display notifications while the app is active.

Use this API to:
- Show notification banners while app is active
- Customize presentation options (banner, sound, badge)
- Implement custom foreground notification UI

## Example

Show all notifications in foreground:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.ForegroundPush.setCustomForegroundPresentationOptions([.banner, .sound, .badge])

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Show only banner and sound:

```swift
func setupForegroundNotifications() {
    Pushwoosh.ForegroundPush.setCustomForegroundPresentationOptions([.banner, .sound])
}
```

## See Also

- ``Pushwoosh/showPushnotificationAlert``
- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``
