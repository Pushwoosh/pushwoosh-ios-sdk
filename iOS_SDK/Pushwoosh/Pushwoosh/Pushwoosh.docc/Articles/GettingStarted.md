# Getting Started

Set up push notifications in your iOS application with Pushwoosh SDK.

## Overview

This guide walks through the steps to integrate Pushwoosh SDK into your iOS application and send your first push notification.

## Prerequisites

Before you begin, make sure you have:

- A Pushwoosh account and application created
- Apple Developer account with push notification certificate configured
- Xcode 14.0 or later
- iOS deployment target 15.0 or later

## Installation

@TabNavigator {
    @Tab("CocoaPods") {
        Add Pushwoosh to your `Podfile`, for the app and for the Notification Service Extension target (step 6):

        ```ruby
        target 'YourApp' do
          pod 'PushwooshXCFramework'
        end

        target 'NotificationService' do
          pod 'PushwooshXCFramework'
        end
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

        Add PushwooshFramework, PushwooshCore and PushwooshBridge to the app target and to the Notification Service Extension target (step 6).
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

### 2. Add Info.plist Keys

Add your Application Code and Device API Token (Pushwoosh Control Panel → API Access) to the app's `Info.plist`:

```xml
<key>Pushwoosh_APPID</key>
<string>XXXXX-XXXXX</string>
<key>Pushwoosh_API_TOKEN</key>
<string>YOUR-DEVICE-API-TOKEN</string>
```

### 3. Initialize in AppDelegate

The SDK is called through ``Pushwoosh/configure-type.property`` and the module accessors (`Pushwoosh.media`, `Pushwoosh.inbox`, `Pushwoosh.LiveActivities` and others).

```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Pushwoosh.configure.registerForPushNotifications()

    return true
}
```

### 4. Handle Push Notifications

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
        print("Push notification received: \(message.payload ?? [:])")
    }

    func pushwoosh(_ pushwoosh: Pushwoosh, onMessageOpened message: PWMessage) {
        print("Push notification opened: \(message.payload ?? [:])")
    }
}
```

### 5. Add Push Notification Capability

In Xcode:
1. Select your target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Push Notifications"
5. Click "+ Capability" again
6. Add "Background Modes"
7. Check "Remote notifications" in Background Modes

### 6. Add a Notification Service Extension and an App Group

This step is required. The message delivery event is sent only by the Notification Service Extension, so without it pushes are shown but never counted as delivered. The extension also applies the badge and downloads media attachments, and it shares data with the app through an App Group.

1. Choose File → New → Target → Notification Service Extension.
2. Link PushwooshFramework, PushwooshCore and PushwooshBridge to the extension target.
3. Make the extension class a subclass of ``PushwooshNotificationServiceExtension``:

```swift
import PushwooshFramework

class NotificationService: PushwooshNotificationServiceExtension {}
```

4. Add the App Groups capability with the same group to the app target and to the extension target.
5. Set that group as `PW_APP_GROUPS_NAME` in the `Info.plist` of the app and of the extension:

```xml
<key>PW_APP_GROUPS_NAME</key>
<string>group.com.example.app</string>
```

6. Leave `Pushwoosh_APPID` out of the extension's `Info.plist`: the extension inherits it from the app.
7. Send pushes with `mutable-content: 1` in `aps`, otherwise iOS does not start the extension.

How the delivery event is sent and what the App Group carries: <doc:AdvancedIntegration#Delivery-Event>.

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

### Delivery Not Counted

Check:
- The Notification Service Extension subclasses ``PushwooshNotificationServiceExtension`` and is embedded in the app
- The push carries `mutable-content: 1`
- The app and the extension have the same App Group and the same `PW_APP_GROUPS_NAME`
- The extension's console log has no `messageDeliveryEvent skipped:` line; if it does, the line names the missing setting

### Notifications Not Received

Check:
- Device is registered in Pushwoosh Control Panel
- Notification is sent to correct audience segment
- App is not in Do Not Disturb mode
- Enable SDK logging with `Pushwoosh.debug.setLogLevel(.PW_LL_VERBOSE)`
