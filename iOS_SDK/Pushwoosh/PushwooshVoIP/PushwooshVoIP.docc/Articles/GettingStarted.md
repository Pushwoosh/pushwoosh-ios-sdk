# Getting Started

Set up VoIP push notifications with CallKit in your iOS app.

## Installation

@TabNavigator {
    @Tab("Swift Package Manager") {
        In Xcode, use the following URL to add the Pushwoosh dependency:

        ```
        https://github.com/Pushwoosh/Pushwoosh-XCFramework
        ```

        Select the required modules in your target:

        ![Choose package products: PushwooshBridge, PushwooshCore, PushwooshFramework, and PushwooshVoIP](ios-voip-1.png)

        > **Important**: The modules PushwooshFramework, PushwooshCore, PushwooshBridge, and PushwooshVoIP are required.
    }

    @Tab("CocoaPods") {
        Add to your Podfile:

        ```ruby
        pod 'PushwooshXCFramework'
        pod 'PushwooshXCFramework/PushwooshVoIP'
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
- An iOS platform configured in your Pushwoosh project. We recommend using the Token-Based Authentication configuration as the simplest approach
- Your Pushwoosh Application Code from the Control Panel
- VoIP Services Certificate (.p12) created in Apple Developer Portal
- iOS 15.0+ deployment target
- PushwooshFramework, PushwooshCore, and PushwooshBridge frameworks integrated in your project
- The base Pushwoosh SDK set up with the same Application Code: `Pushwoosh_APPID` in `Info.plist` and a call to `Pushwoosh.configure.registerForPushNotifications()`. The VoIP token is attached to the device registered by the base SDK

> **Note**: VoIP pushes use the same Pushwoosh application and Application Code as regular pushes. No separate VoIP application is needed.

## Step 1: Add Required Capabilities

In Xcode:

1. Select your target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add **Push Notifications**
4. Click **+ Capability** and add **Background Modes**
5. In Background Modes, enable **Remote notifications** checkbox
6. In Background Modes, enable **Voice over IP** checkbox

![Required capabilities: Push Notifications and Background Modes with Remote notifications and Voice over IP enabled](ios-voip-2.png)

## Step 2: Set the Delegate

The SDK sets up CallKit and PushKit and registers the VoIP token on its own at app launch. Set the delegate in `application(_:didFinishLaunchingWithOptions:)`:

```swift
import UIKit
import PushwooshFramework
import PushwooshVoIP
import CallKit
import PushKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, PWVoIPCallDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        Pushwoosh.VoIP.delegate = self
        Pushwoosh.VoIP.setRingtone("mySound.caf")

        return true
    }

    // MARK: - Required PWVoIPCallDelegate Callbacks

    func voipDidReceiveIncomingCall(payload: PushwooshVoIP.PWVoIPMessage) {
        // Handle incoming VoIP push
    }

    func pwProviderDidReset(_ provider: CXProvider) {
        // Handle provider reset
    }

    func pwProviderDidBegin(_ provider: CXProvider) {
        // Handle provider activation
    }
}
```

`setRingtone(_:)` is optional: it takes a sound file name from the app bundle and is saved across launches. Without it, CallKit plays the system ringtone.

Video support and the caller ID format are set per call in the push payload: `video` (`true` for a video call) and `handleType` (`1` – generic, `2` – phone number, `3` – email; generic by default).

> **Note**: `initializeVoIP(_:ringtoneSound:handleTypes:)` is deprecated. It only sets the ringtone, and its `supportVideo` and `handleTypes` parameters are ignored. Use `setRingtone(_:)` instead.

## Step 3: Delegate Methods

The ``PWVoIPCallDelegate`` protocol provides callbacks for VoIP events:

| Method | Description |
|--------|-------------|
| `voipDidReceiveIncomingCall(payload:)` | Called when VoIP push arrives with call information |
| `pwProviderDidReset(_:)` | Called when CallKit provider resets (end all active calls here) |
| `pwProviderDidBegin(_:)` | Called when CallKit provider is ready |
| `voipDidRegisterTokenSuccessfully()` | Optional. Called when the VoIP token is registered with Pushwoosh |
| `voipDidFailToRegisterToken(error:)` | Optional. Called when VoIP token registration fails. This is the only place the registration error is reported |

## Step 4: Upload VoIP Certificate

1. Create VoIP Services Certificate in Apple Developer Portal
2. Export as .p12 file
3. In Pushwoosh Control Panel, go to **Settings → Configure platforms**, find **iOS**, and select **VoIP push notifications** in the dropdown
4. Upload the .p12 certificate and enter its private key password
5. Under **Gateway**, select **Sandbox** for development builds or **Production** for App Store and TestFlight builds

## Testing

VoIP pushes only work on physical devices. Simulator is not supported.

Build and run your app on a physical device, then send a test VoIP push from the Pushwoosh Control Panel.

## Next Steps

- <doc:Examples> - Code examples for common use cases
- ``PWVoIPCallDelegate`` - Full protocol reference
