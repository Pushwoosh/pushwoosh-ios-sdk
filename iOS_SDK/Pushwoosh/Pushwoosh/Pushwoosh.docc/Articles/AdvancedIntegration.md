# Advanced Integration Guide

Advanced configuration options for Pushwoosh iOS SDK integration.

## Overview

This guide covers advanced configuration options including background modes, foreground notifications, logging, custom delegates, lazy initialization, and Info.plist properties.

## Background Modes

By default, iOS does not allow apps to process push notifications when they are in the background. To enable silent push notifications and background processing, you must enable Background Modes.

### Enable Background Modes in Xcode

1. Open your Xcode project
2. Select your app target
3. Navigate to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Select **Background Modes**
6. Enable **Remote notifications** checkbox

This allows your app to:
- Process silent push notifications in the background
- Update content when push notifications arrive
- Wake up the app to perform tasks

## Foreground Notifications

By default, the SDK displays notification banners while the app is running in the foreground. You can control this behavior programmatically.

### Control Foreground Alert Display

@TabNavigator {
    @Tab("Swift") {
        ```swift
        // Enable foreground notifications
        Pushwoosh.configure.setShowPushnotificationAlert(true)

        // Disable foreground notifications
        Pushwoosh.configure.setShowPushnotificationAlert(false)
        ```
    }

    @Tab("Objective-C") {
        ```objc
        // Enable foreground notifications
        [Pushwoosh.configure setShowPushnotificationAlert:YES];

        // Disable foreground notifications
        [Pushwoosh.configure setShowPushnotificationAlert:NO];
        ```
    }
}

## Logging

The SDK provides multiple logging levels to help debug integration issues and monitor SDK behavior.

### Available Log Levels

- **NONE** - No logging
- **ERROR** - Only errors
- **WARNING** - Errors and warnings
- **INFO** - Default level, informational messages
- **DEBUG** - Detailed debug information
- **VERBOSE** - All possible logging

### Configure Logging via Info.plist

Add the following key to your `Info.plist`:

```xml
<key>Pushwoosh_LOG_LEVEL</key>
<string>DEBUG</string>
```

### Configure Logging Programmatically

@TabNavigator {
    @Tab("Swift") {
        ```swift
        Pushwoosh.debug.setLogLevel(.PW_LL_DEBUG)
        ```

        Available log levels:
        - `.PW_LL_NONE`
        - `.PW_LL_ERROR`
        - `.PW_LL_WARNING`
        - `.PW_LL_INFO`
        - `.PW_LL_DEBUG`
        - `.PW_LL_VERBOSE`
    }

    @Tab("Objective-C") {
        ```objc
        [Pushwoosh.debug setLogLevel:PW_LL_DEBUG];
        ```

        Available log levels:
        - `PW_LL_NONE`
        - `PW_LL_ERROR`
        - `PW_LL_WARNING`
        - `PW_LL_INFO`
        - `PW_LL_DEBUG`
        - `PW_LL_VERBOSE`
    }
}

## Custom UNNotificationCenterDelegate

If you need to implement custom notification handling alongside Pushwoosh, you can register additional delegates through the notification center delegate proxy.

### Register Custom Delegate

@TabNavigator {
    @Tab("Swift") {
        ```swift
        Pushwoosh.sharedInstance().notificationCenterDelegateProxy.add(myDelegate)
        ```
    }

    @Tab("Objective-C") {
        ```objc
        [[Pushwoosh sharedInstance].notificationCenterDelegateProxy
            addNotificationCenterDelegate:myDelegate];
        ```
    }
}

### Implement Delegate Methods

Use `PWMessage.isPushwooshMessage()` to check if the notification is from Pushwoosh and handle only non-Pushwoosh notifications in your custom delegate.

@TabNavigator {
    @Tab("Swift") {
        ```swift
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            // Only handle non-Pushwoosh notifications
            if !PWMessage.isPushwooshMessage(notification.request.content.userInfo) {
                completionHandler([.alert, .sound])
            }
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            // Only handle non-Pushwoosh notifications
            if !PWMessage.isPushwooshMessage(response.notification.request.content.userInfo) {
                // Handle your custom notification
                completionHandler()
            }
        }
        ```
    }

    @Tab("Objective-C") {
        ```objc
        - (void)userNotificationCenter:(UNUserNotificationCenter *)center
                willPresentNotification:(UNNotification *)notification
                withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
            // Only handle non-Pushwoosh notifications
            if (![PWMessage isPushwooshMessage:notification.request.content.userInfo]) {
                completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
            }
        }

        - (void)userNotificationCenter:(UNUserNotificationCenter *)center
                didReceiveNotificationResponse:(UNNotificationResponse *)response
                withCompletionHandler:(void (^)(void))completionHandler {
            // Only handle non-Pushwoosh notifications
            if (![PWMessage isPushwooshMessage:response.notification.request.content.userInfo]) {
                // Handle your custom notification
                completionHandler();
            }
        }
        ```
    }
}

## Lazy Initialization

By default, the Pushwoosh SDK initializes automatically when the app launches. Lazy initialization allows you to delay SDK startup until explicitly called.

This is useful when:
- You need to obtain user consent before initializing the SDK
- You want conditional initialization based on user preferences
- You need to configure settings before SDK starts

### Enable Lazy Initialization

Add the following key to your `Info.plist`:

```xml
<key>Pushwoosh_LAZY_INITIALIZATION</key>
<true/>
```

With this flag enabled, the SDK will not start automatically. Services will only activate when you explicitly call Pushwoosh SDK methods, such as:

@TabNavigator {
    @Tab("Swift") {
        ```swift
        Pushwoosh.configure.registerForPushNotifications()
        ```
    }

    @Tab("Objective-C") {
        ```objc
        [Pushwoosh.configure registerForPushNotifications];
        ```
    }
}

## Info.plist Configuration Properties

The SDK supports multiple configuration options through `Info.plist` keys.

### Application Configuration

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_APPID` | String | Production app ID from Pushwoosh Control Panel | Required |
| `Pushwoosh_APPID_Dev` | String | Development app ID for testing | Optional |

### Notification Settings

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_SHOW_ALERT` | Boolean | Shows notification foreground alert | YES |
| `Pushwoosh_ALERT_TYPE` | String | Sets notification alert style: BANNER, ALERT, or NONE | BANNER |
| `Pushwoosh_AUTO_ACCEPT_DEEP_LINK_FOR_SILENT_PUSH` | Boolean | Deep links in silent pushes process automatically | YES |

### Network Configuration

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_BASEURL` | String | Overrides the Pushwoosh server base URL | https://cp.pushwoosh.com/json/1.3/ |
| `Pushwoosh_ALLOW_SERVER_COMMUNICATION` | Boolean | Allows SDK to send network requests to Pushwoosh | YES |

### Data Collection Settings

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA` | Boolean | Allows SDK to collect and send device data | YES |
| `Pushwoosh_ALLOW_COLLECTING_DEVICE_OS_VERSION` | Boolean | Device OS version collection permission | YES |
| `Pushwoosh_ALLOW_COLLECTING_DEVICE_LOCALE` | Boolean | Device locale collection permission | YES |
| `Pushwoosh_ALLOW_COLLECTING_DEVICE_MODEL` | Boolean | Device model collection permission | YES |

### Feature Toggles

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_LOG_LEVEL` | String | SDK logging level: NONE, ERROR, WARNING, INFO, DEBUG, VERBOSE | INFO |
| `Pushwoosh_PURCHASE_TRACKING_ENABLED` | Boolean | In-app purchase tracking for customer journeys | NO |
| `Pushwoosh_LAZY_INITIALIZATION` | Boolean | Delays SDK startup until explicitly called | NO |

### Example Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required: Your Pushwoosh Application ID -->
    <key>Pushwoosh_APPID</key>
    <string>XXXXX-XXXXX</string>

    <!-- Optional: Development Application ID -->
    <key>Pushwoosh_APPID_Dev</key>
    <string>YYYYY-YYYYY</string>

    <!-- Show notifications in foreground -->
    <key>Pushwoosh_SHOW_ALERT</key>
    <true/>

    <!-- Set logging level -->
    <key>Pushwoosh_LOG_LEVEL</key>
    <string>DEBUG</string>

    <!-- Enable lazy initialization -->
    <key>Pushwoosh_LAZY_INITIALIZATION</key>
    <true/>

    <!-- Enable purchase tracking -->
    <key>Pushwoosh_PURCHASE_TRACKING_ENABLED</key>
    <true/>
</dict>
</plist>
```

## Best Practices

### 1. Use Appropriate Log Levels

- **Production**: Use `INFO` or `WARNING` level
- **Development**: Use `DEBUG` or `VERBOSE` level
- **Release**: Consider using `ERROR` or `NONE` to minimize log output

### 2. Background Modes

Always enable Background Modes if you plan to:
- Send silent push notifications
- Update app content in the background
- Track notification delivery rates accurately

### 3. Custom Delegates

When implementing custom `UNNotificationCenterDelegate`:
- Always check `PWMessage.isPushwooshMessage()` first
- Handle only non-Pushwoosh notifications in your custom code
- Let Pushwoosh SDK handle its own notifications automatically

### 4. Lazy Initialization

Use lazy initialization when:
- You need to comply with privacy regulations (GDPR, CCPA)
- User consent is required before collecting data
- You want to delay SDK initialization for performance reasons

### 5. Data Collection

Configure data collection settings based on your privacy policy:
- Disable unnecessary data collection
- Document what data you collect in your privacy policy
- Provide users with opt-out options if required

## Troubleshooting

### Background Notifications Not Working

Check:
1. Background Modes capability is enabled
2. Remote notifications checkbox is checked
3. Silent push notification flag is set in the notification payload
4. App is not force-quit by the user

### Foreground Notifications Not Appearing

Verify:
1. `showPushnotificationAlert` is set to `true`
2. `Pushwoosh_SHOW_ALERT` is `YES` in Info.plist
3. Notification permissions are granted

### Custom Delegate Not Called

Ensure:
1. Delegate is registered via `notificationCenterDelegateProxy`
2. You're checking `isPushwooshMessage()` correctly
3. Delegate is not deallocated (use strong reference)

## Next Steps

- Configure user segmentation with tags
- Set up rich media notifications
- Implement deep linking
- Enable in-app messaging
