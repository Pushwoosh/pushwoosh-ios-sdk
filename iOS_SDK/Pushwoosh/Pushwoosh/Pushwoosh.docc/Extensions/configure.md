# ``Pushwoosh/configure``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to SDK configuration methods.

## Overview

The primary entry point for all Pushwoosh SDK operations. Use this property to:
- Register for push notifications
- Set user data and tags
- Configure delegates
- Manage SDK settings

## Usage

All SDK methods are accessed through this property:

```swift
// Registration
Pushwoosh.configure.registerForPushNotifications()

// User identification
Pushwoosh.configure.setUserId("user_123")
Pushwoosh.configure.setEmail("user@example.com")

// Tags
Pushwoosh.configure.setTags(["isPremium": true])

// Delegates
Pushwoosh.configure.delegate = self
```

## Example

Complete app setup:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.showPushnotificationAlert = true

    if userDefaults.bool(forKey: "onboardingComplete") {
        Pushwoosh.configure.registerForPushNotifications()
    }

    return true
}
```

## See Also

- ``Pushwoosh/sharedInstance()``
- ``Pushwoosh/registerForPushNotifications()``
- ``Pushwoosh/delegate``
