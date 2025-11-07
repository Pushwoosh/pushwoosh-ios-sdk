# Examples

Code samples demonstrating common tvOS integration scenarios.

## Overview

This page provides ready-to-use code examples for integrating Pushwoosh into your tvOS application. Examples cover basic setup, Rich Media configuration, custom push handling, and advanced scenarios.

## Basic Setup

### Minimal AppDelegate Setup

The simplest way to integrate Pushwoosh into your tvOS app:

```swift
import UIKit
import Pushwoosh
import PushwooshTVOS

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")

        // Register for push notifications
        Pushwoosh.TVoS.registerForTvPushNotifications()

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Pushwoosh.TVoS.handleTvPushToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Pushwoosh.TVoS.handleTvPushRegistrationFailure(error)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Pushwoosh.TVoS.handleTvPushReceived(userInfo: userInfo, completionHandler: completionHandler)
    }
}
```

## Rich Media Configuration

### Center Position with Bottom Animation

Display Rich Media in the center with slide-in animation from bottom:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")

    // Configure Rich Media
    Pushwoosh.TVoS.configureRichMediaWith(
        position: .center,
        presentAnimation: .fromBottom,
        dismissAnimation: .toBottom
    )

    Pushwoosh.TVoS.configureCloseButton(true)
    Pushwoosh.TVoS.registerForTvPushNotifications()

    return true
}
```

### Left Side Panel

Display Rich Media as a left-side panel:

```swift
Pushwoosh.TVoS.configureRichMediaWith(
    position: .left,
    presentAnimation: .fromLeft,
    dismissAnimation: .toLeft
)
```

### Top Banner

Display Rich Media as a top banner with slide-down animation:

```swift
Pushwoosh.TVoS.configureRichMediaWith(
    position: .top,
    presentAnimation: .fromTop,
    dismissAnimation: .toTop
)
```

### No Close Button

Hide the Close button if your Rich Media has custom dismiss logic:

```swift
Pushwoosh.TVoS.configureRichMediaWith(
    position: .center,
    presentAnimation: .fromBottom,
    dismissAnimation: .toBottom
)

Pushwoosh.TVoS.configureCloseButton(false)
```

## Custom Push Handling

### Selective Rich Media Display

Display Rich Media only for specific push types:

```swift
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

    // Check if push contains Rich Media
    if let rm = userInfo["rm"] as? [String: Any],
       let url = rm["url"] as? String {

        // Check URL or other criteria
        if url.contains("special-offer") {
            // Display Rich Media
            if Pushwoosh.TVoS.handleTVOSPush(userInfo: userInfo) {
                completionHandler(.newData)
                return
            }
        }
    }

    // Handle as regular push
    Pushwoosh.TVoS.handleTvPushReceived(userInfo: userInfo, completionHandler: completionHandler)
}
```

## Registration with Completion Handler

Register with device token and handle success/failure:

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Pushwoosh.TVoS.registerForTvPushNotifications(withToken: deviceToken) { error in
        if let error = error {
            print("Failed to register: \(error.localizedDescription)")
        } else {
            print("Successfully registered for push notifications")
        }
    }
}
```

## Unregister from Push Notifications

Unregister the device from receiving push notifications:

```swift
Pushwoosh.TVoS.unregisterForTvPushNotifications { error in
    if let error = error {
        print("Failed to unregister: \(error.localizedDescription)")
    } else {
        print("Successfully unregistered from push notifications")
    }
}
```

## getTags Handler

Handle tags retrieved from Rich Media:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")

    // Set getTags handler
    Pushwoosh.TVoS.setRichMediaGetTagsHandler { tags in
        print("Received tags from Rich Media:")
        for (key, value) in tags {
            print("  \(key): \(value)")
        }
    }

    Pushwoosh.TVoS.registerForTvPushNotifications()

    return true
}
```

## See Also

- <doc:GettingStarted>
- <doc:HTMLGuide>
- ``PushwooshTVOSImplementation``
- ``PWTVOSRichMediaManager``
- ``PWTVOSRichMediaPosition``
- ``PWTVOSRichMediaPresentAnimation``
- ``PWTVOSRichMediaDismissAnimation``
