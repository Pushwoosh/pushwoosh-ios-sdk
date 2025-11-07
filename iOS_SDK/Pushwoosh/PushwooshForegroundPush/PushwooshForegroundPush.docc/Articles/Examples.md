# Code Examples

Practical examples for common foreground push notification scenarios.

## Overview

This guide provides working code examples for customizing PushwooshForegroundPush appearance, animations, and user interactions.

## Basic Setup

### Minimal Configuration

The simplest configuration with default appearance:

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

    func didTapForegroundPush(_ userInfo: [AnyHashable: Any]) {
        print("Foreground custom push: \(userInfo)")
    }
}
```

## Appearance Customization

### Custom Gradient Background

Create a vibrant gradient background with custom text colors:

```swift
Pushwoosh.ForegroundPush.gradientColors = [.red, .orange, .yellow]
Pushwoosh.ForegroundPush.titlePushColor = .white
Pushwoosh.ForegroundPush.messagePushColor = .white
```

![Foreground push with custom gradient and text colors](ios-foreground-custom-3.gif)

### Solid Background Color

Use a solid color instead of gradient:

```swift
Pushwoosh.ForegroundPush.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
Pushwoosh.ForegroundPush.gradientColors = nil
```

### Custom Fonts

Use custom fonts for title and message:

```swift
Pushwoosh.ForegroundPush.backgroundColor = .systemPurple
Pushwoosh.ForegroundPush.titlePushFont = UIFont(name: "YourCustomFont-Bold", size: 18)
Pushwoosh.ForegroundPush.messagePushFont = UIFont(name: "YourCustomFont-Regular", size: 15)
Pushwoosh.ForegroundPush.titlePushColor = .white
Pushwoosh.ForegroundPush.messagePushColor = .white
```

![Foreground push with custom background and fonts](ios-foreground-custom-4.gif)

## Rich Media Support

### Push with Image Attachment

Foreground push notifications support image attachments:

![Foreground push with card image attachment](ios-foreground-custom-2.gif)

### Push with GIF Attachment

Animated GIF images are supported:

![Foreground push with animated GIF](ios-foreground-custom-1.gif)

The attachment URL is specified in the push notification payload. The SDK automatically downloads and displays the media content.

## Animation Customization

### Disable Entry Animation

Show push instantly without slide animation:

```swift
Pushwoosh.ForegroundPush.usePushAnimation = false
```

![Foreground push with no animation](ios-foreground-custom-4.gif)

### Particle Explosion Effect

Use particle explosion when push disappears:

```swift
Pushwoosh.ForegroundPush.foregroundNotificationWith(
    style: .style1,
    duration: 5,
    vibration: .notification,
    disappearedPushAnimation: .balls
)
```

### Regular Push Animation

Use standard upward slide animation:

```swift
Pushwoosh.ForegroundPush.foregroundNotificationWith(
    style: .style1,
    duration: 5,
    vibration: .notification,
    disappearedPushAnimation: .regularPush
)
```

### Liquid Glass Effect (iOS 26+)

Enable modern Liquid Glass visual effect:

```swift
Pushwoosh.ForegroundPush.useLiquidView = true
```

![Foreground push with Liquid Glass effect](ios-foreground-custom-5.gif)

> **Important**: Liquid Glass requires iOS 26+ and Swift 5.13+. On earlier iOS versions, standard UIView-based notifications are displayed. Swift versions below 5.13 use blurred UIVisualEffectView.

## Haptic Feedback Options

### No Vibration

For silent notifications:

```swift
Pushwoosh.ForegroundPush.foregroundNotificationWith(
    style: .style1,
    duration: 5,
    vibration: .none,
    disappearedPushAnimation: .balls
)
```

### Strong Haptic

For important notifications:

```swift
Pushwoosh.ForegroundPush.foregroundNotificationWith(
    style: .style1,
    duration: 7,
    vibration: .heavy,
    disappearedPushAnimation: .balls
)
```

### System Notification Haptic

Use system notification-style haptic:

```swift
Pushwoosh.ForegroundPush.foregroundNotificationWith(
    style: .style1,
    duration: 5,
    vibration: .notification,
    disappearedPushAnimation: .balls
)
```

## Handling User Interactions

### Implementing Delegate

Handle user taps through the delegate method:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, PWForegroundPushDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Pushwoosh.ForegroundPush.delegate = self
        return true
    }

    func didTapForegroundPush(_ userInfo: [AnyHashable: Any]) {
        print("Foreground custom push tapped: \(userInfo)")

        if let customData = userInfo["custom"] as? [String: Any],
           let screenId = customData["screen_id"] as? String {
            navigateToScreen(screenId)
        }
    }
}
```

### Deep Link Handling

Handle deep links from push notifications:

```swift
func didTapForegroundPush(_ userInfo: [AnyHashable: Any]) {
    if let deepLink = userInfo["deep_link"] as? String,
       let url = URL(string: deepLink) {
        UIApplication.shared.open(url, options: [:]) { success in
            print("Deep link opened: \(success)")
        }
    }
}
```

## Complete Custom Setup

### Branded Notification

Full customization with brand identity:

```swift
func configureBrandedForegroundPush() {
    Pushwoosh.ForegroundPush.gradientColors = [
        UIColor(red: 0.18, green: 0.31, blue: 0.64, alpha: 1.0),
        UIColor(red: 0.44, green: 0.26, blue: 0.63, alpha: 1.0)
    ]

    Pushwoosh.ForegroundPush.titlePushColor = .white
    Pushwoosh.ForegroundPush.messagePushColor = UIColor(white: 0.95, alpha: 1.0)

    Pushwoosh.ForegroundPush.titlePushFont = UIFont(name: "Helvetica-Bold", size: 18)
    Pushwoosh.ForegroundPush.messagePushFont = UIFont(name: "Helvetica", size: 15)

    Pushwoosh.ForegroundPush.usePushAnimation = true
    Pushwoosh.ForegroundPush.useLiquidView = true

    Pushwoosh.ForegroundPush.foregroundNotificationWith(
        style: .style1,
        duration: 6,
        vibration: .notification,
        disappearedPushAnimation: .balls
    )

    Pushwoosh.ForegroundPush.delegate = self
}
```

## Dark Mode Support

### Adaptive Colors

Adjust colors based on user interface style:

```swift
func configureForegroundPushColors() {
    if #available(iOS 13.0, *) {
        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark

        if isDarkMode {
            Pushwoosh.ForegroundPush.gradientColors = [
                UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
                UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
            ]
            Pushwoosh.ForegroundPush.titlePushColor = .white
            Pushwoosh.ForegroundPush.messagePushColor = UIColor(white: 0.85, alpha: 1.0)
        } else {
            Pushwoosh.ForegroundPush.gradientColors = [
                UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
                UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
            ]
            Pushwoosh.ForegroundPush.titlePushColor = .black
            Pushwoosh.ForegroundPush.messagePushColor = UIColor(white: 0.15, alpha: 1.0)
        }
    }
}
```

## Next Steps

- <doc:GettingStarted> - Quick start guide
- ``PushwooshForegroundPushImplementation`` - Full API reference
