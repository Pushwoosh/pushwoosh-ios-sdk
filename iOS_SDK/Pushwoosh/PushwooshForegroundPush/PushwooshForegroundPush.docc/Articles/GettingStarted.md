# Getting Started

Customize foreground push notifications when native iOS system alerts are disabled.

## Prerequisites

Before you begin, ensure you have:

- A Pushwoosh account
- A Pushwoosh project set up in your account
- An iOS platform configured in your Pushwoosh project. We recommend using the Token-Based Authentication configuration as the simplest approach
- Your Pushwoosh Application Code from the Control Panel
- iOS 14.0+ deployment target
- Pushwoosh SDK version 6.10.0 or higher
- PushwooshFramework, PushwooshCore, and PushwooshBridge frameworks integrated in your project

> **Important**: PushwooshForegroundPush requires the main Pushwoosh SDK to be properly configured for push notifications.

## Step 1: Disable Native Alerts

Add the following key to your `Info.plist` file to disable native iOS system alerts:

```xml
<key>Pushwoosh_SHOW_ALERT</key>
<false/>
```

This allows PushwooshForegroundPush to display custom foreground notifications instead of system alerts.

## Step 2: Install Module

@TabNavigator {
    @Tab("Swift Package Manager") {
        In Xcode, use the following URL to add the Pushwoosh dependency:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```

        Select the required modules in your target:

        ![Choose package products: PushwooshBridge, PushwooshCore, PushwooshFramework, PushwooshForegroundPush, and PushwooshLiveActivities](spm-foreground-push-selection.png)

        > **Important**: The modules PushwooshFramework, PushwooshCore, PushwooshBridge, PushwooshForegroundPush, and PushwooshLiveActivities are required.
    }

    @Tab("CocoaPods") {
        Add to your Podfile:

        ```ruby
        pod 'PushwooshXCFramework'
        pod 'PushwooshFramework/PushwooshForegroundPush'
        ```

        Then run:

        ```bash
        pod install
        ```
    }
}

## Step 3: Add Required Capabilities

In Xcode:

1. Select your target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **Push Notifications**
4. Click **+ Capability** and add **Background Modes**
5. In Background Modes, enable **Remote notifications** checkbox

![Required capabilities screenshot](capabilities-foreground-push.png)

## Step 4: Configure Foreground Push

Configure foreground push and set delegate in `application(_:didFinishLaunchingWithOptions:)`:

```swift
import UIKit
import PushwooshFramework
import PushwooshForegroundPush

@main
class AppDelegate: UIResponder, UIApplicationDelegate, PWForegroundPushDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.ForegroundPush.foregroundNotificationWith(
            style: .style1,
            duration: 5,
            vibration: .notification,
            disappearedPushAnimation: .balls
        )

        Pushwoosh.ForegroundPush.delegate = self

        return true
    }

    // MARK: - Push Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Pushwoosh.configure.handlePushRegistration(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - PWForegroundPushDelegate

    func didTapForegroundPush(_ userInfo: [AnyHashable: Any]) {
        print("Foreground custom push tapped: \(userInfo)")
    }
}
```

### Configuration Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `style` | `PWForegroundPushStyle` | Visual template for the notification. Currently only `.style1` is available |
| `duration` | `Int` | Display time in seconds |
| `vibration` | `PWForegroundPushHapticFeedback` | Haptic feedback type:<br>• `.none` – No vibration<br>• `.light` – Subtle feedback<br>• `.medium` – Standard feedback<br>• `.heavy` – Strong feedback<br>• `.soft` – Gentle feedback<br>• `.rigid` – Sharp feedback<br>• `.notification` – System notification feedback |
| `disappearedPushAnimation` | `PWForegroundPushDisappearedAnimation` | Exit animation:<br>• `.balls` – Explodes into particles<br>• `.regularPush` – Slides up and fades |

### Delegate Methods

The ``PWForegroundPushDelegate`` protocol provides callbacks for foreground push events:

| Method | Description |
|--------|-------------|
| `didTapForegroundPush(_:)` | Called when user taps on the foreground push notification |

## Customization

Configure appearance globally using static properties:

```swift
Pushwoosh.ForegroundPush.useLiquidView = true
Pushwoosh.ForegroundPush.gradientColors = [.red, .orange, .yellow]
Pushwoosh.ForegroundPush.titlePushColor = .red
Pushwoosh.ForegroundPush.messagePushColor = .white
Pushwoosh.ForegroundPush.usePushAnimation = false
```

### Available Properties

- `useLiquidView` - Enable Liquid Glass effect (requires iOS 26+ and Swift 5.13+)
- `gradientColors` - Custom gradient background colors
- `backgroundColor` - Solid background color
- `titlePushColor` - Text color for notification title
- `messagePushColor` - Text color for notification message
- `titlePushFont` - Custom font for title
- `messagePushFont` - Custom font for message
- `usePushAnimation` - Enable or disable show animation

## Platform Support

- **Liquid Glass effect**: Requires iOS 26+ and Swift 5.13+
- **Earlier iOS versions**: Display standard UIView-based notifications
- **Swift versions below 5.13**: Use blurred UIVisualEffectView instead of Liquid Glass

## Testing

To test your foreground push integration:

1. Verify `Pushwoosh_SHOW_ALERT` is set to `false` in Info.plist
2. Build and run your app on a physical device (push notifications don't work in Simulator)
3. Ensure the app has registered for push notifications successfully
4. Send a test push notification from Pushwoosh Control Panel
5. Keep your app in the foreground when the notification arrives
6. Verify the custom foreground push banner appears with the configured animation and haptic feedback
7. Tap the notification to verify the delegate method is called

> **Important**: If `Pushwoosh_SHOW_ALERT` is not set to `false`, native iOS alerts will be shown instead of custom foreground push notifications.

## Next Steps

- <doc:Examples> - Advanced customization with colors, fonts, and animations
- ``PushwooshForegroundPushImplementation`` - Full API reference
- ``PWForegroundPushDelegate`` - Delegate protocol reference
