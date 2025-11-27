# ``Pushwoosh/registerForPushNotifications()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Registers the device for push notifications.

## Overview

This method initiates the push notification registration process:
1. Requests user permission to display notifications
2. Registers the device with Apple Push Notification service (APNs)
3. Sends the device token to Pushwoosh servers

## Permission Dialog

The system permission dialog is shown only once per app installation. If the user:
- **Grants permission**: Device receives a push token from APNs
- **Denies permission**: No token is received; user must enable notifications in Settings

## When to Call

Call this method:
- In `application(_:didFinishLaunchingWithOptions:)` for immediate registration
- After onboarding flow to explain notification benefits first
- When user explicitly enables notifications in your app settings

## Example

Register for push notifications at app launch:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

Register after user completes onboarding:

```swift
func completeOnboarding() {
    userDefaults.set(true, forKey: "onboardingComplete")

    Pushwoosh.configure.registerForPushNotifications()

    navigateToMainScreen()
}
```

Prompt user before requesting permission:

```swift
func showNotificationPrompt() {
    let alert = UIAlertController(
        title: "Stay Updated",
        message: "Enable notifications to receive order updates and exclusive offers",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Enable", style: .default) { _ in
        Pushwoosh.configure.registerForPushNotifications()
    })

    alert.addAction(UIAlertAction(title: "Later", style: .cancel))

    present(alert, animated: true)
}
```

## See Also

- ``Pushwoosh/registerForPushNotifications(completion:)``
- ``Pushwoosh/unregisterForPushNotifications()``
- ``Pushwoosh/delegate``
- ``PWMessagingDelegate``
