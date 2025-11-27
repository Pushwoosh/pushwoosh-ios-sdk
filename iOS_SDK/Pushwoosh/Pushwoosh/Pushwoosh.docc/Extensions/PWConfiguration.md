# ``PWConfiguration``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Protocol defining SDK configuration methods.

## Overview

`PWConfiguration` defines all methods for configuring the Pushwoosh SDK. Implemented by ``PushwooshConfig`` and accessed via `Pushwoosh.configure`.

## Key Capabilities

- **Registration**: Register/unregister for push notifications
- **User Identity**: Set user ID, email, phone numbers
- **Tags**: Set and retrieve user tags for segmentation
- **Configuration**: App code, delegates, proxy settings
- **Communication**: Start/stop server communication

## Example

Typical SDK setup:

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}

func handleLogin(user: User) {
    Pushwoosh.configure.setUserId(user.id)
    Pushwoosh.configure.setEmail(user.email)
    Pushwoosh.configure.setTags([
        "subscription": user.subscriptionTier,
        "lastLogin": Date()
    ])
}
```

## See Also

- ``PushwooshConfig``
- ``Pushwoosh/configure``
