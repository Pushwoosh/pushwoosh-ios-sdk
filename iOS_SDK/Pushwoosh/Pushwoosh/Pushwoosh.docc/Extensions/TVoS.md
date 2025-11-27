# ``Pushwoosh/TVoS``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

Provides access to tvOS-specific functionality.

## Overview

APIs for Apple TV applications. Use this when building tvOS targets to handle push notifications on Apple TV devices.

## Platform Availability

This property is only available when building for tvOS targets.

## Example

Handle tvOS notifications:

```swift
#if os(tvOS)
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.delegate = self
    Pushwoosh.configure.registerForPushNotifications()

    return true
}

func application(_ application: UIApplication,
                didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    Pushwoosh.TVoS.handleTVOSNotification(userInfo)
}
#endif
```

## See Also

- ``Pushwoosh/configure``
- ``Pushwoosh/registerForPushNotifications()``
