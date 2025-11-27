# Getting Started

Set up push notifications in your iOS application with Pushwoosh SDK.

## Overview

This guide walks through the steps to integrate Pushwoosh SDK into your iOS application and send your first push notification.

## Prerequisites

Before you begin, make sure you have:

- A Pushwoosh account and application created
- Apple Developer account with push notification certificate configured
- Xcode 14.0 or later
- iOS deployment target 11.0 or later

## Installation

@TabNavigator {
    @Tab("CocoaPods") {
        Add Pushwoosh to your `Podfile`:

        ```ruby
        pod 'PushwooshXCFramework'
        ```

        Then run:

        ```bash
        pod install
        ```
    }

    @Tab("Swift Package Manager") {
        In Xcode, use the following URL to add the Pushwoosh dependency:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```
    }
}

## Configuration

### 1. Import the SDK

@TabNavigator {
    @Tab("Swift") {
        ```swift
        import PushwooshFramework
        ```
    }

    @Tab("Objective-C") {
        ```objc
        #import <PushwooshFramework/PushwooshFramework.h>
        ```
    }
}

### 2. Initialize in AppDelegate

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

### 3. Handle Push Notifications

Implement `PWMessagingDelegate` to receive push notification events:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWMessagingDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Pushwoosh.configure.delegate = self
        Pushwoosh.configure.registerForPushNotifications()

        return true
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageReceived message: PWMessage) {
        print("Push notification received: \(message.payload)")
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
        print("Push notification opened: \(message.payload)")
    }
}
```

### 4. Add Push Notification Capability

In Xcode:
1. Select your target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Push Notifications"
5. Click "+ Capability" again
6. Add "Background Modes"
7. Check "Remote notifications" in Background Modes

## Send Your First Push

1. Go to Pushwoosh Control Panel
2. Navigate to your application
3. Click "Create Message"
4. Enter your notification content
5. Click "Send"

Your device should receive the push notification!

## Next Steps

- <doc:AdvancedIntegration> - Learn about advanced integration options
- Configure user segmentation with tags
- Set up rich media notifications
- Enable inbox functionality

## Troubleshooting

### Device Not Registered

Make sure:
- Push notification capability is enabled
- APNs certificate is correctly configured
- App has permission to receive notifications
- Device token is successfully sent to Pushwoosh

### Notifications Not Received

Check:
- Device is registered in Pushwoosh Control Panel
- Notification is sent to correct audience segment
- App is not in Do Not Disturb mode
- Enable SDK logging with `Pushwoosh.debug.setLogLevel(.PW_LL_VERBOSE)`
