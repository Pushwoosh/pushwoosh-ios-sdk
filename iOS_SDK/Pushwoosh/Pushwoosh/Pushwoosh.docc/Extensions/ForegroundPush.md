# ``Pushwoosh/ForegroundPush-type.property``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to custom foreground push notifications (the PushwooshForegroundPush module).

## Overview

With the PushwooshForegroundPush module linked and `Pushwoosh_SHOW_ALERT` set to `NO` in `Info.plist`, pushes that arrive while the app is in the foreground are shown as a custom in-app banner instead of the system alert.

Use this API to:
- Choose the banner style, display time, haptic feedback and exit animation
- Customize colors, fonts and the Liquid Glass effect (iOS 26+)
- Handle taps on the banner

## Example

Configure the banner at launch:

```swift
import PushwooshFramework
import PushwooshForegroundPush

func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.ForegroundPush.foregroundNotificationWith(
        style: .style1,
        duration: 5,
        vibration: .notification,
        disappearedPushAnimation: .balls
    )

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Customize the appearance and handle taps:

```swift
func setupForegroundNotifications() {
    Pushwoosh.ForegroundPush.gradientColors = [.systemIndigo, .systemPurple]
    Pushwoosh.ForegroundPush.titlePushColor = .white
    Pushwoosh.ForegroundPush.messagePushColor = .white

    Pushwoosh.ForegroundPush.didTapForegroundPush = { userInfo in
        print("Foreground push tapped: \(userInfo)")
    }
}
```

## See Also

- ``Pushwoosh/showPushnotificationAlert``
- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``
