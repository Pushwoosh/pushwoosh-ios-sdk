# Getting Started

Integrate Modal Rich Media for your tvOS app.

## Overview

Modal Rich Media for tvOS provides interactive HTML-based content display optimized for Apple TV's remote control navigation. Starting from SDK version 6.11.0, you can deliver rich media to tvOS devices.

> **Important**: Traditional push notifications are not supported on Apple TV. Only silent notifications with rich media content work on tvOS.

## Installation

@TabNavigator {
    @Tab("Swift Package Manager") {
        In Xcode, use the following URL to add the Pushwoosh dependency:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```

        Select the required modules in your target:

        ![Choose package products: PushwooshBridge, PushwooshCore, PushwooshFramework, and PushwooshTVOS](tvos-install-spm.png)

        > **Important**: The modules PushwooshFramework, PushwooshCore, PushwooshBridge, and PushwooshTVOS are required.
    }

    @Tab("CocoaPods") {
        Add to your Podfile:

        ```ruby
        platform :tvos, '11.0'
        use_frameworks!

        target 'YourTVOSApp' do
          pod 'PushwooshXCFramework'
          pod 'PushwooshXCFramework/PushwooshTVOS'
        end
        ```

        Then run:

        ```bash
        pod install
        ```
    }
}

## Prerequisites

Before you begin, ensure you have:

- A Pushwoosh account
- A Pushwoosh project set up in your account
- A tvOS platform configured in your Pushwoosh project. We recommend using the Token-Based Authentication configuration as the simplest approach
- Your Pushwoosh Application Code from the Control Panel
- tvOS 11.0+ deployment target
- PushwooshFramework, PushwooshCore, and PushwooshBridge frameworks integrated in your project
- SDK version 6.11.0 or higher

> **Important**: Rich Media HTML content must be hosted on a web server accessible from your tvOS devices.

## Step 1: Add Required Capabilities

In Xcode:

1. Select your tvOS target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **Push Notifications**

![Required capabilities: Push Notifications enabled](tvos-capabilities.png)

## Step 2: Configure AppDelegate

Initialize Pushwoosh in `application(_:didFinishLaunchingWithOptions:)`:

```swift
import UIKit
import Pushwoosh
import PushwooshTVOS

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")
        Pushwoosh.TVoS.registerForTvPushNotifications()

        return true
    }
}
```

Replace `XXXXX-XXXXX` with your actual Pushwoosh Application Code.

## Step 3: Handle Device Token Registration

Implement token registration methods:

```swift
import UIKit
import Pushwoosh
import PushwooshTVOS

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Pushwoosh.TVoS.handleTvPushToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Pushwoosh.TVoS.handleTvPushRegistrationFailure(error)
    }
}
```

## Step 4: Process Incoming Notifications

Handle incoming push notifications with rich media:

```swift
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    // Check if push contains Rich Media and handle it
    if Pushwoosh.TVoS.handleTVOSPush(userInfo: userInfo) {
        // Rich Media was successfully displayed
        completionHandler(.newData)
    } else {
        // No Rich Media in notification
        completionHandler(.noData)
    }
}
```

The `handleTVOSPush(userInfo:)` method returns a boolean indicating whether the notification contained rich media and was handled successfully.

## Step 5: Configure Rich Media (Optional)

Customize the position and animations for Rich Media display:

```swift
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

    Pushwoosh.TVoS.setAppCode("XXXXX-XXXXX")

    // Configure Rich Media appearance
    Pushwoosh.TVoS.configureRichMediaWith(
        position: .center,
        presentAnimation: .fromBottom,
        dismissAnimation: .toBottom
    )

    // Show or hide the system Close button
    Pushwoosh.TVoS.configureCloseButton(true)

    Pushwoosh.TVoS.registerForTvPushNotifications()

    return true
}
```

### Rich Media Position Options

| Position | Description |
|----------|-------------|
| `.center` | Display in the center of the screen (default) |
| `.left` | Display on the left side |
| `.right` | Display on the right side |
| `.top` | Display at the top |
| `.bottom` | Display at the bottom |

### Animation Options

| Present Animation | Dismiss Animation | Description |
|-------------------|-------------------|-------------|
| `.none` | `.none` | No animation, appears/disappears immediately (default) |
| `.fromTop` | `.toTop` | Slides in from / out to the top |
| `.fromBottom` | `.toBottom` | Slides in from / out to the bottom |
| `.fromLeft` | `.toLeft` | Slides in from / out to the left |
| `.fromRight` | `.toRight` | Slides in from / out to the right |

### Close Button Configuration

If you hide the system close button with `configureCloseButton(false)`, ensure your Rich Media HTML includes a custom button with the `closeInApp()` action:

```html
<a href="#" onclick="closeInApp()">Close</a>
```

## Step 6: Create Rich Media HTML Content

Rich Media content uses HTML with inline styles. The SDK parses HTML and renders it natively with tvOS Focus Engine support.

### Focus Navigation

Focusable elements are automatically detected in the HTML content. Users can navigate between elements using the directional pad on the Apple TV remote. Standard elements like `<button>`, `<a>`, and `<input>` receive automatic focus support.

### Basic Example

```html
<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 0;">
    <div style="width: 1600px; height: 600px; padding: 50px; background-color: #667eea; display: flex; flex-direction: column; align-items: center; justify-content: center;">

        <h1 style="color: #ffffff; font-size: 48px; margin-bottom: 20px;">
            Welcome to Our Service
        </h1>

        <p style="color: #e0e7ff; font-size: 22px; margin-bottom: 30px; text-align: center;">
            Discover amazing content tailored for your Apple TV
        </p>

        <div style="display: flex; gap: 15px;">
            <a href="#" data-event="subscribe_clicked" style="padding: 16px 30px; background-color: #ffffff; color: #667eea; text-align: center; border-radius: 10px; text-decoration: none;">
                Subscribe Now
            </a>

            <a href="#" onclick="closeInApp()" style="padding: 16px 30px; background-color: transparent; color: #ffffff; border: 2px solid #ffffff; border-radius: 10px; text-decoration: none;">
                Close
            </a>
        </div>

    </div>
</body>
</html>
```

### HTML Best Practices

- **Use standard interactive elements**: `<button>`, `<a>`, `<input>` receive automatic focus support
- **Maintain adequate spacing**: Keep at least 20-30px between interactive components for easy navigation
- **Minimum element width**: Target minimum 250pt width for interactive elements
- **Test focus navigation**: Always test in Apple TV simulator to verify navigation flow
- **Use inline styles**: All styles must be inline, external CSS is not supported
- **Use larger fonts**: Minimum 22px for body text, 48px+ for headings

### Supported Elements

- **Headings**: `<h1>` through `<h6>`
- **Text**: `<p>`, `<div>`, `<span>`
- **Images**: `<img src="...">`
- **Buttons**: `<a>`, `<button>`
- **Text Fields**: `<input type="text">`
- **Containers**: `<div>` with flexbox support

### Button Actions

| Action | Description | Example |
|--------|-------------|---------|
| Close | `onclick="closeInApp()"` | `<a href="#" onclick="closeInApp()">Close</a>` |
| Track Event | `data-event` + `data-attributes` | `<a data-event="event_name" data-attributes='{"key":"value"}'>Button</a>` |
| Send Tags | `data-action="sendTags"` + `data-tags` | `<button data-action="sendTags" data-tags='{"tag":"value"}'>Set Tags</button>` |
| Get Tags | `data-action="getTags"` | `<button data-action="getTags">Get Tags</button>` |
| Open Settings | `data-action="openSettings"` | `<button data-action="openSettings">Settings</button>` |

## Step 7: Send Push Notifications

Send silent notifications with rich media using the Pushwoosh REST API.

> **Important**: Only silent notifications with rich media work on Apple TV. Traditional alert notifications are not supported.

```bash
curl -X POST https://api.pushwoosh.com/json/1.3/createMessage \
  -H "Content-Type: application/json" \
  -d '{
    "request": {
      "application": "YOUR-APP-CODE",
      "auth": "YOUR-API-TOKEN",
      "notifications": [{
        "send_date": "now",
        "content": "Rich Media Message",
        "tvos_root_params": {
          "aps": {
            "content-available": 1
          },
          "rm": {
            "url": "https://example.com/richmedia.html",
            "code": "unique_message_id"
          }
        }
      }]
    }
  }'
```

Replace `YOUR-APP-CODE` and `YOUR-API-TOKEN` with your actual credentials.

### Payload Structure

| Field | Description |
|-------|-------------|
| `content-available: 1` | Required for silent notifications on tvOS |
| `rm.url` | URL to your hosted Rich Media HTML file |
| `rm.code` | Unique identifier for this rich media message |

## Testing

### Testing on Simulator

tvOS simulators do not support APNs. You can test:

- SDK initialization and configuration
- Rich Media display by calling methods directly
- UI and focus navigation
- HTML content rendering

![tvOS Simulator testing with Rich Media display](tv_os_simulator.png)

### Testing on Physical Apple TV

1. Build and run your app on a physical Apple TV device
2. Send a test silent notification with rich media from the Pushwoosh Control Panel
3. Verify the Rich Media appears on the device
4. Test focus navigation with Apple TV remote
5. Verify all button actions work correctly

### Verifying Push Token Registration

Check Xcode console logs:

```
[PW] PUSH TV TOKEN: <your-device-token>
Device successfully registered for push notifications
```

### Focus Navigation Testing

Test the following on physical Apple TV:

- Navigate between focusable elements using directional pad
- Verify proper focus highlighting
- Test button activation with the select button
- Ensure smooth navigation flow without focus traps

## Troubleshooting

### Push Notifications Not Received

- Verify Push Notifications capability is enabled in Xcode
- Check that your provisioning profile includes push notification entitlement
- Ensure the App Code matches your Pushwoosh Control Panel
- Verify you're sending **silent notifications** (`content-available: 1`)
- Check that the device token is being sent to Pushwoosh servers

### Rich Media Not Displaying

- Verify the Rich Media URL is accessible from tvOS device
- Check HTML structure and inline styles
- Ensure the `rm` payload is correctly formatted in the notification
- Test HTML rendering in a browser first
- Check console logs for parsing errors
- Verify `handleTVOSPush(userInfo:)` returns `true`

### Focus Navigation Issues

- Ensure interactive elements have minimum 250pt width
- Maintain adequate spacing (20-30px) between focusable elements
- Verify elements are standard HTML interactive elements (`<button>`, `<a>`, `<input>`)
- Test with physical Apple TV remote, not simulator
- Check that `onclick` and `data-` attributes are correctly set

### HTML Content Not Rendering

- Use only inline styles, no external CSS
- Avoid complex CSS selectors
- Keep HTML structure simple and flat (max 3-4 nesting levels)
- Ensure image URLs use HTTPS
- Test HTML in a browser to verify structure

## Next Steps

- <doc:Examples> - Code examples for common use cases
- ``PushwooshTVOSImplementation`` - Full API reference
- ``PWTVOSRichMediaManager`` - Rich Media manager reference
