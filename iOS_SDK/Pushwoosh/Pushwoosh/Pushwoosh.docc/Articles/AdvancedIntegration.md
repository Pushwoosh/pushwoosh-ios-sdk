# Advanced Integration Guide

Advanced configuration options for Pushwoosh iOS SDK integration.

## Overview

This guide covers advanced configuration options including the delivery event, user identity, language and locale, In-App events, the push primer, feature flags, background modes, foreground notifications, logging, custom delegates, lazy initialization, and Info.plist properties.

## Delivery Event

The message delivery event (`messageDeliveryEvent`) is sent by the Notification Service Extension, a subclass of ``PushwooshNotificationServiceExtension``, when iOS hands it the push, whether the app is running or not. The app never sends this event: an integration without the extension has no delivery statistics. The extension and an App Group shared with the app are required; see step 4 of <doc:QuickStart>.

### How the Event Is Sent

- **Push with a `pw_delivery_delay` window, App Group set.** The extension hands the event to iOS, which sends it at a random moment within the window (up to 300 seconds), so the notification is shown without waiting for the request. A failed attempt (no response, HTTP 408, 429, 500, 502, 503 or 504) is sent again 10 seconds × attempt number later, five attempts in all: by the extension while it runs, otherwise by the app, which iOS wakes in the background for it. The SDK takes these background session events in `application(_:handleEventsForBackgroundURLSession:completionHandler:)` itself; events of your own background sessions still reach your app delegate.
- **No window, or no usable App Group.** The extension sends the event at once, while it runs.
- **Incomplete configuration.** The event is skipped, and the extension logs what to configure:

```
messageDeliveryEvent skipped: the Notification Service Extension has no Pushwoosh app code. Set Pushwoosh_APPID in the Info.plist of the app or the extension, or add the same App Group to both targets and set it as PW_APP_GROUPS_NAME in both Info.plist files.
messageDeliveryEvent skipped: the Notification Service Extension has no reverse proxy URL. Add the same App Group to the app and the extension targets and set it as PW_APP_GROUPS_NAME in both Info.plist files, so the extension reads the URL the app passes to setReverseProxy().
```

### What the App Group Carries

Add the App Groups capability with the same group to the app and the extension targets, and set the group as `PW_APP_GROUPS_NAME` in both `Info.plist` files. Through it the extension gets:

- the delivery event scheduled for a `pw_delivery_delay` window, and its retries;
- the reverse proxy URL passed to `Pushwoosh.configure.setReverseProxy(_:headers:)`. With `Pushwoosh_ALLOW_REVERSE_PROXY` enabled and no App Group, the extension has no proxy URL and skips the delivery event rather than bypass the proxy;
- the application selected at runtime with `Pushwoosh.configure.setAppCode(_:baseUrl:)`. Without the App Group the extension reports deliveries to the `Info.plist` application;
- the badge count. The extension applies `pw_badge` (`5`, `+1`, `-1`) only when the App Group is set, so increments add up across pushes.

`Pushwoosh_APPID` and the other `Pushwoosh_*` keys do not need to be repeated in the extension's `Info.plist`: the extension inherits them from the app. A value set in the extension overrides the app's.

To set the App Group in code instead of `Info.plist`, override ``PushwooshNotificationServiceExtension/pushwooshAppGroupsName()`` in the extension.

### Integration Check

At every launch the SDK runs an integration check and prints the report to the console. It flags a missing Notification Service Extension, a `PW_APP_GROUPS_NAME` group the app has no App Groups capability for (checked on a device, not in the simulator), and different `PW_APP_GROUPS_NAME` or `Pushwoosh_APPID` values in the app and the extension. Set `Pushwoosh_DISABLE_INTEGRATION_CHECK` to `YES` to turn the check off.

## User Identity

`Pushwoosh.configure.setUserId(_:)` attributes the device to your user, and `resetUserId()` returns it to the HWID on logout or account deletion. `setUserId("")` does not reset the user: an empty value is ignored.

@TabNavigator {
    @Tab("Swift") {
        ```swift
        func handleLogin(userId: String, email: String) {
            Pushwoosh.configure.setUserId(userId)
            Pushwoosh.configure.setEmail(email)
        }

        func handleLogout() {
            Pushwoosh.configure.resetUserId()
            Pushwoosh.configure.setTags(["logged_in": false])
        }
        ```
    }

    @Tab("Objective-C") {
        ```objc
        [[Pushwoosh configure] setUserId:@"user_123"];
        [[Pushwoosh configure] resetUserId];
        ```
    }
}

## Language and Locale

`setLanguage(_:)` takes a two-letter ISO-639-1 code; `setLocale(_:)` takes a full BCP 47 tag such as `pt-BR` or `zh-Hant-TW`. The two are independent: an app that sets its own language should set the locale too, otherwise the device locale is reported. A new value is sent right away once the device has a push token; pass `nil` to return to the device value.

```swift
Pushwoosh.configure.setLanguage("pt")
Pushwoosh.configure.setLocale("pt-BR")
```

## Events and In-App Messages

Post events that trigger In-App Messages, reload In-App resources, and expose native methods to In-App HTML:

```swift
Pushwoosh.configure.postEvent("productOpened", withAttributes: ["productId": "42"])

Pushwoosh.configure.reloadInApps { error in
    print(error == nil ? "In-Apps reloaded" : "Reload failed")
}

final class JavaScriptInterface: NSObject, PWJavaScriptInterface {
    @objc func nativeCall(_ str: String, _ callback: PWJavaScriptCallback) {
        callback.execute(withParam: str)
    }
}

Pushwoosh.configure.addJavascriptInterface(JavaScriptInterface(), withName: "native")
```

## Push Primer

A soft in-app dialog shown before the system permission prompt. The SDK checks the current authorization status, shows or skips the dialog, and registers for pushes when the user accepts:

```swift
Pushwoosh.configure.pushPrimer
    .title("Stay in the loop")
    .message("Get notified about deals first")
    .acceptButton("Enable")
    .declineButton("Later")
    .present { outcome in }
```

## Feature Flags

Pushwoosh evaluates feature flags on the server; the SDK caches the last response and refreshes it by itself. `get` returns `nil` until the first response arrives. Call `logImpression` when the user sees a branch of the feature, including the disabled one:

```swift
let flags = Pushwoosh.configure.featureFlags
if flags.isEnabled("new_checkout", default: false) {
    showNewCheckout()
} else {
    showOldCheckout()
}
flags.logImpression("new_checkout")
```

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
        - `.PW_LL_WARN`
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
        - `PW_LL_WARN`
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
        Pushwoosh.configure.addNotificationCenterDelegate(myDelegate)
        ```
    }

    @Tab("Objective-C") {
        ```objc
        [Pushwoosh.configure addNotificationCenterDelegate:myDelegate];
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
                completionHandler([.banner, .list, .sound])
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
                completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList | UNNotificationPresentationOptionSound);
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
| `Pushwoosh_API_TOKEN` | String | Device API Token from Pushwoosh Control Panel → API Access | Required |
| `PW_APP_GROUPS_NAME` | String | App Group shared by the app and the Notification Service Extension; set the same value in both `Info.plist` files | Required |

### Notification Settings

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_SHOW_ALERT` | Boolean | Shows notification foreground alert | YES |
| `Pushwoosh_ALERT_TYPE` | String | Sets notification alert style: BANNER, ALERT, or NONE | BANNER |
| `Pushwoosh_AUTO_ACCEPT_DEEP_LINK_FOR_SILENT_PUSH` | Boolean | Deep links in silent pushes process automatically | YES |

### Network Configuration

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `Pushwoosh_BASEURL` | String | Overrides the Pushwoosh server base URL | `https://<APPID>.api.pushwoosh.com/json/1.3/` (auto-built from `Pushwoosh_APPID`) |
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

    <!-- Required: Device API Token -->
    <key>Pushwoosh_API_TOKEN</key>
    <string>YOUR-DEVICE-API-TOKEN</string>

    <!-- Required: App Group shared with the Notification Service Extension -->
    <key>PW_APP_GROUPS_NAME</key>
    <string>group.com.example.app</string>

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

Delivery statistics do not depend on Background Modes: they come from the Notification Service Extension (see <doc:AdvancedIntegration#Delivery-Event>).

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
1. `Pushwoosh.configure.setShowPushnotificationAlert(true)` is in effect (`getShowPushnotificationAlert()` returns `true`)
2. `Pushwoosh_SHOW_ALERT` is `YES` in Info.plist
3. Notification permissions are granted

### Custom Delegate Not Called

Ensure:
1. Delegate is registered via `Pushwoosh.configure.addNotificationCenterDelegate(_:)`
2. You're checking `isPushwooshMessage()` correctly
3. Delegate is not deallocated (use strong reference)

## Next Steps

- Configure user segmentation with tags
- Set up rich media notifications
- Implement deep linking
- Enable in-app messaging
