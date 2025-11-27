# ``Pushwoosh/launchNotification``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

The push notification payload that launched the app.

## Overview

Contains the notification payload if the app was launched by tapping a push notification. Returns `nil` if the app was launched normally.

Use this for:
- Cold start deep linking
- Handling notification actions on app launch
- Restoring state from notification data

## Timing

This property is available immediately after SDK initialization. Check it early in your app lifecycle to handle launch notifications.

## Example

Handle launch notification in AppDelegate:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    if let launchNotification = Pushwoosh.configure.launchNotification {
        handleLaunchNotification(launchNotification)
    }

    return true
}

func handleLaunchNotification(_ payload: [AnyHashable: Any]) {
    guard let customData = payload["u"] as? [String: Any],
          let screen = customData["screen"] as? String else {
        return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        DeepLinkRouter.shared.navigate(to: screen, params: customData)
    }
}
```

Check for launch notification in SceneDelegate:

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {

    if let launchNotification = Pushwoosh.configure.launchNotification {
        pendingDeepLink = extractDeepLink(from: launchNotification)
    }
}
```

## See Also

- ``Pushwoosh/delegate``
- ``PWMessagingDelegate/pushwoosh(_:onMessageOpened:)``
