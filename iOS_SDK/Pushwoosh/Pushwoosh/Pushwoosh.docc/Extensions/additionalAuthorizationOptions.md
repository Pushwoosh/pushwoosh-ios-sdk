# ``Pushwoosh/additionalAuthorizationOptions``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Additional notification authorization options beyond the SDK defaults.

## Overview

When the SDK calls `registerForPushNotifications`, it automatically requests these permissions:
- `.badge`
- `.sound`
- `.alert`
- `.carPlay`

Use `setAdditionalAuthorizationOptions` to request extra capabilities on top of the defaults. The options are combined (bitwise OR) with the defaults before being passed to `UNUserNotificationCenter.requestAuthorization(options:)`.

### Available Options

| Option | iOS | Description |
|--------|-----|-------------|
| `.provisional` | 12+ | Deliver notifications quietly without showing a permission dialog. Users see them in Notification Center and decide whether to keep or disable. |
| `.criticalAlert` | 12+ | Bypass Do Not Disturb and the mute switch. Requires a special entitlement from Apple. For medical, health, safety, and public security apps. |
| `.providesAppNotificationSettings` | 12+ | Adds a "Configure in App" button in the system notification settings. When tapped, iOS calls `userNotificationCenter(_:openSettingsFor:)` on your delegate. |
| `.announcement` | 13+ | Allows Siri to read notifications aloud through AirPods and compatible headphones. |

## Important

Call `setAdditionalAuthorizationOptions` **before** ``registerForPushNotifications()``. Options set after registration have no effect until the next authorization request.

## Provisional (Soft Opt-In)

Deliver notifications silently without prompting the user for permission. This is useful to demonstrate value before asking for full notification access:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if #available(iOS 12.0, *) {
        Pushwoosh.configure.setAdditionalAuthorizationOptions([.provisional])
    }

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

## In-App Notification Settings

Add a "Configure in App" button to the system Settings > Notifications screen for your app. When the user taps it, implement the `openSettingsFor` callback to navigate to your custom settings screen:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if #available(iOS 12.0, *) {
        Pushwoosh.configure.setAdditionalAuthorizationOptions([.providesAppNotificationSettings])
    }

    Pushwoosh.configure.addNotificationCenterDelegate(self)
    Pushwoosh.configure.registerForPushNotifications()

    return true
}

// Called when user taps "Configure in App" in system notification settings
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            openSettingsFor notification: UNNotification?) {
    // Navigate to your in-app notification settings screen
}
```

## Critical Alerts

For medical, health, and safety apps that need to bypass Do Not Disturb and the mute switch. Requires a special entitlement approved by Apple:

```swift
if #available(iOS 12.0, *) {
    Pushwoosh.configure.setAdditionalAuthorizationOptions([.criticalAlert])
}

Pushwoosh.configure.registerForPushNotifications()
```

## Combining Multiple Options

Options can be combined:

```swift
if #available(iOS 12.0, *) {
    Pushwoosh.configure.setAdditionalAuthorizationOptions([.provisional, .providesAppNotificationSettings])
}
```

Objective-C:

```objc
if (@available(iOS 12.0, *)) {
    [Pushwoosh.configure setAdditionalAuthorizationOptions:UNAuthorizationOptionProvisional | UNAuthorizationOptionProvidesAppNotificationSettings];
}

[Pushwoosh.configure registerForPushNotifications];
```

## See Also

- ``Pushwoosh/registerForPushNotifications()``
- ``PushwooshConfig/addNotificationCenterDelegate(_:)``
