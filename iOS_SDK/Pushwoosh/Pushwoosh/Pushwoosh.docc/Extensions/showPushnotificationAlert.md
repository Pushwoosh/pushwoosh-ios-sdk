# ``Pushwoosh/showPushnotificationAlert``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Controls whether push notification alerts are shown when the app is in foreground.

## Overview

When the app is in foreground, iOS can either:
- Show the notification as a banner (default behavior)
- Deliver it silently to your app

This property controls that behavior.

## Values

- `true` (default): Show system notification banner
- `false`: Deliver silently to delegate methods only

## Use Cases

Set to `false` when you want to:
- Show custom in-app notification UI
- Handle notifications silently without interrupting user
- Implement custom notification presentation logic

## Example

Disable system alerts and show custom UI:

```swift
func setupPushwoosh() {
    Pushwoosh.configure.showPushnotificationAlert = false
    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()
}

func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
    guard UIApplication.shared.applicationState == .active else { return }

    showCustomNotificationBanner(
        title: message.title,
        body: message.message,
        data: message.customData
    )
}
```

Toggle based on user preference:

```swift
func updateForegroundNotificationSetting(showBanner: Bool) {
    Pushwoosh.configure.showPushnotificationAlert = showBanner

    userDefaults.set(showBanner, forKey: "showForegroundNotifications")
}
```

Disable during specific screens:

```swift
class VideoPlayerViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Pushwoosh.configure.showPushnotificationAlert = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Pushwoosh.configure.showPushnotificationAlert = true
    }
}
```

## See Also

- ``Pushwoosh/delegate``
- ``PWMessagingDelegate/pushwoosh(_:onMessageReceived:)``
